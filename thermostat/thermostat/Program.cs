using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using thermostat;
using thermostat.Configurations;
using thermostat.Repository;
using thermostat.Services;

IHost host = Host.CreateDefaultBuilder(args)
    .ConfigureAppConfiguration((context, configuration) =>
    {
        configuration.AddEnvironmentVariables();
        configuration.AddJsonFile("appsettings.json");
        configuration.AddJsonFile($"appsettings.{context.HostingEnvironment.EnvironmentName}.json", optional: true);
    })
    .ConfigureServices((context, services) =>
    {
        // A) Configuration using IOptions pattern
        services.AddOptions();
        services.Configure<ClientModel>(context.Configuration.GetSection(nameof(ClientModel)));
        services.Configure<Registration>(context.Configuration.GetSection(nameof(Registration)));

        // B) Services
        services.AddSingleton<ITemperatureRepository, RandomTemperatureRepository>();
        services.AddSingleton<IPublishService, AzureIoTHubService>();
        services.AddHostedService<Worker>();
    })
    .Build();

await host.RunAsync();