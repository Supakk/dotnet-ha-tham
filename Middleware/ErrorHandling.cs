using System.Text.Encodings.Web;
using System.Text.Json;
using Mammod.Data;

namespace Mammod.Middleware;

/// <summary>
/// Turns a thrown <see cref="DomainException"/> into the JSON body the client
/// already knows how to read.
///
/// <c>messageFromBody</c> in the client's <c>apiClient.ts</c> looks for
/// <c>message</c>, then <c>detail</c>, then <c>error</c>, then an <c>errors</c>
/// dictionary, then <c>title</c>. Writing <c>{ "message": … }</c> lands on the
/// first of those, so a refusal reaches the user in the words it was written in
/// rather than as "คำขอไม่สำเร็จ (400)".
///
/// Anything that is not a DomainException is a bug, not a rule: it is logged in
/// full and answered with a deliberately vague 500, because an unplanned
/// exception's message is written for whoever is reading the log, not for a user.
/// </summary>
public sealed class ErrorHandlingMiddleware(RequestDelegate next, ILogger<ErrorHandlingMiddleware> logger)
{
    /// <summary>
    /// Its own options, because this writes the response by hand rather than
    /// through MVC — so the encoder configured in <c>Program.cs</c> does not
    /// reach it, and without the same one here every refusal ships as a wall of
    /// \u0E-escapes while the successful responses read as Thai.
    /// </summary>
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web)
    {
        Encoder = JavaScriptEncoder.UnsafeRelaxedJsonEscaping,
    };

    public async Task InvokeAsync(HttpContext context)
    {
        try
        {
            await next(context);
        }
        catch (DomainException error)
        {
            logger.LogInformation("ปฏิเสธคำขอ {Method} {Path}: {Message}",
                context.Request.Method, context.Request.Path, error.Message);
            await Write(context, error.Status, error.Message);
        }
        catch (Exception error)
        {
            logger.LogError(error, "คำขอ {Method} {Path} ล้มเหลว",
                context.Request.Method, context.Request.Path);
            await Write(context, StatusCodes.Status500InternalServerError,
                "เซิร์ฟเวอร์เกิดข้อผิดพลาด — ดูรายละเอียดใน log ของ backend");
        }
    }

    private static async Task Write(HttpContext context, int status, string message)
    {
        // A response already on its way cannot be replaced with an error body; all
        // that is left is to let it fail rather than throw a second time here.
        if (context.Response.HasStarted) return;

        context.Response.Clear();
        context.Response.StatusCode = status;
        context.Response.ContentType = "application/json; charset=utf-8";
        await context.Response.WriteAsync(JsonSerializer.Serialize(new { message }, Json));
    }
}
