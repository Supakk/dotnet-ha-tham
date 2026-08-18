namespace Mammod.Data;

/// <summary>
/// A refusal the user is meant to read.
///
/// The message is written for a person, in Thai, and the client shows it as-is:
/// <c>toApiError</c> in <c>apiClient.ts</c> reads <c>message</c> off the body
/// before it falls back to anything invented from the status code. So the reason
/// a write was refused only exists here, and it has to be worth reading.
/// </summary>
public sealed class DomainException(string message, int status = StatusCodes.Status400BadRequest)
    : Exception(message)
{
    public int Status { get; } = status;

    /// <summary>The record named by the request does not exist.</summary>
    public static DomainException NotFound(string message) =>
        new(message, StatusCodes.Status404NotFound);
}

/// <summary>
/// The row moved under the caller: the <c>If-Match</c> they sent is not the
/// ROWVER the database holds any more.
///
/// Separate from <see cref="DomainException"/> because the answer needs one more
/// thing than a message — the version that <i>is</i> current — without which the
/// client can only tell the user to reload. With it, the next attempt can be
/// made from what the row actually says.
///
/// <see cref="Mammod.Middleware.ErrorHandlingMiddleware"/> turns this into the
/// 409. Nothing catches <c>DbUpdateConcurrencyException</c> outside the service
/// that raised it: EF's exception names EF, and a caller should never learn the
/// persistence layer's vocabulary from an error body.
/// </summary>
public sealed class ConcurrencyConflictException(string message, string currentVersion)
    : Exception(message)
{
    /// <summary>Base64 ROWVER as the database holds it now.</summary>
    public string CurrentVersion { get; } = currentVersion;
}
