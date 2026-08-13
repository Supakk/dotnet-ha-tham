using System.Text.Json.Serialization;

namespace Mammod.Data;

/// <summary>
/// Credentials for the systems TMS connects out to.
///
/// These are settings, but not the same kind as the preferences on /settings: a
/// page size lives in the browser because it is one person's taste, while a
/// client secret belongs to the installation. So the values go through the API
/// like any other record — and secrets only ever come back masked.
///
/// The plain values are held here in memory only because this stands in for a
/// server with a database. A real deployment encrypts them at rest. Either way
/// the rule below is the important one: nothing in the client ever needs the
/// plain value back, so it is never sent.
/// </summary>
public sealed record IntegrationConfig
{
    public required string Key { get; init; }
    public bool Enabled { get; init; }
    /// <summary>Plain fields verbatim, secrets as a mask like ••••3f9a.</summary>
    public Dictionary<string, string> Values { get; init; } = [];
    /// <summary>Which field names came back masked, so the form knows not to resend them.</summary>
    public List<string> MaskedFields { get; init; } = [];

    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? UpdatedAt { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? UpdatedBy { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? LastTestAt { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public bool? LastTestOk { get; init; }
    [JsonIgnore(Condition = JsonIgnoreCondition.WhenWritingNull)]
    public string? LastTestMessage { get; init; }
}

/// <summary>
/// A save carries only the fields the user actually touched. Sending the whole
/// form back would write the mask string into the secret the moment someone
/// edits an unrelated field — the classic way a working integration breaks on a
/// save that "changed nothing".
/// </summary>
public sealed record IntegrationConfigInput(bool Enabled, Dictionary<string, string>? Changed);

public sealed record IntegrationTestResult(bool Ok, string Message, string At);

/// <summary>One field on one integration's form.</summary>
public sealed record ConfigField(string Name, string Label, string Kind, bool Required = false);

public sealed class IntegrationConfigStore
{
    private readonly object _gate = new();

    /// <summary>
    /// The five systems, and only those. SAP and WMS are deliberately absent: TMS
    /// has no connection to either, and offering fields for them would invite
    /// someone to fill in credentials that nothing reads.
    /// </summary>
    private static readonly Dictionary<string, ConfigField[]> Definitions = new()
    {
        ["backend"] =
        [
            new("baseUrl", "Base URL", "url", Required: true),
            new("timeoutMs", "Timeout (ms)", "text"),
        ],
        ["oms"] =
        [
            new("baseUrl", "Base URL", "url", Required: true),
            new("tenant", "Tenant", "text"),
            new("clientId", "Client ID", "text", Required: true),
            new("clientSecret", "Client Secret", "secret", Required: true),
            new("callbackToken", "Callback Token", "secret"),
        ],
        ["mmx"] =
        [
            new("endpointUrl", "Endpoint URL", "url", Required: true),
            new("apiKey", "API Key", "secret", Required: true),
            new("senderCode", "Sender Code", "text"),
        ],
        ["routing"] =
        [
            new("baseUrl", "Base URL", "url"),
        ],
        ["telerik"] =
        [
            new("baseUrl", "Base URL", "url"),
            new("reportKey", "ชื่อรายงานใบผ่าน", "text"),
            new("apiKey", "API Key", "secret"),
        ],
    };

    /// <summary>What a masked secret looks like coming back — never a prefix of the real one.</summary>
    private static string Mask(string value) =>
        $"••••{(value.Length <= 4 ? value : value[^4..])}";

    private readonly Dictionary<string, string> _secrets = new()
    {
        ["oms:clientSecret"] = "s3cr3t-oms-9f3a",
        ["mmx:apiKey"] = "mmx-live-key-77b2",
    };

    private List<IntegrationConfig> _configs;

    public IntegrationConfigStore()
    {
        _configs =
        [
            new() { Key = "backend", Enabled = false, Values = new() { ["baseUrl"] = "", ["timeoutMs"] = "20000" } },
            new()
            {
                Key = "oms",
                Enabled = true,
                Values = new()
                {
                    ["baseUrl"] = "https://oms.kmto.local/api",
                    ["tenant"] = "MAMMOD",
                    ["clientId"] = "tms-mammod",
                    ["clientSecret"] = Mask("s3cr3t-oms-9f3a"),
                    ["callbackToken"] = "",
                },
                MaskedFields = ["clientSecret"],
                UpdatedAt = "2026-08-03T04:12:00.000Z",
                UpdatedBy = "admin : Next",
                LastTestAt = "2026-08-05T01:30:00.000Z",
                LastTestOk = true,
                LastTestMessage = "ตอบกลับใน 240 ms",
            },
            new()
            {
                Key = "mmx",
                Enabled = true,
                Values = new()
                {
                    ["endpointUrl"] = "https://mmx.local/manifest",
                    ["apiKey"] = Mask("mmx-live-key-77b2"),
                    ["senderCode"] = "MAMMOD-TH",
                },
                MaskedFields = ["apiKey"],
                UpdatedAt = "2026-08-03T04:20:00.000Z",
                UpdatedBy = "admin : Next",
                LastTestAt = "2026-08-05T01:31:00.000Z",
                LastTestOk = false,
                LastTestMessage = "MMX ตอบ 401 — API Key ถูกเพิกถอนแล้ว",
            },
            new() { Key = "routing", Enabled = true, Values = new() { ["baseUrl"] = "" } },
            new() { Key = "telerik", Enabled = false, Values = new() { ["baseUrl"] = "", ["reportKey"] = "GatePass.trdp", ["apiKey"] = "" } },
        ];
    }

    private static string Now() => DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

    public List<IntegrationConfig> List()
    {
        lock (_gate) return [.. _configs.Select(c => c with { Values = new(c.Values) })];
    }

    public IntegrationConfig Save(string key, IntegrationConfigInput input)
    {
        lock (_gate)
        {
            var current = _configs.FirstOrDefault(c => c.Key == key)
                ?? throw DomainException.NotFound("ไม่พบการเชื่อมต่อนี้");
            var fields = Definitions[key];

            var values = new Dictionary<string, string>(current.Values);
            var masked = current.MaskedFields.ToHashSet();

            foreach (var (name, value) in input.Changed ?? [])
            {
                var field = fields.FirstOrDefault(f => f.Name == name)
                    ?? throw new DomainException($"ไม่รู้จักฟิลด์ {name}");

                if (field.Kind == "secret")
                {
                    // A cleared secret is a removal, not a mask of nothing.
                    if (value == "")
                    {
                        _secrets.Remove($"{key}:{name}");
                        values[name] = "";
                        masked.Remove(name);
                    }
                    else
                    {
                        _secrets[$"{key}:{name}"] = value;
                        values[name] = Mask(value);
                        masked.Add(name);
                    }
                }
                else
                {
                    values[name] = value;
                }
            }

            var updated = current with
            {
                Enabled = input.Enabled,
                Values = values,
                MaskedFields = [.. masked],
                UpdatedAt = Now(),
                UpdatedBy = "admin : Next",
            };

            AssertComplete(key, updated);
            _configs = [.. _configs.Select(c => c.Key == key ? updated : c)];
            return updated with { Values = new(updated.Values) };
        }
    }

    /// <summary>Required fields have to be there before an integration may be switched on.</summary>
    private static void AssertComplete(string key, IntegrationConfig config)
    {
        if (!config.Enabled) return;

        var missing = Definitions[key]
            .Where(f => f.Required && (config.Values.GetValueOrDefault(f.Name) ?? "").Trim() == "")
            .Select(f => f.Label)
            .ToList();

        if (missing.Count > 0)
            throw new DomainException($"เปิดใช้งานไม่ได้ — ยังไม่ได้กรอก {string.Join(", ", missing)}");
    }

    public IntegrationTestResult Test(string key)
    {
        lock (_gate)
        {
            var config = _configs.FirstOrDefault(c => c.Key == key)
                ?? throw DomainException.NotFound("ไม่พบการเชื่อมต่อนี้");
            var fields = Definitions[key];
            var at = Now();

            var missing = fields
                .Where(f => f.Required && (config.Values.GetValueOrDefault(f.Name) ?? "").Trim() == "")
                .Select(f => f.Label)
                .ToList();

            // Whether the stored secret exists is all this can honestly check
            // without making the outbound call for real. Replace this method body
            // with that call — an HttpClient GET against the stored base URL — and
            // the screen above it needs no change at all.
            var result = missing.Count > 0
                ? new IntegrationTestResult(false, $"ยังไม่ได้กรอก {string.Join(", ", missing)}", at)
                : fields.Any(f => f.Kind == "secret" && f.Required && !_secrets.ContainsKey($"{key}:{f.Name}"))
                    ? new IntegrationTestResult(false, "ไม่พบ secret ที่บันทึกไว้", at)
                    : new IntegrationTestResult(true, "ตอบกลับใน 240 ms", at);

            _configs = [.. _configs.Select(c => c.Key == key
                ? c with { LastTestAt = result.At, LastTestOk = result.Ok, LastTestMessage = result.Message }
                : c)];

            return result;
        }
    }
}
