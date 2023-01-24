[CmdletBinding()]
param(
	[Parameter(Mandatory)]
	$LicenseId
)

# 1.) We set the default azure license. This attaches all future resources to this license.
az account set --subscription $LicenseId

# 2.) We create the service principal name.
$rawSPData = az ad sp create-for-rbac --name sp-rup-ref-terraform --role Contributor --scopes /subscriptions/$LicenseId
$spData = ConvertFrom-Json -InputObject ([string]::Join("", $rawSPData))
Write-Information -MessageData ("Created {0}." -f $spData.displayName)

# 3.) We create the resource group.
$rawRGData = az group create --name rg-rup-ref-dev-we-01 --location westeurope
$rgData = ConvertFrom-Json -InputObject ([string]::Join("", $rawRGData))
Write-Information -MessageData ("Created {0}." -f $rgData.name)

# 4.) We create the key vault.
$rawKVData = az keyvault create --name kv-rup-ref-dev-we-01 --resource-group $rgData.name --location westeurope
$kvData = ConvertFrom-Json -InputObject ([string]::Join("", $rawKVData))
Write-Information -MessageData ("Created {0}." -f $kvData.name)

# 5.) We store the secrets in the key vault.
az keyvault secret set --name kvs-rup-ref-dev-terraform-sp-client-id --vault-name $kvData.name --value $spData.appId | Out-Null
az keyvault secret set --name kvs-rup-ref-dev-terraform-sp-client-secret --vault-name $kvData.name --value $spData.password | Out-Null
az keyvault secret set --name kvs-rup-ref-dev-terraform-sp-client-tenant-id --vault-name $kvData.name --value $spData.tenant | Out-Null
az keyvault secret set --name kvs-rup-ref-dev-subscription-id --vault-name $kvData.name --value $LicenseId | Out-Null

# 6.) We create the storage account.
# The storage account is scoped to the resource group created in 3).
$rawSTData = az storage account create --name stpruprefdevwe01 --resource-group $rgData.name --location westeurope
$stData = ConvertFrom-Json -InputObject ([string]::Join("", $rawSTData)) 
Write-Information -MessageData ("Created {0}." -f $stData.name)

# 7.) We create the storage container.
$rawSTBLCData = az storage container create --name stblc-rup-ref-dev-terraform --account-name $stData.name
$stblData = ConvertFrom-Json -InputObject ([string]::Join("", $rawSTBLCData)) 
Write-Information -MessageData ("Created {0}." -f $stblData.name)

# 8.) Set access policy to key vault for spn.
az keyvault set-policy --name kv-rup-ref-dev-we-01 --secret-permissions get list --key-permissions decrypt encrypt verify sign get list --spn $spData.appId