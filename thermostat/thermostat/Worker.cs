using Microsoft.Extensions.Hosting;
using Microsoft.Extensions.Logging;
using thermostat.Configurations;
using thermostat.Messages;
using thermostat.Repository;
using thermostat.Services;

namespace thermostat
{
    public class Worker : BackgroundService
    {
        private readonly ILogger<Worker> _logger;
        private readonly ITemperatureRepository _repository;
        private readonly IPublishService _service;

        public Worker(ILogger<Worker> logger, ITemperatureRepository repository, IPublishService service)
        {
            _logger = logger ?? throw new ArgumentNullException(nameof(logger));
            _repository = repository ?? throw new ArgumentNullException(nameof(repository));
            _service = service ?? throw new ArgumentNullException(nameof(service));
        }

        private async Task DoWorkAsync()
        {
            _logger.LogInformation(
                $"{nameof(Worker)} is working.");

            var temperature = _repository.GetTemperature();
            var message = new Measurement(){ Temperature = temperature };

            _logger.LogInformation($"Publishing measured temperature {message.Temperature}.");
            await _service.PublishAsync(message);
        }

        public override async Task StopAsync(CancellationToken stoppingToken)
        {
            _logger.LogInformation(
                $"{nameof(Worker)} is stopping.");

            await base.StopAsync(stoppingToken);
        }

        protected override async Task ExecuteAsync(CancellationToken stoppingToken)
        {
            await _service.InitializeAsync();

            while (!stoppingToken.IsCancellationRequested)
            {
                await DoWorkAsync();
                await Task.Delay(1000, stoppingToken);
            }
        }
    }
}
