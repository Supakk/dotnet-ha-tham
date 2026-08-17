using Mammod.Dtos;
using Mammod.Models;

namespace Mammod.Data;

/// <summary>
/// The whole database, in memory.
///
/// Registered as a singleton, so every request shares one instance and the state
/// survives a page reload — which is the point of running a server instead of the
/// client-side fixtures. It does not survive a restart: this stands in for a real
/// database, it is not one. Swapping it for EF Core later means replacing the
/// lists below with DbSets; the rules in the methods stay where they are.
///
/// Every public method takes <c>_gate</c>. Two requests can arrive at once — the
/// pending pool is shared mutable state, and "take these stops out of the pool"
/// read by two requests at the same time is how one order rides two trucks.
/// </summary>
public sealed class TmsStore
{
    // A plain object, not System.Threading.Lock: that type arrived in .NET 9 and
    // this project targets net8.0 to match the rest of the team's services.
    private readonly object _gate = new();

    private List<ManifestStop> _pendingStops = Seed.PendingStops();
    private List<Manifest> _manifests = Seed.Manifests();
    private List<TransportPlan> _plans = Seed.TransportPlans();
    private List<Warehouse> _warehouses = Seed.Warehouses();
    private List<DeliveryZone> _zones = Seed.DeliveryZones();
    private List<RouteMaster> _routes = Seed.Routes();
    private List<Carrier> _carriers = Seed.Carriers();
    private List<FleetVehicle> _vehicles = Seed.FleetVehicles();
    private List<Driver> _drivers = Seed.Drivers();
    private List<IntegrationMessage> _messages = Seed.IntegrationMessages();

    /// <summary>Past the highest number in the fixtures, so a new draft cannot collide.</summary>
    private int _nextManifest = 44;
    private int _nextPlan = 2;
    private int _nextMessage = 8;
    private int _nextWarehouse = 6;
    private int _nextZone = 11;
    private int _nextRoute = 5;
    private int _nextCarrier = 5;
    private int _nextVehicle = 7;
    private int _nextDriver = 7;

    private static string Now() => DateTime.UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

    /// <summary>
    /// Stands in for the signed-in account. A real deployment stamps this from the
    /// token — a client-supplied author is not something a server would trust.
    /// </summary>
    private const string Author = "admin : Next";

    // ── ใบปิดบรรทุก · manifests ────────────────────────────────────────────────

    public List<Manifest> ListManifests()
    {
        lock (_gate) return [.. _manifests];
    }

    public List<ManifestStop> ListPendingStops()
    {
        lock (_gate) return [.. _pendingStops];
    }

    /// <summary>
    /// Where routes come from when a plan names one.
    ///
    /// Not <c>_routes</c> directly: with a database configured the masters are
    /// served from SQL Server and keyed by their own code — <c>rt-RT-NORTH-01</c>
    /// — while this seed numbers them <c>rt-1</c>. The planning screen offers
    /// whatever <c>GET /routes</c> returned, so looking the choice up in the seed
    /// found none of them and every save was refused with "ไม่พบสายส่งนี้".
    ///
    /// Set once at startup rather than injected, because <c>MasterQueries</c>
    /// already depends on this store and constructor injection the other way
    /// would be a cycle. Unset — plain <c>dotnet run</c> with no database — the
    /// seed is both the source and the answer, which is what it was before.
    /// </summary>
    private Func<List<RouteMaster>>? _routeSource;

    public void UseRouteSource(Func<List<RouteMaster>> source) => _routeSource = source;

    // Called while `_gate` is held, so a configured source runs its query under
    // the lock. It is one indexed read against a master table and the alternative
    // — resolving outside and re-checking inside — buys a race for the trouble.
    private RouteMaster FindRoute(string id) =>
        (_routeSource?.Invoke() ?? _routes).FirstOrDefault(r => r.Id == id)
        ?? throw DomainException.NotFound("ไม่พบสายส่งนี้");

    private Manifest FindManifest(string id) =>
        _manifests.FirstOrDefault(m => m.Id == id)
        ?? throw DomainException.NotFound("ไม่พบใบปิดบรรทุกนี้");

    private Manifest Replace(Manifest updated)
    {
        _manifests = [.. _manifests.Select(m => m.Id == updated.Id ? updated : m)];
        return updated;
    }

    /// <summary>
    /// The transitions the server polices. The client disables the buttons that
    /// would fail here, but a disabled button is a courtesy, not a rule — anything
    /// that can reach this endpoint has to be checked here too.
    /// </summary>
    private static void AssertStatus(Manifest manifest, string[] allowed, string action)
    {
        if (!allowed.Contains(manifest.Status))
        {
            throw new DomainException(
                $"{action}ไม่ได้ เพราะเอกสารอยู่สถานะ \"{ManifestStatus.Label[manifest.Status]}\"");
        }
    }

    public Manifest CreateManifest(ManifestInput input)
    {
        lock (_gate)
        {
            if (input.Stops.Count == 0)
                throw new DomainException("ต้องเลือกใบสั่งส่งอย่างน้อย 1 รายการ");

            var created = input.ToManifest() with
            {
                Id = $"mn-{_nextManifest}",
                ManifestNo = $"MN-202608-{_nextManifest.ToString().PadLeft(4, '0')}",
                // A new document is a draft: it stays TMS's to edit until confirmed.
                Status = ManifestStatus.Draft,
                // One colour per trip, from the running number, so consecutive runs
                // never share one. Whatever the client sent is ignored — the palette
                // is the server's to hand out, or two clients pick the same colour.
                Colour = Palette.RouteColour(_nextManifest),
                ClosedAt = Now(),
                // The billed figure is the breakdown's total, never a separately
                // typed number — two sources for one amount is how they disagree.
                FreightCost = input.Pricing.Total(),
            };
            _nextManifest += 1;

            _manifests = [created, .. _manifests];
            // Loaded orders leave the pending pool so they cannot be assigned twice.
            var loaded = created.Stops.Select(s => s.Id).ToHashSet();
            _pendingStops = [.. _pendingStops.Where(s => !loaded.Contains(s.Id))];

            return created;
        }
    }

    public Manifest UpdateManifest(string id, ManifestInput input)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Draft, ManifestStatus.Confirmed], "แก้ไข");
            if (input.Stops.Count == 0)
                throw new DomainException("ใบปิดบรรทุกต้องมีจุดส่งอย่างน้อย 1 รายการ");

            // Stops dropped from the document go back to the pool; stops added leave it.
            var kept = input.Stops.Select(s => s.Id).ToHashSet();
            var returned = current.Stops.Where(s => !kept.Contains(s.Id));
            _pendingStops = [.. _pendingStops.Where(s => !kept.Contains(s.Id)), .. returned];

            return Replace(input.ToManifest() with
            {
                Id = current.Id,
                ManifestNo = current.ManifestNo,
                Status = current.Status,
                ClosedAt = current.ClosedAt,
                ConfirmedAt = current.ConfirmedAt,
                ParentId = current.ParentId,
                SentAt = current.SentAt,
                StatusMessage = current.StatusMessage,
                CancelReason = current.CancelReason,
                Express = current.Express,
                // Left as it was: the colour identifies this trip, and swapping the
                // route on an edit must not repaint a line someone is following.
                Colour = current.Colour,
                FreightCost = input.Pricing.Total(),
            });
        }
    }

    public Manifest ConfirmManifest(string id)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Draft], "ยืนยัน");
            // A manifest cut from a plan has no truck yet; confirming one would hand
            // the warehouse a document nobody can drive.
            if (!current.IsAssigned())
                throw new DomainException("ยืนยันไม่ได้ — ต้องระบุรถ พนักงานขับรถ และสายส่งก่อน");

            var now = Now();
            return Replace(current with { Status = ManifestStatus.Confirmed, ClosedAt = now, ConfirmedAt = now });
        }
    }

    public Manifest SendManifest(string id)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Confirmed, ManifestStatus.Error], "ส่งให้ MMX");

            // The hand-off is the one thing TMS does to the outside world, so it is
            // written to the integration log the same way a real send would be.
            LogOutbound("Manifest.Send", current.ManifestNo, $"ส่งใบปิดบรรทุก {current.Stops.Count} จุดส่ง");

            return Replace(current with
            {
                Status = ManifestStatus.Sent,
                SentAt = Now(),
                StatusMessage = null,
            });
        }
    }

    public Manifest CancelManifest(string id, string reason)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Draft, ManifestStatus.Confirmed], "ยกเลิก");

            // The orders were never delivered, so they return to the pending pool.
            _pendingStops = [.. _pendingStops, .. current.Stops];

            // A reason is optional, and an empty string is not one — leave the field
            // unset rather than storing a blank the screens would have to test for.
            var trimmed = reason.Trim();
            return Replace(current with
            {
                Status = ManifestStatus.Cancelled,
                CancelReason = trimmed == "" ? null : trimmed,
                Stops = [],
            });
        }
    }

    public Manifest MarkExpress(string id, ExpressDispatch express)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Draft, ManifestStatus.Confirmed, ManifestStatus.Sent], "ตั้งเป็นส่งด่วน");
            if (express.Requester.Trim() == "" || express.Approver.Trim() == "")
                throw new DomainException("ส่งด่วนต้องระบุทั้งผู้แจ้งและผู้อนุมัติ");

            return Replace(current with { Express = express });
        }
    }

    public Manifest MarkInvoiced(string id)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            // Nothing is invoiced before it has gone out — billing follows the load.
            AssertStatus(current, [ManifestStatus.Sent, ManifestStatus.Completed], "เปิดอินวอยซ์");
            return Replace(current with { Status = ManifestStatus.Invoiced });
        }
    }

    /// <summary>Returns the parent first, then the new child — the order the client unpacks.</summary>
    public Manifest[] SplitManifest(string id, List<string> stopIds)
    {
        lock (_gate)
        {
            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Draft], "แยกใบ");

            var moving = current.Stops.Where(s => stopIds.Contains(s.Id)).ToList();
            var staying = current.Stops.Where(s => !stopIds.Contains(s.Id)).ToList();
            if (moving.Count == 0) throw new DomainException("เลือกจุดส่งที่จะแยกออกอย่างน้อย 1 รายการ");
            if (staying.Count == 0) throw new DomainException("ต้องเหลือจุดส่งไว้ในใบเดิมอย่างน้อย 1 รายการ");

            // Children hang off the parent's number: MN-…-1, MN-…-2, …
            var parentId = current.ParentId ?? current.Id;
            var parentNo = _manifests.FirstOrDefault(m => m.Id == parentId)?.ManifestNo ?? current.ManifestNo;
            var siblings = _manifests.Count(m => m.ParentId == parentId);

            var child = current with
            {
                Id = $"mn-{_nextManifest}",
                ManifestNo = $"{parentNo}-{siblings + 1}",
                ParentId = parentId,
                Status = ManifestStatus.Draft,
                ClosedAt = Now(),
                Stops = moving,
            };
            _nextManifest += 1;

            var parent = current with { Stops = staying };
            _manifests = [child, .. _manifests.Select(m => m.Id == parent.Id ? parent : m)];
            return [parent, child];
        }
    }

    /// <summary>Returns source then target — the order the client unpacks.</summary>
    public Manifest[] MoveStops(string fromId, string toId, List<string> stopIds)
    {
        lock (_gate)
        {
            if (fromId == toId) throw new DomainException("ต้นทางและปลายทางต้องเป็นคนละใบ");

            // Not named `from`/`to`: `from` is a LINQ query keyword and cannot be
            // an identifier here, which the compiler reports as a syntax error
            // several lines further down than the name itself.
            var source = FindManifest(fromId);
            var target = FindManifest(toId);
            AssertStatus(source, [ManifestStatus.Draft], "ย้ายจุดส่งออกจากใบนี้");
            AssertStatus(target, [ManifestStatus.Draft], "ย้ายจุดส่งเข้าใบปลายทาง");

            var moving = source.Stops.Where(s => stopIds.Contains(s.Id)).ToList();
            if (moving.Count == 0) throw new DomainException("เลือกจุดส่งที่จะย้ายอย่างน้อย 1 รายการ");
            var staying = source.Stops.Where(s => !stopIds.Contains(s.Id)).ToList();
            if (staying.Count == 0) throw new DomainException("ต้องเหลือจุดส่งไว้ในใบต้นทางอย่างน้อย 1 รายการ");

            var nextFrom = source with { Stops = staying };
            var nextTo = target with { Stops = [.. target.Stops, .. moving] };
            Replace(nextFrom);
            Replace(nextTo);
            return [nextFrom, nextTo];
        }
    }

    /// <summary>
    /// What OMS reports back. Stands in for the inbound webhook until it exists —
    /// `เสร็จสิ้น` and `ตีกลับ` are not states TMS may set on its own.
    /// </summary>
    public Manifest ApplyExternalStatus(string id, string outcome, string message)
    {
        lock (_gate)
        {
            if (outcome != ManifestStatus.Completed && outcome != ManifestStatus.Error)
                throw new DomainException("สถานะที่รับกลับได้มีแค่ completed และ error");

            var current = FindManifest(id);
            AssertStatus(current, [ManifestStatus.Sent], "รับสถานะกลับ");

            LogInbound("Status.Update", current.ManifestNo, message);

            return Replace(current with { Status = outcome, StatusMessage = message });
        }
    }

    // ── แผนขนส่ง · transport plans ─────────────────────────────────────────────

    public List<TransportPlan> ListPlans()
    {
        lock (_gate) return [.. _plans];
    }

    private TransportPlan FindPlan(string id) =>
        _plans.FirstOrDefault(p => p.Id == id)
        ?? throw DomainException.NotFound("ไม่พบแผนขนส่งนี้");

    private TransportPlan ReplacePlan(TransportPlan updated)
    {
        _plans = [.. _plans.Select(p => p.Id == updated.Id ? updated : p)];
        return updated;
    }

    private static void AssertPlanStatus(TransportPlan plan, string[] allowed, string action)
    {
        if (!allowed.Contains(plan.Status))
        {
            throw new DomainException(
                $"{action}ไม่ได้ เพราะแผนอยู่สถานะ \"{TransportPlanStatus.Label[plan.Status]}\"");
        }
    }

    /// <summary>Orders taken back out of a plan or a manifest return to the pool.</summary>
    private void GiveBack(IEnumerable<ManifestStop> stops)
    {
        var returning = stops.ToList();
        var ids = returning.Select(s => s.Id).ToHashSet();
        _pendingStops = [.. _pendingStops.Where(s => !ids.Contains(s.Id)), .. returning];
    }

    /// <summary>Takes orders out of the pool. Ids that are not in it are simply not returned.</summary>
    private List<ManifestStop> TakeFromPool(IEnumerable<string> ids)
    {
        var wanted = ids.ToHashSet();
        var taken = _pendingStops.Where(s => wanted.Contains(s.Id)).ToList();
        _pendingStops = [.. _pendingStops.Where(s => !wanted.Contains(s.Id))];
        return taken;
    }

    public TransportPlan CreatePlan(TransportPlanInput input)
    {
        lock (_gate)
        {
            var route = FindRoute(input.RouteId);
            var created = new TransportPlan
            {
                Id = $"pl-{_nextPlan}",
                PlanNo = $"PL-202608-{_nextPlan.ToString().PadLeft(4, '0')}",
                Status = TransportPlanStatus.Draft,
                CreatedAt = Now(),
                CreatedBy = Author,
                WarehouseCode = input.WarehouseCode,
                DeliveryDate = input.DeliveryDate,
                RouteId = route.Id,
                RouteCode = route.Code,
                RouteName = route.Name,
                Note = input.Note,
                Stops = [],
            };
            _nextPlan += 1;

            _plans = [created, .. _plans];
            return created;
        }
    }

    public TransportPlan UpdatePlan(string id, TransportPlanInput input)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Draft], "แก้ไข");

            var route = FindRoute(input.RouteId);
            var moved = current with
            {
                WarehouseCode = input.WarehouseCode,
                DeliveryDate = input.DeliveryDate,
                RouteId = route.Id,
                RouteCode = route.Code,
                RouteName = route.Name,
                Note = input.Note,
            };

            // Moving the plan to another route would leave orders from territory
            // the new one does not reach stranded in it, so they go back to the
            // pool and are picked again.
            if (route.Id != current.RouteId && current.Stops.Count > 0)
            {
                GiveBack(current.Stops);
                return ReplacePlan(moved with { Stops = [] });
            }

            return ReplacePlan(moved);
        }
    }

    /// <summary>
    /// Replaces the plan's contents with exactly these orders. Anything dropped
    /// returns to the pending pool, so an order is only ever in one place.
    /// </summary>
    public TransportPlan SetPlanStops(string id, List<string> stopIds)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Draft], "แก้ไขรายการในแผน");

            var wanted = stopIds.ToHashSet();
            var kept = current.Stops.Where(s => wanted.Contains(s.Id)).ToList();
            var dropped = current.Stops.Where(s => !wanted.Contains(s.Id)).ToList();
            // Only the ids not already held by the plan have to come out of the pool.
            var held = kept.Select(s => s.Id).ToHashSet();
            var added = TakeFromPool(stopIds.Where(sid => !held.Contains(sid)));

            // An order has to sit in a zone the plan's route actually reaches.
            // Not one zone: a lorry drives a line, and the northern run passes
            // through Nakhon Sawan and Phichit on its way to Phitsanulok, so all
            // three are loadable onto it. A zone the route never enters is not.
            var route = FindRoute(current.RouteId);
            var reachable = route.DeliveryZoneIds.ToHashSet();
            var stray = added.Concat(kept).FirstOrDefault(s => !reachable.Contains(s.DeliveryZoneId));
            if (stray is not null)
            {
                // Anything taken out of the pool goes back before throwing, or the
                // rejected orders would vanish from both the plan and the queue.
                GiveBack(added);
                throw new DomainException(
                    $"ใบสั่งส่ง {stray.DoNo} อยู่ในโซนที่สาย {route.Code} ไม่ได้วิ่งผ่าน — " +
                    "เลือกได้เฉพาะใบในโซนที่สายนี้ผ่าน หรือสร้างแผนของสายอื่นแยกอีกใบ");
            }

            GiveBack(dropped);
            return ReplacePlan(current with { Stops = InRouteOrder([.. kept, .. added], route) });
        }
    }

    /// <summary>
    /// The order the lorry drives: zone by zone along the route, then by due date
    /// within a zone. The route's sequence is the only thing that knows Nakhon
    /// Sawan comes before Phichit on the northern run, so the drop order falls
    /// out of the plan instead of being sorted by hand afterwards.
    /// </summary>
    private static List<ManifestStop> InRouteOrder(List<ManifestStop> stops, RouteMaster route)
    {
        var rank = route.DeliveryZoneIds
            .Select((zoneId, index) => (zoneId, index))
            .ToDictionary(pair => pair.zoneId, pair => pair.index);

        return [.. stops
            .OrderBy(s => rank.GetValueOrDefault(s.DeliveryZoneId, int.MaxValue))
            .ThenBy(s => s.DueDate, StringComparer.Ordinal)];
    }

    public PlanIssueResult IssuePlan(string id)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Draft], "สร้างใบขนส่ง");
            if (current.Stops.Count == 0)
                throw new DomainException("แผนนี้ยังไม่มีรายการ — เพิ่มใบสั่งส่งก่อน");

            var origin = _warehouses.FirstOrDefault(w => w.Code == "WNB");

            // A manifest cut from a plan starts with no truck, driver or route — the
            // blanks the dispatcher fills in, and what the confirm gate checks for.
            var manifest = new Manifest
            {
                Id = $"mn-{_nextManifest}",
                ManifestNo = $"MN-202608-{_nextManifest.ToString().PadLeft(4, '0')}",
                Status = ManifestStatus.Draft,
                ClosedAt = Now(),
                Colour = Palette.RouteColour(_nextManifest),
                Vehicle = "6-wheel",
                Origin = new GeoPoint(origin?.Name ?? "DC นนทบุรี", origin?.Position ?? [13.8591, 100.5217]),
                Dock = "Dock 1",
                // The trip is not priced until a carrier is chosen, which happens on
                // the manifest — a plan has no rate to quote from.
                Pricing = new FreightPricing(),
                FreightCost = 0,
                // Both carried over from the plan, so the document says where the load
                // came from and who set it in motion without anyone retyping either.
                WarehouseCode = current.WarehouseCode,
                CreatedBy = current.CreatedBy,
                DeliveryDate = current.DeliveryDate,
                // The stops already left the pool when they were added to the plan.
                Stops = [.. current.Stops],
            };
            _nextManifest += 1;
            _manifests = [manifest, .. _manifests];

            var plan = ReplacePlan(current with
            {
                Status = TransportPlanStatus.Issued,
                ManifestId = manifest.Id,
                ManifestNo = manifest.ManifestNo,
            });

            return new PlanIssueResult(plan, manifest);
        }
    }

    public TransportPlan CancelPlan(string id)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Draft], "ยกเลิก");

            GiveBack(current.Stops);
            return ReplacePlan(current with
            {
                Status = TransportPlanStatus.Cancelled,
                // Remembered so the plan can be raised again as it was. The stops
                // themselves go back to the pool and may be taken by someone else
                // before that happens, which is why this is a list of ids and not
                // the orders: what can still be collected is decided at the time,
                // not promised now.
                CancelledStopIds = [.. current.Stops.Select(s => s.Id)],
                Stops = [],
            });
        }
    }

    /// <summary>
    /// Removes the plan outright — for one raised by mistake, where cancelling
    /// would leave a row on the list saying so forever.
    ///
    /// Only before a manifest exists. Once issued the plan is the record of how
    /// that document came about, and the document outlives it.
    /// </summary>
    public TransportPlan DeletePlan(string id)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Draft, TransportPlanStatus.Cancelled], "ลบ");

            // A draft still holds its orders. Dropping the plan without handing
            // them back would strand them: out of the pool, on no document, and
            // invisible to every screen.
            GiveBack(current.Stops);
            _plans = [.. _plans.Where(p => p.Id != current.Id)];
            return current;
        }
    }

    /// <summary>
    /// Raises a cancelled plan again as a fresh draft, with the same header and
    /// as much of the same load as is still free.
    ///
    /// A new number rather than reviving the old one: the cancellation was
    /// reported to the people downstream, and a number that comes back to life
    /// after that is a number nobody can trust. The cancelled plan stays on the
    /// list, now pointing at its replacement.
    /// </summary>
    public PlanRecreateResult RecreatePlan(string id)
    {
        lock (_gate)
        {
            var current = FindPlan(id);
            AssertPlanStatus(current, [TransportPlanStatus.Cancelled], "สร้างใหม่อีกครั้ง");

            var route = FindRoute(current.RouteId);
            // Whatever is still in the pool. Orders picked up by another plan in
            // the meantime are simply not there, and the caller is told how many
            // rather than being handed a plan quietly missing half its load.
            var wanted = current.CancelledStopIds;
            var regained = TakeFromPool(wanted);
            var lost = wanted.Count - regained.Count;

            var created = new TransportPlan
            {
                Id = $"pl-{_nextPlan}",
                PlanNo = $"PL-202608-{_nextPlan.ToString().PadLeft(4, '0')}",
                Status = TransportPlanStatus.Draft,
                CreatedAt = Now(),
                CreatedBy = Author,
                WarehouseCode = current.WarehouseCode,
                DeliveryDate = current.DeliveryDate,
                RouteId = route.Id,
                RouteCode = route.Code,
                RouteName = route.Name,
                Note = current.Note,
                Stops = InRouteOrder(regained, route),
            };
            _nextPlan += 1;
            _plans = [created, .. _plans];

            return new PlanRecreateResult(created, ReplacePlan(current with { RecreatedAsNo = created.PlanNo }), lost);
        }
    }

    // ── บันทึกการเชื่อมต่อ · integration log ───────────────────────────────────

    /// <summary>Newest first, the way an operator reads a log.</summary>
    public List<IntegrationMessage> ListMessages()
    {
        lock (_gate) return [.. _messages.OrderByDescending(m => m.At, StringComparer.Ordinal)];
    }

    private void LogOutbound(string channel, string reference, string detail) =>
        Append("out", "MMX", channel, reference, detail);

    private void LogInbound(string channel, string reference, string detail) =>
        Append("in", "OMS", channel, reference, detail);

    /// <summary>Caller already holds <c>_gate</c> — this is only reached from inside it.</summary>
    private void Append(string direction, string system, string channel, string reference, string detail)
    {
        _messages = [.. _messages, new IntegrationMessage
        {
            Id = $"msg-{_nextMessage}",
            Direction = direction,
            System = system,
            Channel = channel,
            Reference = reference,
            At = Now(),
            Status = "success",
            Detail = detail,
        }];
        _nextMessage += 1;
    }

    public IntegrationMessage RetryMessage(string id)
    {
        lock (_gate)
        {
            var target = _messages.FirstOrDefault(m => m.Id == id)
                ?? throw DomainException.NotFound("ไม่พบรายการนี้");
            if (target.Status != "failed")
                throw new DomainException("ส่งซ้ำได้เฉพาะรายการที่ล้มเหลว");

            // The retry is logged as its own entry, so the failure stays on the record.
            var retried = target with
            {
                Id = $"msg-{_nextMessage}",
                At = Now(),
                Status = "success",
                Detail = $"ส่งซ้ำสำเร็จ (จากรายการ {target.Reference})",
            };
            _nextMessage += 1;
            _messages = [.. _messages.Select(m => m.Id == id ? m with { Status = "resolved" } : m), retried];
            return retried;
        }
    }

    // ── มาสเตอร์ · master data ────────────────────────────────────────────────
    //
    // Each of these is list / create / update with one uniqueness rule. The rule is
    // always the same shape: the code (or the plate) is what a document prints, so
    // two records sharing one leaves no way to tell which was meant.

    public List<Warehouse> ListWarehouses()
    {
        lock (_gate) return [.. _warehouses];
    }

    public Warehouse CreateWarehouse(Warehouse input)
    {
        lock (_gate)
        {
            AssertWarehouseCodeFree(input.Code, null);
            var created = input with { Id = $"wh-{_nextWarehouse++}" };
            _warehouses = [.. _warehouses, created];
            return created;
        }
    }

    public Warehouse UpdateWarehouse(string id, Warehouse input)
    {
        lock (_gate)
        {
            if (!_warehouses.Any(w => w.Id == id)) throw DomainException.NotFound("ไม่พบคลังนี้");
            AssertWarehouseCodeFree(input.Code, id);
            var updated = input with { Id = id };
            _warehouses = [.. _warehouses.Select(w => w.Id == id ? updated : w)];
            return updated;
        }
    }

    private void AssertWarehouseCodeFree(string code, string? exceptId)
    {
        var clash = _warehouses.FirstOrDefault(w =>
            w.Id != exceptId && string.Equals(w.Code, code.Trim(), StringComparison.OrdinalIgnoreCase));
        if (clash is not null) throw new DomainException($"รหัสคลัง {code} ถูกใช้กับ {clash.Name} แล้ว");
    }

    public List<DeliveryZone> ListZones()
    {
        lock (_gate) return [.. _zones];
    }

    public DeliveryZone CreateZone(DeliveryZone input)
    {
        lock (_gate)
        {
            AssertZoneCodeFree(input.Code, null);
            AssertAreasFree(input, null);
            var created = input with { Id = $"zone-{_nextZone++}" };
            _zones = [.. _zones, created];
            return created;
        }
    }

    public DeliveryZone UpdateZone(string id, DeliveryZone input)
    {
        lock (_gate)
        {
            if (!_zones.Any(z => z.Id == id)) throw DomainException.NotFound("ไม่พบโซนนี้");
            AssertZoneCodeFree(input.Code, id);
            AssertAreasFree(input, id);
            var updated = input with { Id = id };
            _zones = [.. _zones.Select(z => z.Id == id ? updated : z)];
            return updated;
        }
    }

    private void AssertZoneCodeFree(string code, string? exceptId)
    {
        var clash = _zones.FirstOrDefault(z =>
            z.Id != exceptId && string.Equals(z.Code, code.Trim(), StringComparison.OrdinalIgnoreCase));
        if (clash is not null) throw new DomainException($"รหัสโซน {code} ถูกใช้กับ {clash.Name} แล้ว");
    }

    private static List<string> ParseAreas(string areas) =>
        [.. areas.Split(',').Select(a => a.Trim()).Where(a => a != "")];

    /// <summary>District names only repeat across provinces — "เมือง…" exists in most.</summary>
    private static string AreaKey(string province, string area) => $"{province}|{area}".ToLowerInvariant();

    /// <summary>
    /// A district belongs to exactly one zone.
    ///
    /// An order carries a single <c>deliveryZoneId</c> resolved from its address,
    /// so two zones claiming the same district leaves that resolution with no
    /// answer and splits a load that should have travelled together.
    ///
    /// An edit is only checked on what it adds: a zone keeps whatever it already
    /// claimed, so rows that predate this rule can still be renamed instead of
    /// being frozen by an overlap nobody can unpick from this side.
    /// </summary>
    private void AssertAreasFree(DeliveryZone input, string? exceptId)
    {
        var current = _zones.FirstOrDefault(z => z.Id == exceptId);
        var held = current is null
            ? []
            : ParseAreas(current.Areas).Select(a => AreaKey(current.Province, a)).ToHashSet();

        var owners = new Dictionary<string, DeliveryZone>();
        foreach (var zone in _zones.Where(z => z.Id != exceptId))
        {
            foreach (var area in ParseAreas(zone.Areas)) owners[AreaKey(zone.Province, area)] = zone;
        }

        foreach (var area in ParseAreas(input.Areas))
        {
            var key = AreaKey(input.Province, area);
            if (held.Contains(key)) continue;
            if (owners.TryGetValue(key, out var owner))
                throw new DomainException($"{area} อยู่ในโซน {owner.Code} ({owner.Name}) แล้ว");
        }
    }

    public List<RouteMaster> ListRoutes()
    {
        lock (_gate) return [.. _routes];
    }

    public RouteMaster CreateRoute(RouteMaster input)
    {
        lock (_gate)
        {
            AssertRouteCodeFree(input.Code, null);
            var created = WithPrimaryZone(input) with { Id = $"rt-{_nextRoute++}" };
            _routes = [.. _routes, created];
            return created;
        }
    }

    public RouteMaster UpdateRoute(string id, RouteMaster input)
    {
        lock (_gate)
        {
            if (!_routes.Any(r => r.Id == id)) throw DomainException.NotFound("ไม่พบสายส่งนี้");
            AssertRouteCodeFree(input.Code, id);
            var updated = WithPrimaryZone(input) with { Id = id };
            _routes = [.. _routes.Select(r => r.Id == id ? updated : r)];
            return updated;
        }
    }

    /// <summary>
    /// A route with zones always has exactly one primary, mirroring the unique
    /// filtered index the table carries. A choice that is not one of the route's
    /// own zones falls back to the first rather than being stored as given.
    /// </summary>
    private static RouteMaster WithPrimaryZone(RouteMaster input) => input with
    {
        PrimaryZoneId = input.DeliveryZoneIds.Contains(input.PrimaryZoneId)
            ? input.PrimaryZoneId
            : input.DeliveryZoneIds.FirstOrDefault() ?? "",
    };

    private void AssertRouteCodeFree(string code, string? exceptId)
    {
        if (_routes.Any(r => r.Id != exceptId && string.Equals(r.Code, code.Trim(), StringComparison.OrdinalIgnoreCase)))
            throw new DomainException($"รหัสสายส่ง {code} ถูกใช้แล้ว");
    }

    public List<Carrier> ListCarriers()
    {
        lock (_gate) return [.. _carriers];
    }

    public Carrier CreateCarrier(Carrier input)
    {
        lock (_gate)
        {
            AssertCarrierCodeFree(input.Code, null);
            var created = input with { Id = $"cr-{_nextCarrier++}" };
            _carriers = [.. _carriers, created];
            return created;
        }
    }

    public Carrier UpdateCarrier(string id, Carrier input)
    {
        lock (_gate)
        {
            if (!_carriers.Any(c => c.Id == id)) throw DomainException.NotFound("ไม่พบผู้ให้บริการนี้");
            AssertCarrierCodeFree(input.Code, id);
            var updated = input with { Id = id };
            _carriers = [.. _carriers.Select(c => c.Id == id ? updated : c)];
            return updated;
        }
    }

    private void AssertCarrierCodeFree(string code, string? exceptId)
    {
        if (_carriers.Any(c => c.Id != exceptId && string.Equals(c.Code, code.Trim(), StringComparison.OrdinalIgnoreCase)))
            throw new DomainException($"รหัสผู้ให้บริการ {code} ถูกใช้แล้ว");
    }

    public List<FleetVehicle> ListVehicles()
    {
        lock (_gate) return [.. _vehicles];
    }

    public FleetVehicle CreateVehicle(FleetVehicle input)
    {
        lock (_gate)
        {
            AssertPlateFree(input.PlateHead, null);
            var created = input with { Id = $"v-{_nextVehicle++}" };
            _vehicles = [.. _vehicles, created];
            return created;
        }
    }

    public FleetVehicle UpdateVehicle(string id, FleetVehicle input)
    {
        lock (_gate)
        {
            if (!_vehicles.Any(v => v.Id == id)) throw DomainException.NotFound("ไม่พบรถคันนี้");
            AssertPlateFree(input.PlateHead, id);
            var updated = input with { Id = id };
            _vehicles = [.. _vehicles.Select(v => v.Id == id ? updated : v)];
            return updated;
        }
    }

    /// <summary>A plate identifies the truck on the road, so two records must never share one.</summary>
    private void AssertPlateFree(string plateHead, string? exceptId)
    {
        if (_vehicles.Any(v => v.Id != exceptId && string.Equals(v.PlateHead.Trim(), plateHead.Trim(), StringComparison.OrdinalIgnoreCase)))
            throw new DomainException($"ทะเบียน {plateHead} ถูกใช้แล้ว");
    }

    public List<Driver> ListDrivers()
    {
        lock (_gate) return [.. _drivers];
    }

    public Driver CreateDriver(Driver input)
    {
        lock (_gate)
        {
            AssertDriverCodeFree(input.Code, null);
            var created = input with { Id = $"dr-{_nextDriver++}" };
            _drivers = [.. _drivers, created];
            return created;
        }
    }

    public Driver UpdateDriver(string id, Driver input)
    {
        lock (_gate)
        {
            if (!_drivers.Any(d => d.Id == id)) throw DomainException.NotFound("ไม่พบพนักงานขับรถคนนี้");
            AssertDriverCodeFree(input.Code, id);
            var updated = input with { Id = id };
            _drivers = [.. _drivers.Select(d => d.Id == id ? updated : d)];
            return updated;
        }
    }

    private void AssertDriverCodeFree(string code, string? exceptId)
    {
        if (_drivers.Any(d => d.Id != exceptId && string.Equals(d.Code, code.Trim(), StringComparison.OrdinalIgnoreCase)))
            throw new DomainException($"รหัสพนักงานขับรถ {code} ถูกใช้แล้ว");
    }

    /* ── ลบ master ────────────────────────────────────────────────────────────
       กติกาเดียวกับฝั่งฐานข้อมูล (Database/MasterDeletes.cs): ลบได้เฉพาะแถวที่
       ไม่มีอะไรอ้างถึง ที่เหลือปฏิเสธพร้อมบอกว่าอะไรถืออยู่

       โครงการนี้ตั้งใจไม่มี delete มาตลอด เพราะการตั้ง active = false ทำให้
       เอกสารเก่าที่อ้างชื่อนั้นยังอ่านได้ ส่วน delete ทำไม่ได้ — เหตุผลนั้นยังจริง
       สำหรับแถวที่เคยถูกใช้ และเป็นที่มาของการตรวจข้างล่างนี้ สิ่งที่มันไม่ได้
       ครอบคลุมคือแถวที่เพิ่งพิมพ์ผิดเมื่อครู่ ซึ่งเป็นเหตุผลที่ delete มีอยู่ */

    private static DomainException InUse(string what, string key, string label, int count) =>
        new($"ลบ{what} {key} ไม่ได้ — มี{label} {count} รายการอ้างถึงอยู่ " +
            "ถ้าเลิกใช้แล้วให้ตั้งเป็นไม่ใช้งาน (active = false) แทน เอกสารเก่าจะได้ยังอ่านได้");

    public void DeleteWarehouse(string id)
    {
        lock (_gate)
        {
            var row = _warehouses.FirstOrDefault(w => w.Id == id)
                ?? throw DomainException.NotFound("ไม่พบคลังนี้");
            var used = _manifests.Count(m => m.WarehouseCode == row.Code)
                     + _plans.Count(p => p.WarehouseCode == row.Code);
            if (used > 0) throw InUse("คลัง", row.Code, "เอกสาร", used);
            _warehouses = [.. _warehouses.Where(w => w.Id != id)];
        }
    }

    public void DeleteZone(string id)
    {
        lock (_gate)
        {
            var row = _zones.FirstOrDefault(z => z.Id == id)
                ?? throw DomainException.NotFound("ไม่พบโซนนี้");
            var used = _manifests.SelectMany(m => m.Stops).Count(s => s.DeliveryZoneId == id)
                     + ListPendingStops().Count(s => s.DeliveryZoneId == id)
                     + _routes.Count(r => r.DeliveryZoneIds.Contains(id));
            if (used > 0) throw InUse("โซนจัดส่ง", row.Code, "จุดส่งและสายส่ง", used);
            _zones = [.. _zones.Where(z => z.Id != id)];
        }
    }

    public void DeleteRoute(string id)
    {
        lock (_gate)
        {
            var row = _routes.FirstOrDefault(r => r.Id == id)
                ?? throw DomainException.NotFound("ไม่พบสายส่งนี้");
            var used = _manifests.Count(m => m.RouteId == id);
            if (used > 0) throw InUse("สายส่ง", row.Code, "ใบปิดบรรทุก", used);
            _routes = [.. _routes.Where(r => r.Id != id)];
        }
    }

    public void DeleteCarrier(string id)
    {
        lock (_gate)
        {
            var row = _carriers.FirstOrDefault(c => c.Id == id)
                ?? throw DomainException.NotFound("ไม่พบผู้ให้บริการนี้");
            var used = _manifests.Count(m => m.CarrierId == id)
                     + _vehicles.Count(v => v.CarrierId == id)
                     + _drivers.Count(d => d.CarrierId == id);
            if (used > 0) throw InUse("ผู้ให้บริการ", row.Code, "ใบปิดบรรทุก รถ และพนักงานขับรถ", used);
            _carriers = [.. _carriers.Where(c => c.Id != id)];
        }
    }

    public void DeleteVehicle(string id)
    {
        lock (_gate)
        {
            var row = _vehicles.FirstOrDefault(v => v.Id == id)
                ?? throw DomainException.NotFound("ไม่พบรถคันนี้");
            var used = _manifests.Count(m => m.PlateHead == row.PlateHead);
            if (used > 0) throw InUse("รถ", row.PlateHead, "ใบปิดบรรทุก", used);
            _vehicles = [.. _vehicles.Where(v => v.Id != id)];
        }
    }

    public void DeleteDriver(string id)
    {
        lock (_gate)
        {
            var row = _drivers.FirstOrDefault(d => d.Id == id)
                ?? throw DomainException.NotFound("ไม่พบพนักงานขับรถคนนี้");
            var used = _manifests.Count(m => m.DriverId == id);
            if (used > 0) throw InUse("พนักงานขับรถ", row.Code, "ใบปิดบรรทุก", used);
            _drivers = [.. _drivers.Where(d => d.Id != id)];
        }
    }
}

/// <summary>Both documents the issue step writes, in the shape the client destructures.</summary>
public sealed record PlanIssueResult(TransportPlan Plan, Manifest Manifest);

/// <summary>
/// What raising a cancelled plan again produced: the new draft, the cancelled
/// plan now pointing at it, and how many of its orders could not be collected
/// back because another plan had taken them. The client needs all three — the
/// count is what turns a quietly short plan into a sentence the planner reads.
/// </summary>
public sealed record PlanRecreateResult(TransportPlan Plan, TransportPlan Cancelled, int Unavailable);
