namespace Mammod.Database.Documents;

/// <summary>
/// Turning database identity into the single string the API exposes, and back.
///
/// The database identifies a document by <c>(WHSEID, KEY)</c>. The client has
/// one <c>id</c> field. The old code bridged that with invented ids — <c>mn-3</c>,
/// <c>pl-1</c>, <c>s-1</c> — which existed only in memory and meant nothing to
/// the database; the first time masters moved to SQL and documents did not, the
/// two id spaces stopped meeting and every route in the planning screen became
/// unfindable.
///
/// So the public id is the <b>business key</b>: <c>MN-202608-0043</c>,
/// <c>PL-202608-0001</c>. It is already unique per warehouse, it is what people
/// read off the paperwork, and it survives a restart. The warehouse half of the
/// key never crosses the wire — the request already carries it implicitly, via
/// <see cref="IWarehouseContext"/>.
/// </summary>
public static class DocumentIdentity
{
    private const char StopSeparator = ':';

    /// <summary>
    /// A stop has no business key of its own — it is numbered within its
    /// shipment — so its id is the pair, joined. Colon because neither half can
    /// contain one.
    /// </summary>
    public static string StopId(string shipmentKey, int shipmentStopId) =>
        $"{shipmentKey}{StopSeparator}{shipmentStopId}";

    /// <summary>
    /// Reads a stop id back. Returns false rather than throwing: the value came
    /// from a request, so a malformed one is a 400, not a crash.
    /// </summary>
    public static bool TryReadStopId(string? id, out string shipmentKey, out int shipmentStopId)
    {
        shipmentKey = "";
        shipmentStopId = 0;
        if (string.IsNullOrWhiteSpace(id)) return false;

        var cut = id.LastIndexOf(StopSeparator);
        if (cut <= 0 || cut == id.Length - 1) return false;

        if (!int.TryParse(id[(cut + 1)..], out var parsed)) return false;

        shipmentKey = id[..cut];
        shipmentStopId = parsed;
        return true;
    }

    /// <summary>
    /// The concurrency token as it travels: ROWVER is eight bytes, and base64 is
    /// how it survives a JSON field and an <c>If-Match</c> header intact.
    ///
    /// Deliberately not turned into a number. A rowversion is not a counter — it
    /// is a database-wide stamp — and presenting it as "version 6" would invite
    /// someone to send 7.
    /// </summary>
    public static string EncodeVersion(byte[]? rowVersion) =>
        rowVersion is null or { Length: 0 } ? "" : Convert.ToBase64String(rowVersion);

    /// <summary>
    /// Reads a version back. An unreadable one is treated as absent so the
    /// caller answers "you must send If-Match" rather than "your version is
    /// wrong" — different problems, different fixes.
    /// </summary>
    public static bool TryReadVersion(string? encoded, out byte[] rowVersion)
    {
        rowVersion = [];
        if (string.IsNullOrWhiteSpace(encoded)) return false;

        // If-Match arrives quoted more often than not: If-Match: "AAAA...".
        var trimmed = encoded.Trim().Trim('"');
        if (trimmed.StartsWith("W/", StringComparison.Ordinal)) trimmed = trimmed[2..].Trim('"');

        Span<byte> buffer = stackalloc byte[16];
        if (!Convert.TryFromBase64String(trimmed, buffer, out var written) || written == 0) return false;

        rowVersion = buffer[..written].ToArray();
        return true;
    }
}
