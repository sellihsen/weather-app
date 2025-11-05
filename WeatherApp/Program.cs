using OpenTelemetry;
using OpenTelemetry.Trace;
using OpenTelemetry.Metrics;
using System.Diagnostics;
using System.Diagnostics.Metrics;
using OpenTelemetry.Resources;
using Azure.Monitor.OpenTelemetry.AspNetCore;

var builder = WebApplication.CreateBuilder(args);

// Custom metrics for the application
var weatherMeter = new Meter("WeatherApi", "1.0.0");
var countWeatherStations = weatherMeter.CreateCounter<int>("WeatherStations.count", description: "Counts the number of Weather Stations");

// Create a resource for the service
var resource = ResourceBuilder.CreateDefault().AddService("WeatherApi");

// Custom ActivitySource for the application
var weatherActivitySource = new ActivitySource("WeatherApi");

builder.Logging.AddOpenTelemetry(logging =>
{
    logging.IncludeFormattedMessage = true;
    logging.IncludeScopes = true;
});

var otel = builder.Services.AddOpenTelemetry();

otel.WithMetrics(metrics =>
{
    // Only HTTP Client and custom meters supported.
    metrics.AddHttpClientInstrumentation();
    metrics.AddMeter(weatherMeter.Name);
    metrics.AddMeter("Microsoft.AspNetCore.Hosting");
    metrics.AddMeter("Microsoft.AspNetCore.Server.Kestrel");
});

otel.WithTracing(tracing =>
{
    tracing.AddAspNetCoreInstrumentation();
    tracing.AddHttpClientInstrumentation();
    tracing.AddSource(weatherActivitySource.Name);
});

// Export OpenTelemetry data via OTLP, using env vars for configuration
if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
{
    otel.UseAzureMonitor();
}


// Add services to the container
builder.Services.AddHealthChecks();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure Kestrel to listen on port 8080 (required for containers)
builder.WebHost.ConfigureKestrel(options =>
{
    options.ListenAnyIP(8080);
});

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment() || app.Environment.IsProduction())
{
    app.UseSwagger();
    app.UseSwaggerUI(c => 
    {
        c.SwaggerEndpoint("/swagger/v1/swagger.json", "Weather API v1");
        c.RoutePrefix = "swagger";
    });
}

// Define API endpoints
app.MapGet("/", () => new
{
    Message = "Welcome to the Weather App!",
    Version = "1.0.0",
    Environment = app.Environment.EnvironmentName,
    Timestamp = DateTime.UtcNow,
    DeployedBy = "GitHub Actions"
})
.WithName("GetWelcome")
.WithTags("General");

app.MapGet("/weather", () =>
{
    var summaries = new[] { 
        "Freezing", "Bracing", "Chilly", "Cool", "Mild", 
        "Warm", "Balmy", "Hot", "Sweltering", "Scorching" 
    };

    var forecast = Enumerable.Range(1, 5).Select(index => new
    {
        Date = DateOnly.FromDateTime(DateTime.Now.AddDays(index)),
        TemperatureC = Random.Shared.Next(-20, 55),
        TemperatureF = 0,
        Summary = summaries[Random.Shared.Next(summaries.Length)]
    })
    .Select(temp => new
    {
        temp.Date,
        temp.TemperatureC,
        TemperatureF = 32 + (int)(temp.TemperatureC / 0.5556),
        temp.Summary
    });

    return forecast;
})
.WithName("GetWeatherForecast")
.WithTags("Weather");

// Health check endpoint (required for Kubernetes)
app.MapHealthChecks("/health")
.WithTags("Health");

app.MapGet("/sendWeatherStations", SendWeatherStations);

string SendWeatherStations(ILogger<Program> logger)
{
    using var activity = weatherActivitySource.StartActivity("WeatherActivity");
    logger.LogInformation("Sending Weather Stations");
    countWeatherStations.Add(1);
    activity?.SetTag("WeatherStations", "Hello World!");
    return "Hello World!";
}

app.Run();

public partial class Program { };

