using Mammod.Models;

namespace Mammod.Data;

/// <summary>
/// Delivery orders, kept apart from <see cref="TmsStore"/> because nothing in the
/// transport flow reads them — they are their own list screen, and sharing a
/// store would only mean sharing a lock with writes they have nothing to do with.
/// </summary>
public sealed class DeliveryOrderStore
{
    private readonly object _gate = new();

    private static readonly string[] Warehouses = ["คลัง MAIN", "คลัง BANGNA", "คลัง LADKRABANG"];
    private static readonly string[] Vendors = ["Coco Duck Co.", "Central Retail", "Big C", "Makro", "Villa Market"];
    private static readonly string[] Users = ["สมชาย ใจดี", "วิชัย พงษ์ทอง", "ประเสริฐ ศรีสุข"];
    private static readonly string[] Statuses = ["pending", "in_transit", "delivered", "cancelled"];

    /// <summary>Deterministic seed, so reloads during development stay comparable.</summary>
    private List<DeliveryOrder> _orders =
        [.. Enumerable.Range(0, 27).Select(i => new DeliveryOrder
        {
            Id = $"do-{i + 1}",
            DeliveryNo = $"CRN-{24091 - i}",
            // Counted back from 13 February by day, as AddDays rather than by
            // building a date out of `13 - i % 14`: at i = 13 that arithmetic asks
            // for the 0th of February, which JavaScript quietly rolls back to
            // 31 January and .NET refuses outright.
            CreatedDate = new DateTime(2026, 2, 13, 0, 0, 0, DateTimeKind.Utc)
                .AddDays(-(i % 14))
                .ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
            Warehouse = Warehouses[i % Warehouses.Length],
            CreatedBy = Users[i % Users.Length],
            Vendor = Vendors[i % Vendors.Length],
            Status = Statuses[i % Statuses.Length],
        })];

    private int _nextId = 28;

    public Paginated<DeliveryOrder> List(string? search, string? status, string? sort, int page, int pageSize)
    {
        lock (_gate)
        {
            var term = (search ?? "").Trim();

            var filtered = _orders.Where(o =>
            {
                var matchesStatus = string.IsNullOrEmpty(status) || status == "all" || o.Status == status;
                var matchesTerm = term == ""
                    || o.DeliveryNo.Contains(term, StringComparison.OrdinalIgnoreCase)
                    || o.Vendor.Contains(term, StringComparison.OrdinalIgnoreCase)
                    || o.Warehouse.Contains(term, StringComparison.OrdinalIgnoreCase)
                    || o.CreatedBy.Contains(term, StringComparison.OrdinalIgnoreCase);
                return matchesStatus && matchesTerm;
            });

            // Ordinal, not culture-aware: these are ISO timestamps and running
            // numbers, and a Thai collation would order them by rules meant for
            // words. The client sorts the same way.
            var sorted = sort switch
            {
                "createdDate:asc" => filtered.OrderBy(o => o.CreatedDate, StringComparer.Ordinal),
                "deliveryNo:asc" => filtered.OrderBy(o => o.DeliveryNo, StringComparer.Ordinal),
                _ => filtered.OrderByDescending(o => o.CreatedDate, StringComparer.Ordinal),
            };

            var all = sorted.ToList();
            var size = pageSize < 1 ? 10 : pageSize;
            var current = page < 1 ? 1 : page;
            var items = all.Skip((current - 1) * size).Take(size).ToList();

            return new Paginated<DeliveryOrder>(items, all.Count, current, size);
        }
    }

    public DeliveryOrder Create(DeliveryOrder input)
    {
        lock (_gate)
        {
            // Id, running number and timestamp are the server's to assign, so
            // whatever the client sent for them is replaced rather than trusted.
            var created = input with
            {
                Id = $"do-{_nextId}",
                DeliveryNo = $"CRN-{24091 + _nextId}",
                CreatedDate = DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ"),
            };
            _nextId += 1;
            _orders = [created, .. _orders];
            return created;
        }
    }

    public DeliveryOrder Update(string id, DeliveryOrder input)
    {
        lock (_gate)
        {
            var existing = Find(id);
            var updated = input with
            {
                Id = id,
                DeliveryNo = existing.DeliveryNo,
                CreatedDate = existing.CreatedDate,
            };
            _orders = [.. _orders.Select(o => o.Id == id ? updated : o)];
            return updated;
        }
    }

    public void Remove(string id)
    {
        lock (_gate)
        {
            Find(id);
            _orders = [.. _orders.Where(o => o.Id != id)];
        }
    }

    private DeliveryOrder Find(string id) =>
        _orders.FirstOrDefault(o => o.Id == id)
        ?? throw DomainException.NotFound($"ไม่พบรายการนำส่ง {id}");
}
