using thermostat.Messages;

namespace thermostat.Services
{
    public interface IPublishService
    {
        /// <summary>
        /// Prepares the publishing service for publishing messages.
        /// Has to be called first.
        /// </summary>
        /// <returns></returns>
        Task InitializeAsync();

        /// <summary>
        /// Publishes the measurement.
        /// </summary>
        /// <param name="measurement"></param>
        /// <returns></returns>
        Task PublishAsync(Measurement measurement);
    }
}
