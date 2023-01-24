using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
using System.Threading.Tasks;

namespace thermostat.Repository
{
    public class RandomTemperatureRepository : ITemperatureRepository
    {
        private readonly Random _random = new Random();

        public double GetTemperature() => _random.NextDouble() * 100;
    }
}
