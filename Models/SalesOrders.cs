namespace Mammod.Models;

/// <summary>
/// A sales order — what a customer asked for — and the delivery orders raised
/// against it.
///
/// The two were one thing for as long as there was no sales-order table: the
/// delivery order carried the sales-order number in a text column and nothing
/// else. Splitting them is what makes the question "has this order gone out
/// yet, and how much of it" answerable, because the answer lives in the gap
/// between <see cref="SalesOrderLine.OrderQty"/> and
/// <see cref="SalesOrderLine.ShippedQty"/>.
///
/// One sales order can produce several delivery orders. Stock ran short, the
/// customer asked for it in parts, or it ships from two warehouses — all
/// ordinary, and all impossible to record while the relationship was one to one.
/// </summary>
public sealed record SalesOrder
{
    /// <summary>The sales-order number, e.g. SO-99200011. Unique across warehouses.</summary>
    public required string SoNo { get; init; }
    public required string WarehouseCode { get; init; }
    public string CustomerId { get; init; } = "";
    public string CustomerName { get; init; } = "";

    /// <summary>When the customer placed it.</summary>
    public required string OrderDate { get; init; }
    /// <summary>When they asked to have it. Null if they did not say.</summary>
    public string? RequestedDate { get; init; }

    /// <summary>Which system it arrived from — OMS, SAP, or entered by hand.</summary>
    public string Source { get; init; } = "OMS";

    /// <summary>
    /// NEW — nothing raised against it · PARTIAL — some of it has gone out ·
    /// CLOSED — all of it has · CANCELLED.
    ///
    /// Upper case because that is what the database stores. The lower-case
    /// statuses the client uses elsewhere are a different vocabulary belonging
    /// to transport documents, and flattening the two would lose the distinction
    /// between "this order is closed" and "this manifest is completed".
    /// </summary>
    public required string Status { get; init; }

    public decimal TotalAmount { get; init; }
    public string Currency { get; init; } = "THB";

    public List<SalesOrderLine> Lines { get; init; } = [];

    /// <summary>Delivery-order numbers raised against this order, oldest first.</summary>
    public List<string> DeliveryOrderNos { get; init; } = [];
}

public sealed record SalesOrderLine
{
    public required string LineNo { get; init; }
    public required string Sku { get; init; }
    public string Uom { get; init; } = "";

    /// <summary>What was ordered.</summary>
    public decimal OrderQty { get; init; }
    /// <summary>What has been put on delivery orders so far, across all of them.</summary>
    public decimal ShippedQty { get; init; }
    /// <summary>Still to ship. Derived, never stored — two copies would disagree.</summary>
    public decimal OpenQty => OrderQty - ShippedQty;

    public decimal UnitPrice { get; init; }
    public decimal ExtendedPrice { get; init; }
    public string Status { get; init; } = "NEW";
}

/// <summary>A delivery order as the sales-order screen needs to see it.</summary>
public sealed record DeliveryOrderSummary
{
    public required string DoNo { get; init; }
    public required string SoNo { get; init; }
    public required string WarehouseCode { get; init; }
    public string CustomerName { get; init; } = "";
    public string? DeliveryDate { get; init; }
    public string Route { get; init; } = "";
    public string Zone { get; init; } = "";
    public required string Status { get; init; }
}
