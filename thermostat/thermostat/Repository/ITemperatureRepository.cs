namespace thermostat.Repository
{
    public interface ITemperatureRepository
    {
        /// <summary>
        /// Obtains the current temperature measured by the device.
        /// </summary>
        /// <returns></returns>
        public double GetTemperature();
    }
}
