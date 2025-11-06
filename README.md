# WeatherApp

## Project Overview

WeatherApp is a .NET 9 Web API that offers weather forecast data, designed for deployment on Azure Kubernetes Service (AKS) with enhanced observability and security.

---

## Local Deployment

1. Clone the repository:

git clone https://github.com/your-username/weather-app.git
cd weather-app/WeatherApp

text

2. Run the application locally:

dotnet run

text

3. Access the API at `http://localhost:8080` and Swagger UI at `http://localhost:8080/swagger`.

---

## Azure Deployment

### Required Secrets and Environment Variables

- `ACR_NAME`: Azure Container Registry name.
- `AZURE_CREDENTIALS`: JSON credentials for Azure service principal.
- `AZURE_OBJECT_ID`: Object ID for Azure identity.
- `AZURE_TENANT_ID`: Azure tenant identifier.
- `CLUSTER_NAME`: AKS cluster name.
- `RESOURCE_GROUP`: Azure resource group name.
- `SONAR_ORGANIZATION_KEY`: SonarCloud organization key.
- `SONAR_TOKEN`: SonarCloud access token.
- `SONAR_WEATHER_PRJ_KEY`: SonarCloud project key for WeatherApp.
- `SUBSCRIPTION_ID`: Azure subscription ID.

### Workflow

The GitHub Actions workflow handles:

- Dependency restoration, testing, and SonarCloud analysis.
- Docker image build with multi-stage Dockerfile optimized for size (uses alpine).
- Vulnerability scanning with Trivy.
- Push image to ACR tagged with commit SHA.
- Deploy to AKS, applying Kubernetes manifests and updating deployments.

---

## Docker Image Optimization

- Multi-stage Dockerfile separates build and runtime stages.
- Runtime image based on `mcr.microsoft.com/dotnet/aspnet:9.0-alpine` for small size.
- Clean-up commands remove cache and unnecessary files.

---

## Security Scanning With Trivy

- Integrated vulnerability scan in CI pipeline.
- Build aborts if HIGH or CRITICAL vulnerabilities are detected.

---

## OpenTelemetry Integration

- Custom metrics and tracing with OpenTelemetry packages.
- Exports telemetry data to Azure Monitor if configured.
- Uses counters, ActivitySource, and automatic instrumentation for HTTP client and ASP.NET Core.

Example code snippets:

var weatherMeter = new Meter("WeatherApi", "1.0.0");
var countWeatherStations = weatherMeter.CreateCounter<int>("WeatherStations.count");

var resource = ResourceBuilder.CreateDefault().AddService("WeatherApi");
var weatherActivitySource = new ActivitySource("WeatherApi");

builder.Logging.AddOpenTelemetry(logging =>
{
logging.IncludeFormattedMessage = true;
logging.IncludeScopes = true;
});

var otel = builder.Services.AddOpenTelemetry();

otel.WithMetrics(metrics =>
{
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

if (!string.IsNullOrEmpty(builder.Configuration["APPLICATIONINSIGHTS_CONNECTION_STRING"]))
{
otel.UseAzureMonitor();
}