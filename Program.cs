using System.Text.Encodings.Web;
using System.Text.Json.Serialization;
using Mammod.Data;
using Mammod.Middleware;
using Mammod.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;

var builder = WebApplication.CreateBuilder(args);

// ── บริการที่ลงทะเบียนไว้ · services ────────────────────────────────────────

builder.Services.AddControllers().AddJsonOptions(options =>
{
    // camelCase is already the default, but the client reads these names by hand
    // (`manifestNo`, `isDC`, `stopIds`) and it is worth being explicit that this
    // is a contract rather than a default nobody chose.
    options.JsonSerializerOptions.PropertyNamingPolicy = System.Text.Json.JsonNamingPolicy.CamelCase;
    // The status fields are plain strings on both sides ("draft", "sent"), never
    // numbers — a numeric enum would reach the client as `2` and match nothing.
    options.JsonSerializerOptions.Converters.Add(new JsonStringEnumConverter());
    // Without this every Thai character ships as a เ escape. The client
    // decodes those correctly either way, but it triples the size of a response
    // that is almost entirely Thai and makes the payloads unreadable in the
    // network tab and in logs — which is where you look when something is wrong.
    // "Unsafe" names the fact that it no longer escapes characters that only
    // matter when JSON is pasted raw into HTML; it is still valid JSON.
    options.JsonSerializerOptions.Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping;
});

// One instance for the whole process: the pending pool and the documents are
// shared state, and a scoped store would reset itself on every request.
builder.Services.AddSingleton<TmsStore>();
builder.Services.AddSingleton<DeliveryOrderStore>();
builder.Services.AddSingleton<IntegrationConfigStore>();
builder.Services.AddSingleton<TokenService>();

builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// The browser refuses a cross-origin request unless the server names the origin
// back. `AllowCredentials` is what lets the refresh cookie travel, and it is
// exactly why the origins have to be listed: a wildcard origin and credentials
// are not allowed together, by the spec and by ASP.NET Core.
var allowedOrigins = builder.Configuration.GetSection("Cors:Origins").Get<string[]>()
    ?? ["http://localhost:5700"];

builder.Services.AddCors(options =>
{
    options.AddDefaultPolicy(policy => policy
        .WithOrigins(allowedOrigins)
        .AllowAnyHeader()
        .AllowAnyMethod()
        .AllowCredentials());
});

builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddJwtBearer(options =>
    {
        var tokens = new TokenService(builder.Configuration);
        options.TokenValidationParameters = tokens.ValidationParameters();
    });

builder.Services.AddAuthorization();

var app = builder.Build();

// ── ลำดับการทำงานของ request · the pipeline ─────────────────────────────────
// Order matters here more than anywhere else in the file. Each piece only sees
// what the ones above it let through.

// First, so it also catches anything thrown further down the pipeline.
app.UseMiddleware<ErrorHandlingMiddleware>();

if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// No UseHttpsRedirection: the dev client talks to http://localhost, and a 307 to
// https in the middle of a CORS preflight fails in a way that reads like a
// server that is simply down. Put TLS in front of this when it is deployed.

app.UseCors();
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.Run();
