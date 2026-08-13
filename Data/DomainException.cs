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
