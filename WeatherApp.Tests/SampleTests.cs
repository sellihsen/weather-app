using System;
using System.Linq;
using Xunit;
using Microsoft.AspNetCore.Mvc.Testing;
using System.Threading.Tasks;
using System.Net.Http;
using System.Text.Json;
using WeatherApp;
using Microsoft.AspNetCore.Hosting;

namespace WeatherApp.Tests
{
    public class SampleTests : IClassFixture<WebApplicationFactory<Program>>
    {
        private readonly HttpClient _client;

        public SampleTests(WebApplicationFactory<Program> factory)
        {
            _client = factory.WithWebHostBuilder(builder =>
            {
                builder.UseEnvironment("Production");
            }).CreateClient();
        }

        [Fact]
        public async Task GetWelcome_ReturnsExpectedMessage()
        {
            var response = await _client.GetAsync("/");
            response.EnsureSuccessStatusCode();

            var jsonString = await response.Content.ReadAsStringAsync();
            Console.WriteLine(jsonString);
            var jsonDoc = JsonDocument.Parse(jsonString);

            Assert.True(jsonDoc.RootElement.TryGetProperty("message", out var message));
            Assert.Equal("Welcome to the Weather App!", message.GetString());

            Assert.True(jsonDoc.RootElement.TryGetProperty("version", out var version));
            Assert.Equal("1.0.0", version.GetString());

            Assert.True(jsonDoc.RootElement.TryGetProperty("environment", out var environment));
            Assert.Equal("Production", environment.GetString());
        }

        [Fact]
        public async Task GetWeather_ReturnsFiveForecasts()
        {
            var response = await _client.GetAsync("/weather");
            response.EnsureSuccessStatusCode();

            var jsonString = await response.Content.ReadAsStringAsync();
            var forecasts = JsonDocument.Parse(jsonString).RootElement;

            Assert.Equal(5, forecasts.GetArrayLength());

            foreach (var forecast in forecasts.EnumerateArray())
            {
                Assert.True(forecast.TryGetProperty("date", out _));
                Assert.True(forecast.TryGetProperty("temperatureC", out _));
                Assert.True(forecast.TryGetProperty("temperatureF", out _));
                Assert.True(forecast.TryGetProperty("summary", out _));
            }
        }

        [Fact]
        public async Task HealthCheck_ReturnsOk()
        {
            var response = await _client.GetAsync("/health");
            Assert.Equal(System.Net.HttpStatusCode.OK, response.StatusCode);
        }
    }
}
