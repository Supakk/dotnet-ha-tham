using System.Text.Encodings.Web;
using System.Text.Json.Serialization;
using Mammod.Data;
using Mammod.Database;
using Mammod.Database.Documents;
using Mammod.Middleware;
using Mammod.Services;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.AspNetCore.Authorization;
using Microsoft.EntityFrameworkCore;

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

// ── ฐานข้อมูล · optional ────────────────────────────────────────────────────
//
// มี connection string ชื่อ Mmdev = อ่าน master กับใบสั่งขายจาก SQL Server
// ไม่มี = ทำงานบน seed ในหน่วยความจำเหมือนเดิมทุกอย่าง
//
// เป็นทางเลือกไม่ใช่ข้อบังคับ เพราะโปรเจคนี้ต้องรันได้ด้วย `dotnet run` เปล่า ๆ
// สำหรับคนที่ยังไม่ได้ลง SQL Server และเพราะ smoke test กับ fixture ฝั่ง frontend
// พึ่งพาข้อมูลชุดที่รู้ค่าแน่นอน
//
// ⚠ ตอนนี้ **อ่านอย่างเดียว** การเขียนยังลงหน่วยความจำ แปลว่าถ้าเปิดฐานไว้
//   แถวที่สร้างผ่าน POST /carriers จะไม่โผล่ใน GET /carriers เพราะคนละที่เก็บ
//   ย้ายการเขียนตามไปเป็นงานถัดไป ซึ่งต้องมี transaction คุมกติกา
//   "ใบสั่งส่งอยู่ได้ที่เดียว" ตอนมีคนใช้พร้อมกัน จึงยังไม่รวมมาในรอบนี้
var connectionString = builder.Configuration.GetConnectionString("Mmdev");
var useDatabase = !string.IsNullOrWhiteSpace(connectionString);

if (useDatabase)
{
    builder.Services.AddDbContext<AppDbContext>(options => options.UseSqlServer(connectionString));

    // ── เอกสารอ่านจาก SQL · documents read from SQL ─────────────────────────
    //
    // ผูกแบบ scoped ทั้งหมด เพราะคลังของ request มาจาก header ไม่ใช่ค่าคงที่ —
    // ถ้าเป็น singleton สอง request ที่คนละคลังจะเห็นข้อมูลปนกัน
    builder.Services.AddScoped<RequestContext>();
    builder.Services.AddScoped<IWarehouseContext>(sp => sp.GetRequiredService<RequestContext>());
    builder.Services.AddScoped<IActorContext>(sp => sp.GetRequiredService<RequestContext>());
    builder.Services.AddScoped<DocumentReadQueries>();
    builder.Services.AddScoped<IDeliveryOrderQuery, DeliveryOrderQuery>();
}

builder.Services.AddSingleton(sp => new MasterQueries(
    sp.GetRequiredService<TmsStore>(),
    sp.GetRequiredService<IServiceScopeFactory>(),
    useDatabase));
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

// แผนขนส่งอยู่ในหน่วยความจำ แต่สายส่งอาจมาจาก SQL Server — ผูกให้แผนหาสายส่ง
// จากที่เดียวกับที่ GET /routes ตอบ ไม่งั้นตอนเปิดฐานไว้ สายที่หน้าจอให้เลือก
// จะหาไม่เจอทุกตัว เพราะคนละชุด id (rt-RT-NORTH-01 กับ rt-1)
//
// ต่อสายทีหลังตรงนี้แทนที่จะฉีดผ่าน constructor เพราะ MasterQueries พึ่ง TmsStore
// อยู่แล้ว ถ้าฉีดกลับไปอีกทางจะเป็นวงกลม
app.Services.GetRequiredService<TmsStore>()
    .UseRouteSource(() => app.Services.GetRequiredService<MasterQueries>().Routes());

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

// หลัง authentication เพราะต้องอ่านชื่อผู้ใช้จาก token ไปลง audit
// และก่อน controller เพราะ repository ทุกตัวต้องรู้คลังก่อนจะ query
if (useDatabase) app.UseMiddleware<WarehouseMiddleware>();

app.MapControllers();

app.Run();
