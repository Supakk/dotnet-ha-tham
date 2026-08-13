using System.Text.Encodings.Web;
using System.Text.Json.Serialization;
using Mammod.Data;
using Mammod.Middleware;
using Mammod.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;

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
// หากุญแจตรงนี้ ตอน startup ไม่ใช่ปล่อยให้ DI ไปหาตอนมี request แรก — เซิร์ฟเวอร์ที่
// ตั้งค่าไม่ครบต้องไม่ขึ้น ดีกว่าขึ้นแล้วพังตอนคนแรกกด login
var tokenService = new TokenService(
    JwtKey.Resolve(builder.Configuration, builder.Environment), builder.Configuration);
builder.Services.AddSingleton(tokenService);

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
        // ตัวเดียวกับที่ลงทะเบียนไว้ข้างบน — ถ้าสร้างใหม่ตรงนี้ ตอน dev จะได้กุญแจคนละอัน
        // กับที่ใช้เซ็น แล้ว token ที่เพิ่งออกให้จะ validate ไม่ผ่านทันที
        options.TokenValidationParameters = tokenService.ValidationParameters();
    });

// ประตูหลัก: นอก Development ทุก endpoint ต้องมี token ที่ถูกต้อง เว้นแต่จะติด
// [AllowAnonymous] ไว้เอง (มีแค่ login กับ refresh)
//
// ตั้งเป็น fallback policy แทนการไปแปะ [Authorize] ทีละ controller เพราะแบบนั้น
// ลืมได้ — และ endpoint ที่ลืมแปะจะเปิดโล่งโดยไม่มีอะไรเตือน แบบนี้ค่าเริ่มต้นคือปิด
// แล้วต้องตั้งใจเปิดเป็นราย ๆ ไป ซึ่งเป็นทางที่พลาดแล้วปลอดภัยกว่า
var requireAuth = builder.Configuration.GetValue("Auth:RequireAuthentication", false)
    || !builder.Environment.IsDevelopment();

builder.Services.AddAuthorization(options =>
{
    if (requireAuth)
    {
        options.FallbackPolicy = new AuthorizationPolicyBuilder(JwtBearerDefaults.AuthenticationScheme)
            .RequireAuthenticatedUser()
            .Build();
    }
});

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
