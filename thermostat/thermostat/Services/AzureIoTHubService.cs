using Microsoft.Azure.Devices.Client;
using Microsoft.Extensions.Logging;
using Microsoft.Extensions.Options;
using System.Text;
using System.Text.Json;
using thermostat.Configurations;
using thermostat.Messages;

namespace thermostat.Services
{
    public class AzureIoTHubService : IPublishService, IDisposable
    {
        private readonly ILogger<AzureIoTHubService> _logger;
        private readonly Registration _registration;
        private readonly ClientModel _model;
        private DeviceClient? _client;
        private bool _isInitialized;

        public AzureIoTHubService(IOptions<Registration> options, IOptions<ClientModel> modelOptions, ILogger<AzureIoTHubService> logger)
        {
            _registration = options.Value;
            _model = modelOptions.Value;
            _isInitialized = false;
            _logger = logger;
        }

        public async Task InitializeAsync()
        {
            _client = DeviceClient.Create(
                hostname: _registration.HubHostName,
                authenticationMethod: new DeviceAuthenticationWithRegistrySymmetricKey(_registration.DeviceId, _registration.SymmetricKey),
                options: new ClientOptions()
                {
                    ModelId = _model.ModelId
                }
            );

            await _client.OpenAsync();
            _logger.LogInformation($"Setup client {_registration.DeviceId} for message publishing.");
            _isInitialized = true;
        }

        public async Task PublishAsync(Measurement measurement)
        {
            if (!_isInitialized) throw new InvalidOperationException("Initialize service before usage.");

            var payload = JsonSerializer.Serialize(measurement);
            using var message = new Message(Encoding.UTF8.GetBytes(payload))
            {
                ContentEncoding = "utf-8",
                ContentType = "application/json",
            };

            _logger.LogTrace($"Publishing message from client {_registration.DeviceId}.");
            await _client!.SendEventAsync(message);
        }

        public void Dispose()
        {
            if (_client != null) _client.Dispose();
        }
    }
}
