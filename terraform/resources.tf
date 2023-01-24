resource "azurerm_resource_group" "references" {
  name     = "rg-rup-ref-dev-we-02"
  location = "West Europe"
}

resource "azurerm_iothub" "iothub" {
  name                = "iot-rup-ref-dev-we-01"
  location            = azurerm_resource_group.references.location
  resource_group_name = azurerm_resource_group.references.name

  # Defines tier as described in https://azure.microsoft.com/en-us/pricing/details/iot-hub/
  sku {
    name     = "S1"
    capacity = 1
  }

  depends_on = [
    azurerm_resource_group.references
  ]
}

resource "azurerm_eventhub_namespace" "telemetry" {
  name                = "evhns-rup-ref-dev-we-01"
  location            = azurerm_resource_group.references.location
  resource_group_name = azurerm_resource_group.references.name
  sku                 = "Basic"

  depends_on = [
    azurerm_resource_group.references
  ]
}

resource "azurerm_eventhub" "aggregated" {
  name                = "evh-rup-ref-dev-we-01"
  namespace_name      = azurerm_eventhub_namespace.telemetry.name
  resource_group_name = azurerm_resource_group.references.name
  partition_count     = 2
  message_retention   = 1

  depends_on = [
    azurerm_resource_group.references,
    azurerm_eventhub_namespace.telemetry
  ]
}

resource "azurerm_stream_analytics_job" "cold_job" {
  name                = "stream-rup-ref-dev-we-01"
  resource_group_name = azurerm_resource_group.references.name
  location            = azurerm_resource_group.references.location
  compatibility_level = "1.2"
  streaming_units     = 3

  transformation_query = <<QUERY
SELECT
  AVG(Temperature) AS Temperature,
  IoTHub.ConnectionDeviceId AS DeviceId,
  System.Timestamp() AS WindowEnd
INTO
  [output-to-hub]
FROM
  [iot-telemetry]
TIMESTAMP BY
  EventEnqueuedUtcTime
GROUP BY 
  IoTHub.ConnectionDeviceId,
  TumblingWindow(second, 60)

SELECT
  AVG(Temperature) AS Temperature,
  System.Timestamp() AS WindowEnd
INTO 
  [output-to-powerbi]
FROM
  [iot-telemetry]
TIMESTAMP BY
  EventEnqueuedUtcTime
GROUP BY 
  TumblingWindow(second, 10)
HAVING
  AVG(Temperature) > 60
QUERY

  depends_on = [
    azurerm_resource_group.references
  ]
}

resource "azurerm_stream_analytics_stream_input_iothub" "telemetry" {
  name                         = "iot-telemetry"
  stream_analytics_job_name    = azurerm_stream_analytics_job.cold_job.name
  resource_group_name          = azurerm_stream_analytics_job.cold_job.resource_group_name
  endpoint                     = "messages/events"
  eventhub_consumer_group_name = "$Default"
  iothub_namespace             = azurerm_iothub.iothub.name
  shared_access_policy_key     = azurerm_iothub.iothub.shared_access_policy[0].primary_key
  shared_access_policy_name    = "iothubowner"

  serialization {
    type     = "Json"
    encoding = "UTF8"
  }

  depends_on = [
    azurerm_resource_group.references,
    azurerm_stream_analytics_job.cold_job,
    azurerm_iothub.iothub
  ]
}

resource "azurerm_stream_analytics_output_eventhub" "telemetry" {
  name                      = "output-to-hub"
  stream_analytics_job_name = azurerm_stream_analytics_job.cold_job.name
  resource_group_name       = azurerm_stream_analytics_job.cold_job.resource_group_name
  eventhub_name             = azurerm_eventhub.aggregated.name
  servicebus_namespace      = azurerm_eventhub_namespace.telemetry.name
  shared_access_policy_key  = azurerm_eventhub_namespace.telemetry.default_primary_key
  shared_access_policy_name = "RootManageSharedAccessKey"

  partition_key = "id"

  serialization {
    type     = "Json"
    encoding = "UTF8"
    format   = "LineSeparated"
  }

  depends_on = [
    azurerm_resource_group.references,
    azurerm_stream_analytics_job.cold_job,
    azurerm_eventhub.aggregated,
    azurerm_eventhub_namespace.telemetry
  ]
}

#resource "azurerm_stream_analytics_output_powerbi" "telemetry" {
#  name                    = "output-to-powerbi"
#  stream_analytics_job_id = data.azurerm_stream_analytics_job.example.id
#  dataset                 = "iot-alerts"
#  table                   = "temperature"
#  group_id                = "00000000-0000-0000-0000-000000000000"
#  group_name              = "some-group-name"
#}
#
#resource "azurerm_stream_analytics_job_schedule" "cold_job" {
#  stream_analytics_job_id = azurerm_stream_analytics_job.cold_job.id
#  start_mode              = "JobStartTime"
#
#  depends_on = [
#    azurerm_stream_analytics_job.cold_job,
#    azurerm_stream_analytics_stream_input_iothub.telemetry,
#    azurerm_stream_analytics_output_powerbi.telemetry,
#  ]
#}

resource "azurerm_kusto_cluster" "telemetry" {
  name                = "decruprefdevwe01"
  location            = azurerm_resource_group.references.location
  resource_group_name = azurerm_resource_group.references.name

  sku {
    name     = "Dev(No SLA)_Standard_E2a_v4"
    capacity = 1
  }

  depends_on = [
    azurerm_resource_group.references
  ]
}

resource "azurerm_kusto_database" "telemetry" {
  name                = "dedb-rup-ref-dev-we01"
  resource_group_name = azurerm_resource_group.references.name
  location            = azurerm_resource_group.references.location
  cluster_name        = azurerm_kusto_cluster.telemetry.name

  depends_on = [
    azurerm_resource_group.references,
    azurerm_kusto_cluster.telemetry
  ]
}

resource "azurerm_kusto_script" "temperature" {
  name                       = "example"
  database_id                = azurerm_kusto_database.telemetry.id
  continue_on_errors_enabled = false

  script_content = ".create table temperature_measurement(DeviceId:string, WindowEnd:datetime, Temperature:real)"

  depends_on = [
    azurerm_resource_group.references,
    azurerm_kusto_database.telemetry
  ]
}


resource "azurerm_kusto_eventhub_data_connection" "eventhub_connection" {
  name                = "aggregated-telemetry"
  resource_group_name = azurerm_resource_group.references.name
  location            = azurerm_resource_group.references.location
  cluster_name        = azurerm_kusto_cluster.telemetry.name
  database_name       = azurerm_kusto_database.telemetry.name

  eventhub_id    = azurerm_eventhub.aggregated.id
  consumer_group = "$Default"

  table_name  = "temperature_measurement"
  data_format = "JSON"

  depends_on = [
    azurerm_resource_group.references,
    azurerm_eventhub.aggregated,
    azurerm_kusto_cluster.telemetry,
    azurerm_kusto_script.temperature
  ]
}
