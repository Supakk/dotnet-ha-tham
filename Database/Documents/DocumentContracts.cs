namespace Mammod.Database.Documents;

/// <summary>
/// The contracts the document layer is built from. Phase 3 defines them and
/// nothing else — the implementations arrive with the services, so that the
/// shape can be argued about before behaviour depends on it.
///
/// The split is deliberate and is the whole point of the refactor:
///
/// <list type="bullet">
/// <item><b>Policy</b> answers "is this allowed" and nothing more. No I/O.</item>
/// <item><b>Repository</b> answers "load and save this" and nothing more. No rules.</item>
/// <item><b>Service</b> orchestrates: open a transaction, ask policy, use
/// repositories, write audit, commit.</item>
/// </list>
///
/// Controllers do none of the three. The rule that used to live as
/// <c>AssertStatus(...)</c> beside the mutation now lives in one place, which is
/// what makes it possible to answer "when can this be cancelled" without reading
/// a thousand lines.
/// </summary>

/// <summary>
/// Which warehouse the request is acting on.
///
/// The database is keyed by warehouse all the way down — every PK starts with
/// <c>WHSEID</c> — so every query needs one. Today it comes from configuration
/// and is always <c>WSK</c>; it is an interface anyway so that the day a second
/// warehouse appears, the change is one implementation rather than a search for
/// every hard-coded literal.
/// </summary>
public interface IWarehouseContext
{
    string CurrentWarehouseId { get; }
}

/// <summary>
/// Who is acting, for the audit columns. Separate from
/// <see cref="IWarehouseContext"/> because they change for different reasons.
/// </summary>
public interface IActorContext
{
    string CurrentUser { get; }

    /// <summary>Correlates every row written by one HTTP request.</summary>
    string RequestId { get; }
}

// ── สถานะ · domain status ───────────────────────────────────────────────────

/// <summary>
/// Plan status, uppercase, matching <c>CK_DOC_TRANSPORT_PLAN_STATUS</c> exactly.
/// The database already refuses anything else, so these are the whole set.
/// </summary>
public static class PlanStatus
{
    public const string Draft = "DRAFT";
    public const string Issued = "ISSUED";
    public const string Cancelled = "CANCELLED";
}

/// <summary>
/// Shipment status. <c>DELETED</c> is a soft delete — the row stays, out of the
/// normal list. There is deliberately no <c>INVOICED</c>: invoicing is a fact
/// recorded alongside the lifecycle, not a stage of it, so a shipment that has
/// been invoiced still says whether it was delivered.
/// </summary>
public static class ShipmentStatus
{
    public const string Draft = "DRAFT";
    public const string Confirmed = "CONFIRMED";
    public const string Sent = "SENT";
    public const string Error = "ERROR";
    public const string Completed = "COMPLETED";
    public const string Cancelled = "CANCELLED";
    public const string Deleted = "DELETED";
}

/// <summary>
/// A send attempt's own lifecycle, which is not the shipment's.
///
/// The distinction the old code missed: pressing "send" does not mean the load
/// has gone. <c>SEND_REQUESTED</c> is ours, <c>ACKED</c> is the first word from
/// MMX, and only then is the shipment <c>SENT</c>. <c>TIMEOUT</c> is not a
/// failure — MMX may well have taken the work — so it leaves the shipment where
/// it is and waits for a callback or a reconciliation.
///
/// These six values are exactly what <c>CK_TMS_SEND_ATTEMPT_STATUS</c> allows,
/// and they are written to the column the table calls <c>STATUS</c> — mapped as
/// <see cref="ShipmentSendAttemptRow.Status"/>. The type keeps the name
/// "outcome" because that is what the domain calls it; the column keeps the name
/// the schema gave it. Neither is a mistake, and the mapping is the one place
/// they meet.
/// </summary>
public static class SendAttemptOutcome
{
    public const string SendRequested = "SEND_REQUESTED";
    public const string Sending = "SENDING";
    public const string Acked = "ACKED";
    public const string Success = "SUCCESS";
    public const string Failed = "FAILED";
    public const string Timeout = "TIMEOUT";
}

/// <summary>What a row in TMS_DOCUMENT_AUDIT records having happened.</summary>
public static class AuditAction
{
    public const string Created = "CREATED";
    public const string Updated = "UPDATED";
    public const string Issued = "ISSUED";
    public const string Confirmed = "CONFIRMED";
    public const string Sent = "SENT";
    public const string Retry = "RETRY";
    public const string MmxAck = "MMX_ACK";
    public const string MmxSuccess = "MMX_SUCCESS";
    public const string MmxError = "MMX_ERROR";
    public const string Cancelled = "CANCELLED";
    public const string Deleted = "DELETED";
    public const string Reissued = "REISSUED";
    public const string Invoiced = "INVOICED";
    public const string CallbackIgnored = "CALLBACK_IGNORED";
    public const string CallbackAnomaly = "CALLBACK_ANOMALY";
}

// ── กติกา · domain policy ───────────────────────────────────────────────────

/// <summary>
/// Why an action was refused, so the caller can turn it into the right status
/// code without re-deciding: a rule about state is a 409, a rule about the
/// contents of the request is a 422.
/// </summary>
public enum RefusalKind
{
    /// <summary>Allowed.</summary>
    None,
    /// <summary>The document is not in a state where this makes sense — 409.</summary>
    State,
    /// <summary>The document is missing something this action needs — 422.</summary>
    Incomplete,
}

public readonly record struct PolicyResult(RefusalKind Kind, string Message)
{
    public static PolicyResult Allow() => new(RefusalKind.None, "");
    public static PolicyResult WrongState(string message) => new(RefusalKind.State, message);
    public static PolicyResult Incomplete(string message) => new(RefusalKind.Incomplete, message);
    public bool IsAllowed => Kind == RefusalKind.None;
}

/// <summary>
/// Every rule about when a plan may change, in one place. Pure: it is handed the
/// row and answers, so it can be tested without a database.
/// </summary>
public interface ITransportPlanPolicy
{
    PolicyResult CanEdit(TransportPlanRow plan);
    PolicyResult CanSetStops(TransportPlanRow plan);
    PolicyResult CanIssue(TransportPlanRow plan, int stopCount);
    PolicyResult CanCancel(TransportPlanRow plan, ShipmentRow? currentShipment);
    PolicyResult CanDelete(TransportPlanRow plan);
}

/// <summary>
/// Every rule about when a shipment may change.
///
/// <c>CanCancel</c> refuses <c>SENT</c> on purpose: the load may already be with
/// MMX, and taking it back is a conversation, not a button. There is no
/// force-cancel until there is a real cancellation contract to call.
/// </summary>
public interface IShipmentPolicy
{
    PolicyResult CanEdit(ShipmentRow shipment);
    PolicyResult CanConfirm(ShipmentRow shipment);
    PolicyResult CanSend(ShipmentRow shipment);
    PolicyResult CanRetry(ShipmentRow shipment);
    PolicyResult CanCancel(ShipmentRow shipment);
    PolicyResult CanDelete(ShipmentRow shipment);
    PolicyResult CanReissue(ShipmentRow shipment);
    PolicyResult CanMarkInvoiced(ShipmentRow shipment);

    /// <summary>
    /// Whether a callback should be applied at all. A late or duplicate one is
    /// not an error to the sender — it is recorded and ignored.
    /// </summary>
    PolicyResult CanApplyExternalStatus(ShipmentRow shipment, string outcome);
}

// ── ที่เก็บ · repositories ──────────────────────────────────────────────────

/// <summary>
/// Loading and saving plans. Every method is warehouse-scoped by the
/// implementation — no caller passes <c>WHSEID</c>, and no caller can forget to.
/// </summary>
public interface ITransportPlanRepository
{
    Task<TransportPlanRow?> GetAsync(string planKey, CancellationToken ct = default);

    /// <summary>With lines loaded — for issuing, where the count is a rule.</summary>
    Task<TransportPlanRow?> GetWithLinesAsync(string planKey, CancellationToken ct = default);

    Task<IReadOnlyList<TransportPlanRow>> ListAsync(CancellationToken ct = default);
    Task AddAsync(TransportPlanRow plan, CancellationToken ct = default);
    Task ReplaceLinesAsync(string planKey, IReadOnlyList<string> orderKeys, CancellationToken ct = default);
}

public interface IShipmentRepository
{
    Task<ShipmentRow?> GetAsync(string shipmentKey, CancellationToken ct = default);
    Task<ShipmentRow?> GetWithStopsAsync(string shipmentKey, CancellationToken ct = default);

    /// <summary>Excludes <c>DELETED</c> — the normal list never shows them.</summary>
    Task<IReadOnlyList<ShipmentRow>> ListAsync(CancellationToken ct = default);

    Task<IReadOnlyList<ShipmentRow>> ListDeletedAsync(CancellationToken ct = default);
    Task AddAsync(ShipmentRow shipment, CancellationToken ct = default);

    /// <summary>The shipments issued from a plan, newest first — the lineage chain.</summary>
    Task<IReadOnlyList<ShipmentRow>> ListForPlanAsync(string planKey, CancellationToken ct = default);
}

/// <summary>
/// The pending pool, which is a question and not a table: the delivery orders
/// that no live plan and no live shipment has claimed.
/// </summary>
public interface IDeliveryOrderQuery
{
    Task<IReadOnlyList<DeliveryOrderRow>> GetAvailableAsync(CancellationToken ct = default);

    /// <summary>
    /// Whether these specific orders are still free — asked before taking them,
    /// so the answer given to the user is about the orders they picked rather
    /// than a unique-index violation.
    /// </summary>
    Task<IReadOnlyList<string>> FilterAvailableAsync(
        IReadOnlyList<string> orderKeys, CancellationToken ct = default);
}

public interface IShipmentSendAttemptRepository
{
    Task<ShipmentSendAttemptRow?> GetAsync(int serialKey, CancellationToken ct = default);
    Task<ShipmentSendAttemptRow?> GetByIdempotencyKeyAsync(string key, CancellationToken ct = default);
    Task<ShipmentSendAttemptRow?> GetLatestAsync(string shipmentKey, CancellationToken ct = default);
    Task<IReadOnlyList<ShipmentSendAttemptRow>> ListAsync(string shipmentKey, CancellationToken ct = default);
    Task AddAsync(ShipmentSendAttemptRow attempt, CancellationToken ct = default);
}

/// <summary>
/// Hands out MN-YYYYMM-NNNN and PL-YYYYMM-NNNN.
///
/// Must run inside the caller's transaction: a number handed out and then rolled
/// back leaves a gap, and a number handed out twice is worse. That is why this
/// is an interface over a table rather than a counter in the process — a static
/// field cannot survive a restart, and <c>MAX(number)+1</c> cannot survive two
/// requests.
/// </summary>
public interface IDocumentNumberAllocator
{
    /// <param name="prefix">MN or PL.</param>
    /// <param name="on">The date whose YYYYMM the number belongs to.</param>
    Task<string> AllocateAsync(string prefix, DateOnly on, CancellationToken ct = default);
}

public interface IDocumentAuditWriter
{
    Task WriteAsync(DocumentAuditRow entry, CancellationToken ct = default);
}

// ── บริการ · application services ───────────────────────────────────────────

/// <summary>
/// Orchestration for plans. Each method owns a transaction; none of them is a
/// thin wrapper over the repository, or it would not be worth the layer.
/// </summary>
public interface ITransportPlanService
{
    Task<TransportPlanRow> CreateAsync(PlanHeaderInput input, CancellationToken ct = default);
    Task<TransportPlanRow> UpdateAsync(string planKey, PlanHeaderInput input, string ifMatch, CancellationToken ct = default);
    Task<TransportPlanRow> SetStopsAsync(string planKey, IReadOnlyList<string> orderKeys, string ifMatch, CancellationToken ct = default);

    /// <summary>
    /// One transaction: allocate the number, insert the shipment, point the plan
    /// at it and lock the plan. Anything short of all of it rolls back.
    /// </summary>
    Task<(TransportPlanRow Plan, ShipmentRow Shipment)> IssueAsync(string planKey, string ifMatch, CancellationToken ct = default);

    Task<TransportPlanRow> CancelAsync(string planKey, string reason, string ifMatch, CancellationToken ct = default);
}

public interface IShipmentService
{
    Task<ShipmentRow> UpdateAsync(string shipmentKey, ShipmentHeaderInput input, string ifMatch, CancellationToken ct = default);
    Task<ShipmentRow> ConfirmAsync(string shipmentKey, string ifMatch, CancellationToken ct = default);

    /// <summary>Creates an attempt and hands it to MMX. Does not by itself mean SENT.</summary>
    Task<ShipmentRow> SendAsync(string shipmentKey, string ifMatch, CancellationToken ct = default);

    /// <summary>Same shipment, same number, a new attempt.</summary>
    Task<ShipmentRow> RetryAsync(string shipmentKey, string ifMatch, CancellationToken ct = default);

    Task<ShipmentRow> CancelAsync(string shipmentKey, string reason, string ifMatch, CancellationToken ct = default);
    Task<ShipmentRow> DeleteAsync(string shipmentKey, string? reason, string ifMatch, CancellationToken ct = default);

    /// <summary>
    /// A new shipment replacing a cancelled one. Route and origin come from the
    /// plan, the load from whatever is still free, and the vehicle and driver
    /// from nowhere — those are usually why it was cancelled.
    /// </summary>
    Task<ReissueResult> ReissueAsync(string shipmentKey, CancellationToken ct = default);

    /// <summary>Records the invoice. Does not touch the lifecycle status.</summary>
    Task<ShipmentRow> MarkInvoicedAsync(string shipmentKey, string ifMatch, CancellationToken ct = default);

    Task<ShipmentRow> ApplyExternalStatusAsync(ExternalStatusInput input, CancellationToken ct = default);
}

// ── input / result ──────────────────────────────────────────────────────────

public sealed record PlanHeaderInput(
    DateOnly DeliveryDate,
    string RouteCode,
    string? Note);

public sealed record ShipmentHeaderInput(
    string? VehicleKey,
    string? DriverKey,
    string? TransporterKey,
    string? LicensePlate,
    string? DriverName,
    string? DriverMobile,
    int? AssistantCount,
    string? Door,
    string? SealNo,
    decimal? TripPrice,
    decimal? PriceAdd,
    decimal? PriceDeduct,
    string? FreightNote,
    string? Notes);

/// <summary>
/// <paramref name="Unavailable"/> is the count the screen has to show: the
/// orders the old shipment held that something else has taken since. A reissue
/// that is quietly short is worse than one that says so.
/// </summary>
public sealed record ReissueResult(
    ShipmentRow Cancelled,
    ShipmentRow Created,
    int Unavailable);

/// <summary>
/// What MMX sends back. The idempotency key identifies the attempt, so a
/// callback that arrives twice or late can be matched to what it is answering
/// rather than guessed at from the shipment's current state.
/// </summary>
public sealed record ExternalStatusInput(
    string ShipmentKey,
    string IdempotencyKey,
    string Outcome,
    string? Message,
    string? ErrorCode);
