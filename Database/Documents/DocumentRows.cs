namespace Mammod.Database.Documents;

/// <summary>
/// The document tables, as EF Core sees them.
///
/// These are <b>rows</b>, not the domain. They carry the database's own names
/// and shapes — <c>WHSEID</c>, <c>SHIPMENTKEY</c>, <c>ADDWHO</c> — so that anyone
/// comparing this file against the table can do it line by line. Translation to
/// <c>Manifest</c> / <c>TransportPlan</c> happens above, in the services.
///
/// <b>Not every column is mapped.</b> <c>DOC_SHIPMENT_DETAIL_LINE</c> alone has 55,
/// most of them WMS lot attributes (<c>LOTTABLE01..10</c>, <c>PACKKEY</c>,
/// <c>DAMAGEQTY</c>) that TMS neither reads nor writes. Mapping them would be dead
/// weight and would invite someone to start using them from the wrong module —
/// the same reasoning <see cref="AppDbContext"/> gives for the master tables.
/// Columns left out keep their database defaults on insert.
///
/// Identity is composite everywhere: <c>(WHSEID, KEY)</c>. <c>SERIALKEY</c> is an
/// IDENTITY surrogate the schema carries for the WMS's own tooling; nothing
/// references it, so it is not the key here either.
/// </summary>

/// <summary>DOC_TRANSPORT_PLAN — แผนขนส่ง.</summary>
public sealed class TransportPlanRow
{
    public string WhseId { get; set; } = "";
    public string PlanKey { get; set; } = "";
    public DateTime PlanDate { get; set; }
    public DateTime DeliveryDate { get; set; }

    /// <summary>
    /// Legacy compatibility only. Planning is by route — see the note on
    /// <see cref="Route"/> — and this is kept because the WMS reads it. New
    /// business rules must not branch on it.
    /// </summary>
    public string? Zone { get; set; }

    /// <summary>The planning authority. FK to MST_ROUTE.</summary>
    public string? Route { get; set; }

    /// <summary>
    /// The manifest currently issued from this plan — the schema's own
    /// <c>currentManifestId</c>. Repointed on reissue; the plan itself stays
    /// ISSUED.
    /// </summary>
    public string? ShipmentKey { get; set; }

    public int? TotalOrder { get; set; }
    public decimal? TotalWeight { get; set; }
    public decimal? TotalCube { get; set; }

    /// <summary>DRAFT | ISSUED | CANCELLED — enforced by CK_DOC_TRANSPORT_PLAN_STATUS.</summary>
    public string Status { get; set; } = "";

    public string? CancelReason { get; set; }
    public string? Notes { get; set; }

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }
    public DateTime? EditDate { get; set; }
    public string? EditWho { get; set; }

    /// <summary>
    /// The concurrency token. Assigned by SQL Server on every write — never set
    /// this in code.
    /// </summary>
    public byte[]? RowVer { get; set; }

    public ICollection<TransportPlanLineRow> Lines { get; set; } = [];
}

/// <summary>
/// DOC_TRANSPORT_PLAN_LINE — the orders a plan is holding.
///
/// <c>UX_DOC_TRANSPORT_PLAN_LINE_ORDER</c> is a unique index on <c>ORDERKEY</c>
/// filtered to <c>STATUS &lt;&gt; 'CANCELLED'</c>: one order can be on at most one
/// live plan, enforced by the database rather than by a lock in one process.
/// </summary>
public sealed class TransportPlanLineRow
{
    public string WhseId { get; set; } = "";
    public string PlanKey { get; set; } = "";
    public string OrderKey { get; set; } = "";
    public string Status { get; set; } = "";

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }
    public DateTime? EditDate { get; set; }
    public string? EditWho { get; set; }

    public TransportPlanRow? Plan { get; set; }
}

/// <summary>DOC_SHIPMENT_HDR — ใบปิดบรรทุก.</summary>
public sealed class ShipmentRow
{
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";

    public DateTime? ShipmentDate { get; set; }
    public DateTime? DeliveryDate { get; set; }

    public string? Route { get; set; }
    public string? Zone { get; set; }
    public string? Door { get; set; }

    public string? TransporterKey { get; set; }
    public string? VehicleKey { get; set; }
    public string? VehicleTypeKey { get; set; }
    public string? DriverKey { get; set; }
    public string? LicensePlate { get; set; }
    public string? DriverName { get; set; }
    public string? DriverMobile { get; set; }
    public string? TrailerId { get; set; }

    public int? TotalStop { get; set; }
    public int? TotalOrder { get; set; }
    public decimal? TotalWeight { get; set; }
    public decimal? TotalCube { get; set; }
    public decimal? MaxWeight { get; set; }
    public decimal? MaxCube { get; set; }

    /// <summary>DRAFT | CONFIRMED | SENT | ERROR | COMPLETED | CANCELLED | DELETED.</summary>
    public string Status { get; set; } = "";

    public string? Notes { get; set; }

    /// <summary>The plan this was issued from. FK on (PLANKEY, WHSEID).</summary>
    public string? PlanKey { get; set; }

    /// <summary>
    /// Lineage: the shipment this one came out of, for both a split and a
    /// reissue. <b>The reason for the lineage is not stored anywhere yet</b> —
    /// see the Phase 3 report; a RELATIONTYPE column has to be added before the
    /// two can be told apart from the row alone.
    /// </summary>
    public string? ParentShipmentKey { get; set; }

    public string? SealNo { get; set; }
    public int? AssistantCount { get; set; }

    public decimal? TripPrice { get; set; }
    public decimal? PriceAdd { get; set; }
    public decimal? PriceDeduct { get; set; }
    public string? FreightNote { get; set; }
    public string? Currency { get; set; }

    public bool? ExpressFlag { get; set; }
    public string? ExpressRequester { get; set; }
    public string? ExpressApprover { get; set; }

    public DateTime? ConfirmDate { get; set; }
    public DateTime? SentDate { get; set; }

    /// <summary>What MMX last said. Cleared on a retry.</summary>
    public string? StatusMessage { get; set; }
    public string? CancelReason { get; set; }

    /// <summary>
    /// When the invoice was raised, and by whom. Deliberately not a status —
    /// see <see cref="ShipmentStatus"/>: overwriting SENT or COMPLETED with an
    /// INVOICED stage would destroy the answer to "did this load arrive". A
    /// shipment can be both delivered and invoiced, and these two columns are
    /// how it says so.
    /// </summary>
    public DateTime? InvoicedAt { get; set; }
    public string? InvoicedBy { get; set; }

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }
    public DateTime? EditDate { get; set; }
    public string? EditWho { get; set; }

    public byte[]? RowVer { get; set; }

    public TransportPlanRow? Plan { get; set; }
    public ICollection<ShipmentStopRow> Stops { get; set; } = [];
    public ICollection<ShipmentDetailRow> Details { get; set; } = [];
    public ICollection<ShipmentStatusLogRow> StatusLogs { get; set; } = [];
}

/// <summary>
/// DOC_SHIPMENT_STOP — a drop on the run.
///
/// This is the row the client's <c>ManifestStop</c> maps to: it carries the
/// address, the customer, the coordinates and the COD amount.
/// </summary>
public sealed class ShipmentStopRow
{
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";
    public int ShipmentStopId { get; set; }

    /// <summary>
    /// Order along the run. Unique per shipment
    /// (<c>UX_SHIPMENT_STOP_SEQ</c>), so two drops cannot claim the same place.
    /// </summary>
    public int StopSeq { get; set; }

    public string? StopType { get; set; }
    public string? CustomerKey { get; set; }
    public string? ShipToKey { get; set; }
    public string? ShipToName { get; set; }
    public string? Address1 { get; set; }
    public string? SubDistrict { get; set; }
    public string? District { get; set; }
    public string? Province { get; set; }
    public string? PostalCode { get; set; }

    /// <summary>Both null or both set — CK_SHIPMENT_STOP_LATLNG.</summary>
    public decimal? Latitude { get; set; }
    public decimal? Longitude { get; set; }

    public string? ContactName { get; set; }
    public string? ContactPhone { get; set; }

    public int? TotalOrder { get; set; }
    public decimal? TotalWeight { get; set; }
    public decimal? TotalCube { get; set; }
    public decimal? CodAmount { get; set; }
    public DateOnly? DueDate { get; set; }

    /// <summary>A site, branch or third party; empty means the address above.</summary>
    public string? DeliverTo { get; set; }

    public string? DeliveryStatus { get; set; }
    public string? PodStatus { get; set; }
    public string? Remark { get; set; }
    public string Status { get; set; } = "";

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }
    public DateTime? EditDate { get; set; }
    public string? EditWho { get; set; }

    public byte[]? RowVer { get; set; }

    public ShipmentRow? Shipment { get; set; }
}

/// <summary>
/// DOC_SHIPMENT_DETAIL — which delivery order is riding on this shipment.
///
/// Order level, not product level: the products are in
/// <see cref="ShipmentDetailLineRow"/>. This is the table that makes "an order
/// is on exactly one live shipment" true, through
/// <c>UX_SHIPMENT_DETAIL_ORDER</c> — unique on <c>ORDERKEY</c> filtered to
/// <c>STATUS &lt;&gt; 'CANCELLED'</c>.
/// </summary>
public sealed class ShipmentDetailRow
{
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";
    public int ShipmentDetailId { get; set; }

    /// <summary>Which drop on the run this order is delivered at.</summary>
    public int? ShipmentStopId { get; set; }

    public string OrderKey { get; set; } = "";
    public string? ExternOrderKey { get; set; }
    public string? CustomerKey { get; set; }
    public string? Route { get; set; }
    public string? Zone { get; set; }

    public DateTime? OrderDate { get; set; }
    public DateTime? RequiredDeliveryDate { get; set; }
    public string? OrderStatus { get; set; }

    public decimal? OutWeight { get; set; }
    public decimal? OutCube { get; set; }

    public string Status { get; set; } = "";

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }
    public DateTime? EditDate { get; set; }
    public string? EditWho { get; set; }

    public byte[]? RowVer { get; set; }

    public ShipmentRow? Shipment { get; set; }
    public ShipmentStopRow? Stop { get; set; }
}

/// <summary>
/// DOC_SHIPMENT_DETAIL_LINE — the products on one order of one shipment.
///
/// TMS plans and tracks whole orders, so only the identifying and quantity
/// columns are mapped. The WMS lot attributes are deliberately absent.
/// </summary>
public sealed class ShipmentDetailLineRow
{
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";
    public int ShipmentDetailId { get; set; }
    public int ShipmentLineNo { get; set; }

    public string OrderKey { get; set; } = "";
    public string OrderLineNo { get; set; } = "";
    public string Sku { get; set; } = "";
    public string? Description { get; set; }

    public decimal OrderQty { get; set; }
    public decimal ShipmentQty { get; set; }
    public decimal DeliveredQty { get; set; }
    public decimal ShortQty { get; set; }
    public string? Uom { get; set; }

    public decimal? GrossWgt { get; set; }
    public decimal? Cube { get; set; }

    public string Status { get; set; } = "";

    public DateTime AddDate { get; set; }
    public string? AddWho { get; set; }

    public ShipmentDetailRow? Detail { get; set; }
}

/// <summary>
/// DOC_SHIPMENT_STATUS_LOG — the shipment's own lifecycle history.
///
/// Already in the schema and already populated, so it stays the record of
/// shipment status changes. <see cref="DocumentAuditRow"/> covers what this
/// cannot: plan transitions, the reason, the actor's request id.
/// </summary>
public sealed class ShipmentStatusLogRow
{
    public int SerialKey { get; set; }
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";
    public string? FromStatus { get; set; }
    public string? ToStatus { get; set; }

    /// <summary>TMS | MMX | WMS — who caused the change.</summary>
    public string? SourceSystem { get; set; }
    public string? Message { get; set; }
    public DateTime ChangeDate { get; set; }
    public string? ChangeWho { get; set; }

    public ShipmentRow? Shipment { get; set; }
}

// ── ตารางที่ TMS เป็นเจ้าของ · TMS-owned tables ─────────────────────────────
//
// ⚠ ยังไม่มีใน MMDEV — สร้างโดย migration 004–006 ที่ยังไม่ได้เขียน
//    mapping ไว้ล่วงหน้าเพื่อให้ Phase 4 ต่อได้ทันที แต่ query ก่อนหน้านั้น
//    จะได้ "Invalid object name" ซึ่งถูกต้องแล้ว — ไม่มีตารางก็ต้องไม่ทำงาน

/// <summary>
/// TMS_SHIPMENT_SEND_ATTEMPT — one row per hand-off attempt to MMX.
///
/// Separate from the shipment because a retry is a new attempt against the same
/// document: keeping them on the header would mean either overwriting the last
/// one or growing columns per attempt. The shipment's status is a consequence of
/// the attempts, not a substitute for them.
/// </summary>
public sealed class ShipmentSendAttemptRow
{
    public int SerialKey { get; set; }
    public string WhseId { get; set; } = "";
    public string ShipmentKey { get; set; } = "";

    /// <summary>1 for the first send, then 2, 3 … for each retry.</summary>
    public int AttemptNumber { get; set; }

    /// <summary>New per attempt — what stops a repeated HTTP call being a repeated job.</summary>
    public string IdempotencyKey { get; set; } = "";

    /// <summary>
    /// The document as MMX knows it — the manifest number, identical across
    /// every attempt. This is what lets MMX recognise a retry as the same work.
    /// </summary>
    public string ExternalReference { get; set; } = "";

    public string? RequestId { get; set; }

    /// <summary>SEND_REQUESTED | SENDING | ACKED | SUCCESS | FAILED | TIMEOUT.</summary>
    public string Outcome { get; set; } = "";

    public DateTime CreatedAt { get; set; }
    public string? CreatedBy { get; set; }
    public DateTime? SentAt { get; set; }
    public DateTime? ResponseAt { get; set; }

    public string? ErrorCode { get; set; }
    public string? ErrorMessage { get; set; }
    public string? ResponsePayload { get; set; }

    public ShipmentRow? Shipment { get; set; }
}

/// <summary>
/// TMS_DOCUMENT_AUDIT — what the legacy status log cannot answer.
///
/// Deliberately not a copy of every shipment transition: those are already in
/// <see cref="ShipmentStatusLogRow"/>, and writing both would leave two accounts
/// of the same event to disagree. This carries plan transitions, the reason
/// someone gave, and the request that caused it.
/// </summary>
public sealed class DocumentAuditRow
{
    /// <summary>AUDITID — bigint IDENTITY, filled in by the database.</summary>
    public long AuditId { get; set; }

    public string WhseId { get; set; } = "";

    /// <summary>PLAN | SHIPMENT | SEND_ATTEMPT — CK_TMS_DOCUMENT_AUDIT_TYPE.</summary>
    public string DocumentType { get; set; } = "";

    /// <summary>PLANKEY or SHIPMENTKEY — the business key, not a surrogate.</summary>
    public string DocumentKey { get; set; } = "";

    public string Action { get; set; } = "";
    public string? FromStatus { get; set; }
    public string? ToStatus { get; set; }

    public string? Reason { get; set; }
    public string? RequestId { get; set; }
    public string? ExternalReference { get; set; }

    /// <summary>NOT NULL in the table — every row says who.</summary>
    public string Actor { get; set; } = "";

    public DateTime ChangedAt { get; set; }

    /// <summary>JSON. For anything that does not deserve a column of its own.</summary>
    public string? Metadata { get; set; }
}

/// <summary>
/// TMS_DOCUMENT_NUMBER — the counter behind MN-YYYYMM-NNNN and PL-YYYYMM-NNNN.
///
/// A row per (warehouse, prefix, period) so numbering restarts each month and
/// two warehouses never contend for the same row. Allocation must happen inside
/// the caller's transaction — see <c>IDocumentNumberAllocator</c>.
/// </summary>
public sealed class DocumentNumberRow
{
    public string WhseId { get; set; } = "";

    /// <summary>MN | PL.</summary>
    public string Prefix { get; set; } = "";

    /// <summary>YYYYMM.</summary>
    public string Period { get; set; } = "";

    public int LastNumber { get; set; }

    public byte[]? RowVer { get; set; }
}
