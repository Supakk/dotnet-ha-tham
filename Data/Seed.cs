using Mammod.Models;

namespace Mammod.Data;

/// <summary>
/// The starting rows, carried over from the client's <c>*.mock.ts</c> fixtures so
/// the screens show the same data whether they run on fixtures or on this server.
/// Changing a row here changes what the app shows; changing an <c>id</c> breaks
/// the references the other fixtures make to it.
/// </summary>
public static class Seed
{
    private static readonly GeoPoint DcNonthaburi = new("DC นนทบุรี", [13.8591, 100.5217]);

    /// <summary>
    /// Builds a stop from the handful of fields that actually differ between the
    /// fixtures; the rest is derived so the rows below stay readable.
    /// </summary>
    private static ManifestStop Stop(
        string id, string doNo, string soNo, string zoneId, string customer, string address,
        int boxes, double weight, double cbm, double cod, double[] position,
        string warehouseCode, string pickDate, string dueDate,
        string status = "pending", string deliverTo = "") => new()
        {
            Id = id,
            DoNo = doNo,
            SoNo = soNo,
            PickNo = doNo.Replace("DO-", "PKL-"),
            PickDate = pickDate,
            WarehouseCode = warehouseCode,
            DeliveryZoneId = zoneId,
            Customer = customer,
            Address = address,
            DeliverTo = deliverTo,
            Boxes = boxes,
            Weight = weight,
            Cbm = cbm,
            Cod = cod,
            DueDate = dueDate,
            Status = status,
            Position = position,
        };

    /// <summary>
    /// Spread across warehouses and due dates on purpose: the pool screen shows
    /// how late each order is and filters by warehouse, and neither can be judged
    /// against fixtures that are all identical.
    /// </summary>
    public static List<ManifestStop> PendingStops() =>
    [
        Stop("s-1", "DO-2026-0801", "", "zone-1", "บจก. นครสวรรค์การค้า", "อ.เมือง จ.นครสวรรค์", 150, 3000, 10.5, 0, [15.7047, 100.1372], "WSK", "2026-07-28", "2026-07-31"),
        Stop("s-2", "DO-2026-0802", "", "zone-2", "หจก. พิจิตรซัพพลาย", "อ.เมือง จ.พิจิตร", 200, 4000, 12.0, 15500, [16.4429, 100.3487], "WSK", "2026-08-01", "2026-08-07"),
        Stop("s-3", "DO-2026-0803", "", "zone-3", "ร้านพิษณุโลกมาร์ท", "อ.เมือง จ.พิษณุโลก", 100, 1500, 6.0, 0, [16.8211, 100.2659], "WPD", "2026-08-02", "2026-08-08"),
        Stop("s-4", "DO-2026-0804", "", "zone-4", "บจก. อยุธยาเทรดดิ้ง", "อ.พระนครศรีอยุธยา จ.พระนครศรีอยุธยา", 80, 1200, 4.5, 8200, [14.3532, 100.5689], "WPD", "2026-07-20", "2026-07-25", deliverTo: "หน่วยงานก่อสร้าง ไซต์อยุธยา"),
        Stop("s-5", "DO-2026-0805", "", "zone-5", "สหกรณ์ลพบุรี", "อ.เมือง จ.ลพบุรี", 120, 2400, 8.0, 0, [14.7995, 100.6534], "WWP", "2026-08-03", "2026-08-09"),
        Stop("s-6", "DO-2026-0806", "", "zone-6", "บจก. สระบุรีวัสดุ", "อ.เมือง จ.สระบุรี", 90, 1800, 5.5, 4300, [14.5289, 100.9101], "WWP", "2026-08-03", "2026-08-10"),
        Stop("s-7", "DO-2026-0807", "", "zone-7", "ชลบุรี ซูเปอร์มาร์เก็ต", "อ.ศรีราชา จ.ชลบุรี", 160, 3200, 11.0, 0, [13.1731, 100.9310], "WSK", "2026-07-15", "2026-07-18"),
        Stop("s-8", "DO-2026-0808", "", "zone-8", "ระยองฟู้ดส์", "อ.เมือง จ.ระยอง", 110, 2100, 7.5, 12800, [12.6814, 101.2816], "WPD", "2026-08-04", "2026-08-11", deliverTo: "คลังกระจายสินค้า ระยอง"),
    ];

    private static string At(int day, int hour, int minute) =>
        new DateTime(2026, 8, day, hour, minute, 0, DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

    private static string AtJuly(int day, int hour, int minute) =>
        new DateTime(2026, 7, day, hour, minute, 0, DateTimeKind.Utc).ToString("yyyy-MM-ddTHH:mm:ss.fffZ");

    /// <summary>
    /// One document parked at each of the five ติดตามสถานะ steps — a screen that
    /// only ever shows two of them cannot be judged. <c>error</c> is what stage
    /// four looks like: the load reached WMS and was turned back. Newest first,
    /// so the list reads back down the timeline.
    /// </summary>
    public static List<Manifest> Manifests() =>
    [
        // ── 1 · สร้างใบปิดบรรทุก — a draft the dispatcher can still edit ────────
        new Manifest
        {
            Id = "mn-3",
            ManifestNo = "MN-202608-0043",
            Status = ManifestStatus.Draft,
            ClosedAt = At(5, 3, 20),
            WarehouseCode = "WSK",
            CreatedBy = "admin : Next",
            DeliveryDate = "2026-08-06",
            DriverId = "dr-1",
            DriverName = "สมศักดิ์ ขยันส่ง",
            DriverPhone = "081-234-5678",
            PlateHead = "70-9012 นนทบุรี",
            PlateTrailer = "71-3344 นนทบุรี",
            Vehicle = "10-wheel",
            AssistantCount = 2,
            MaxPayloadKg = 15_000,
            MaxVolumeCbm = 35,
            CarrierId = "cr-1",
            Carrier = "Fleet อินเฮาส์ (คลังบางบัวทอง)",
            RouteId = "rt-1",
            RouteCode = "RT-NORTH-01",
            RouteName = "สายเหนือ (นครสวรรค์ - พิษณุโลก)",
            Origin = DcNonthaburi,
            Dock = "Dock 3",
            SealNo = "",
            FreightCost = 0,
            Pricing = new FreightPricing(),
            Colour = Palette.RouteColour(0),
            Stops =
            [
                Stop("h-5", "DO-2026-0781", "MN-202608-0043", "zone-1", "บจก. นครสวรรค์การค้า", "อ.เมือง จ.นครสวรรค์", 140, 2800, 9.5, 0, [15.7047, 100.1372], "WSK", "2026-08-04", "2026-08-06"),
                Stop("h-6", "DO-2026-0782", "MN-202608-0043", "zone-3", "ร้านพิษณุโลกมาร์ท", "อ.เมือง จ.พิษณุโลก", 95, 1900, 6.5, 7400, [16.8211, 100.2659], "WSK", "2026-08-04", "2026-08-06"),
            ],
        },

        // ── 2 · ยืนยันเอกสาร — confirmed, not yet handed to MMX ────────────────
        new Manifest
        {
            Id = "mn-4",
            ManifestNo = "MN-202608-0042",
            Status = ManifestStatus.Confirmed,
            ClosedAt = At(4, 2, 10),
            ConfirmedAt = At(4, 2, 55),
            WarehouseCode = "WPD",
            CreatedBy = "admin : Next",
            DeliveryDate = "2026-08-05",
            DriverId = "dr-5",
            DriverName = "อนุชา ทองดี",
            DriverPhone = "087-321-9900",
            PlateHead = "1กต 2414",
            PlateTrailer = "-",
            Vehicle = "4-wheel",
            AssistantCount = 0,
            MaxPayloadKg = 3_500,
            MaxVolumeCbm = 12,
            CarrierId = "cr-2",
            Carrier = "ไทยขนส่งด่วน",
            RouteId = "rt-3",
            RouteCode = "RT-WEST-02",
            RouteName = "สายตะวันตก (นครปฐม - ราชบุรี)",
            Origin = DcNonthaburi,
            Dock = "Dock 1",
            SealNo = "SL-9988431",
            FreightCost = 7_200,
            Pricing = new FreightPricing { TripPrice = 7_200 },
            Colour = Palette.RouteColour(1),
            Stops =
            [
                Stop("h-7", "DO-2026-0783", "MN-202608-0042", "zone-9", "นครปฐมค้าส่ง", "อ.เมือง จ.นครปฐม", 55, 850, 3.0, 0, [13.8199, 100.0621], "WPD", "2026-08-03", "2026-08-05"),
                Stop("h-8", "DO-2026-0784", "MN-202608-0042", "zone-10", "ราชบุรีมาร์ท", "อ.เมือง จ.ราชบุรี", 65, 1000, 3.6, 4900, [13.5282, 99.8134], "WPD", "2026-08-03", "2026-08-05"),
            ],
        },

        // ── 3 · ส่งให้ MMX — handed over, waiting on WMS ───────────────────────
        new Manifest
        {
            Id = "mn-1",
            ManifestNo = "MN-202608-0041",
            Status = ManifestStatus.Sent,
            SentAt = At(2, 9, 5),
            ClosedAt = At(2, 8, 30),
            ConfirmedAt = At(2, 8, 45),
            WarehouseCode = "WSK",
            CreatedBy = "admin : Next",
            DeliveryDate = "2026-08-04",
            DriverId = "dr-2",
            DriverName = "สมชาย ใจดี",
            DriverPhone = "081-111-2222",
            PlateHead = "70-1234 นนทบุรี",
            PlateTrailer = "71-5678 นนทบุรี",
            Vehicle = "6-wheel",
            AssistantCount = 1,
            MaxPayloadKg = 12_000,
            MaxVolumeCbm = 35,
            CarrierId = "cr-1",
            Carrier = "Fleet อินเฮาส์ (คลังบางบัวทอง)",
            RouteId = "rt-2",
            RouteCode = "RT-EAST-01",
            RouteName = "สายตะวันออก (ชลบุรี - ระยอง)",
            Origin = DcNonthaburi,
            Dock = "Dock 2",
            SealNo = "SL-9988420",
            // An in-house run carries no trip rate — the truck is already paid for.
            FreightCost = 0,
            Pricing = new FreightPricing(),
            Colour = Palette.RouteColour(2),
            Stops =
            [
                Stop("h-1", "DO-2026-0771", "MN-202608-0041", "zone-7", "ชลบุรี ซูเปอร์มาร์เก็ต", "อ.ศรีราชา จ.ชลบุรี", 160, 3200, 11, 0, [13.1731, 100.9310], "WSK", "2026-08-01", "2026-08-04"),
                Stop("h-2", "DO-2026-0772", "MN-202608-0041", "zone-8", "ระยองฟู้ดส์", "อ.เมือง จ.ระยอง", 110, 2100, 7.5, 12800, [12.6814, 101.2816], "WSK", "2026-08-01", "2026-08-04"),
            ],
        },

        // ── 5 · SAP/OMS ตอบกลับ — the full chain cleared ───────────────────────
        new Manifest
        {
            Id = "mn-2",
            ManifestNo = "MN-202608-0040",
            Status = ManifestStatus.Completed,
            StatusMessage = "OMS ยืนยันการจัดส่งครบถ้วน",
            SentAt = At(1, 8, 0),
            ClosedAt = At(1, 7, 15),
            ConfirmedAt = At(1, 7, 40),
            WarehouseCode = "WPD",
            CreatedBy = "admin : Next",
            DeliveryDate = "2026-08-03",
            DriverId = "dr-4",
            DriverName = "วิชัย พงษ์ทอง",
            DriverPhone = "089-876-5432",
            PlateHead = "82-4455 กรุงเทพมหานคร",
            PlateTrailer = "-",
            Vehicle = "4-wheel",
            AssistantCount = 0,
            MaxPayloadKg = 3_500,
            MaxVolumeCbm = 12,
            CarrierId = "cr-2",
            Carrier = "ไทยขนส่งด่วน",
            RouteId = "rt-3",
            RouteCode = "RT-WEST-02",
            RouteName = "สายตะวันตก (นครปฐม - ราชบุรี)",
            Origin = DcNonthaburi,
            Dock = "Dock 1",
            SealNo = "SL-9988418",
            // A subcontracted run: the trip rate plus a wait charge, less a missed drop.
            FreightCost = 8_500,
            Pricing = new FreightPricing
            {
                TripPrice = 8_000,
                PriceAdd = 800,
                PriceDeduct = 300,
                FreightNote = "รอคิวลงสินค้าที่ราชบุรี 2 ชม. · หักจุดส่งที่ลูกค้าเลื่อนรับ",
            },
            Colour = Palette.RouteColour(3),
            Stops =
            [
                Stop("h-3", "DO-2026-0765", "MN-202608-0040", "zone-9", "นครปฐมค้าส่ง", "อ.เมือง จ.นครปฐม", 60, 900, 3.2, 0, [13.8199, 100.0621], "WPD", "2026-07-30", "2026-08-03", status: "delivered"),
                // Goes to a third-party site rather than the customer's own address,
                // so the "ส่งต่างที่" report has a completed run to report on.
                Stop("h-4", "DO-2026-0766", "MN-202608-0040", "zone-10", "ราชบุรีมาร์ท", "อ.เมือง จ.ราชบุรี", 70, 1100, 4.0, 5600, [13.5282, 99.8134], "WPD", "2026-07-30", "2026-08-03", status: "delivered", deliverTo: "โรงตัดนอก ราชบุรี (รับของแทนลูกค้า)"),
            ],
        },

        // ── 4 · WMS ตรวจ QC — got that far and was turned back ─────────────────
        new Manifest
        {
            Id = "mn-5",
            ManifestNo = "MN-202608-0039",
            Status = ManifestStatus.Error,
            StatusMessage = "WMS ตีกลับ — จำนวนกล่องไม่ตรงกับใบสั่งส่ง DO-2026-0786",
            SentAt = AtJuly(31, 10, 20),
            ClosedAt = AtJuly(31, 9, 0),
            ConfirmedAt = AtJuly(31, 9, 35),
            WarehouseCode = "WWP",
            CreatedBy = "admin : Next",
            DeliveryDate = "2026-08-02",
            DriverId = "dr-3",
            DriverName = "ประเสริฐ ศรีสุข",
            DriverPhone = "086-555-7777",
            PlateHead = "82-7788 กรุงเทพมหานคร",
            PlateTrailer = "-",
            Vehicle = "6-wheel",
            AssistantCount = 1,
            MaxPayloadKg = 8_000,
            MaxVolumeCbm = 22,
            CarrierId = "cr-3",
            Carrier = "สยามโลจิสติกส์ พาร์ทเนอร์",
            RouteId = "rt-2",
            RouteCode = "RT-EAST-01",
            RouteName = "สายตะวันออก (ชลบุรี - ระยอง)",
            Origin = DcNonthaburi,
            Dock = "Dock 2",
            SealNo = "SL-9988409",
            FreightCost = 6_400,
            Pricing = new FreightPricing { TripPrice = 6_400 },
            Colour = Palette.RouteColour(4),
            Stops =
            [
                // The drop QC stopped the load on, kept as `returned` so the document
                // says which one rather than only that something went wrong.
                Stop("h-9", "DO-2026-0786", "MN-202608-0039", "zone-7", "ชลบุรี ซูเปอร์มาร์เก็ต", "อ.ศรีราชา จ.ชลบุรี", 130, 2600, 8.8, 0, [13.1731, 100.9310], "WWP", "2026-07-30", "2026-08-02", status: "returned"),
                Stop("h-10", "DO-2026-0787", "MN-202608-0039", "zone-8", "ระยองฟู้ดส์", "อ.เมือง จ.ระยอง", 85, 1700, 5.9, 9100, [12.6814, 101.2816], "WWP", "2026-07-30", "2026-08-02"),
            ],
        },
    ];

    /// <summary>
    /// One empty draft so the screen has shape. It holds no orders on purpose:
    /// taking them from the pool at startup would make them vanish from the
    /// pending-pool screen before anyone had planned anything.
    /// </summary>
    public static List<TransportPlan> TransportPlans() =>
    [
        new TransportPlan
        {
            Id = "pl-1",
            PlanNo = "PL-202608-0001",
            Status = TransportPlanStatus.Draft,
            CreatedAt = At(5, 2, 15),
            CreatedBy = "admin : Next",
            WarehouseCode = "WSK",
            DeliveryDate = "2026-08-07",
            RouteId = "rt-1",
            RouteCode = "RT-NORTH-01",
            RouteName = "สายเหนือ (นครสวรรค์ - พิษณุโลก)",
            Note = "รอบเช้า สายเหนือ",
            Stops = [],
        },
    ];

    /// <summary>
    /// WSK/WPD/WWP are the codes the pick screens and every document already use;
    /// Nonthaburi and Bangna are the two origins the route and manifest fixtures
    /// were drawn from. Both sets are kept so no fixture points at a missing site.
    /// </summary>
    public static List<Warehouse> Warehouses() =>
    [
        new() { Id = "wh-1", Code = "WSK", Name = "คลังสีคิ้ว", Address = "นิคมอุตสาหกรรมสีคิ้ว", Province = "นครราชสีมา", District = "สีคิ้ว", SubDistrict = "ลาดบัวขาว", ZipCode = "30140", Position = [14.8869, 101.7264], IsDC = true, Active = true },
        new() { Id = "wh-2", Code = "WPD", Name = "คลังปทุมธานี", Address = "ถนนติวานนท์", Province = "ปทุมธานี", District = "เมืองปทุมธานี", SubDistrict = "บางกะดี", ZipCode = "12000", Position = [14.0208, 100.5250], IsDC = true, Active = true },
        new() { Id = "wh-3", Code = "WWP", Name = "คลังวังน้อย", Address = "นิคมอุตสาหกรรมวังน้อย", Province = "พระนครศรีอยุธยา", District = "วังน้อย", SubDistrict = "ลำตาเสา", ZipCode = "13170", Position = [14.2167, 100.7167], IsDC = true, Active = true },
        new() { Id = "wh-4", Code = "WNB", Name = "DC นนทบุรี", Address = "ถนนรัตนาธิเบศร์", Province = "นนทบุรี", District = "เมืองนนทบุรี", SubDistrict = "บางกระสอ", ZipCode = "11000", Position = [13.8591, 100.5217], IsDC = true, Active = true },
        new() { Id = "wh-5", Code = "WBN", Name = "DC บางนา", Address = "ถนนบางนา-ตราด กม.19", Province = "สมุทรปราการ", District = "บางพลี", SubDistrict = "บางแก้ว", ZipCode = "10540", Position = [13.6683, 100.6045], IsDC = true, Active = true },
    ];

    /// <summary>
    /// One province per zone, because that is what the type can hold. A run that
    /// spans several of them is a route covering several zones, which is the job
    /// <c>RouteMaster.DeliveryZoneIds</c> already does.
    ///
    /// District names carry the อำเภอ prefix the geo register uses — without it
    /// the zone form cannot tick back what a zone already covers.
    /// </summary>
    private static readonly (string Province, double Weight, string Areas)[] Territories =
    [
        ("นครสวรรค์", 12_500, "อำเภอเมืองนครสวรรค์, อำเภอพยุหะคีรี, อำเภอโกรกพระ, อำเภอชุมแสง, อำเภอท่าตะโก"),
        ("พิจิตร", 9_800, "อำเภอเมืองพิจิตร, อำเภอตะพานหิน, อำเภอบางมูลนาก, อำเภอสามง่าม"),
        ("พิษณุโลก", 15_400, "อำเภอเมืองพิษณุโลก, อำเภอวังทอง, อำเภอบางระกำ, อำเภอพรหมพิราม"),
        ("พระนครศรีอยุธยา", 18_200, "อำเภอพระนครศรีอยุธยา, อำเภอบางปะอิน, อำเภอวังน้อย, อำเภอนครหลวง, อำเภออุทัย"),
        ("ลพบุรี", 11_200, "อำเภอเมืองลพบุรี, อำเภอบ้านหมี่, อำเภอโคกสำโรง, อำเภอท่าวุ้ง"),
        ("สระบุรี", 13_600, "อำเภอเมืองสระบุรี, อำเภอแก่งคอย, อำเภอหนองแค, อำเภอวิหารแดง"),
        ("ชลบุรี", 24_000, "อำเภอเมืองชลบุรี, อำเภอศรีราชา, อำเภอบางละมุง, อำเภอพานทอง, อำเภอสัตหีบ"),
        ("ระยอง", 16_800, "อำเภอเมืองระยอง, อำเภอบ้านฉาง, อำเภอปลวกแดง, อำเภอนิคมพัฒนา, อำเภอแกลง"),
        ("นครปฐม", 21_500, "อำเภอเมืองนครปฐม, อำเภอสามพราน, อำเภอนครชัยศรี, อำเภอกำแพงแสน, อำเภอบางเลน"),
        ("ราชบุรี", 14_300, "อำเภอเมืองราชบุรี, อำเภอบ้านโป่ง, อำเภอโพธาราม, อำเภอดำเนินสะดวก, อำเภอบางแพ"),
    ];

    public static List<DeliveryZone> DeliveryZones() =>
        [.. Territories.Select((t, i) => new DeliveryZone
        {
            Id = $"zone-{i + 1}",
            Code = $"TH-{(i + 1).ToString().PadLeft(3, '0')}",
            Name = $"โซน{t.Province}",
            Areas = t.Areas,
            Province = t.Province,
            District = "",
            SubDistrict = "",
            ZipCode = "",
            Weight = t.Weight,
            WeightUnit = "kg",
        })];

    public static List<RouteMaster> Routes() =>
    [
        // พิจิตร sits between the two the name gives, so the run passes through it.
        new() { Id = "rt-1", Code = "RT-NORTH-01", Name = "สายเหนือ (นครสวรรค์ - พิษณุโลก)", DeliveryZoneIds = ["zone-1", "zone-2", "zone-3"], DefaultOrigin = new GeoPoint("DC นนทบุรี", [13.8591, 100.5217]), Colour = Palette.RouteColours[0], Active = true },
        new() { Id = "rt-2", Code = "RT-EAST-01", Name = "สายตะวันออก (ชลบุรี - ระยอง)", DeliveryZoneIds = ["zone-7", "zone-8"], DefaultOrigin = new GeoPoint("DC บางนา", [13.6683, 100.6045]), Colour = Palette.RouteColours[1], Active = true },
        new() { Id = "rt-3", Code = "RT-WEST-02", Name = "สายตะวันตก (นครปฐม - ราชบุรี)", DeliveryZoneIds = ["zone-9", "zone-10"], DefaultOrigin = new GeoPoint("DC นนทบุรี", [13.8591, 100.5217]), Colour = Palette.RouteColours[0], Active = true },
        new() { Id = "rt-4", Code = "RT-SOUTH-01", Name = "สายใต้ (เพชรบุรี - ประจวบฯ)", DeliveryZoneIds = [], DefaultOrigin = new GeoPoint("DC บางนา", [13.6683, 100.6045]), Colour = Palette.RouteColours[1], Active = false },
    ];

    public static List<Carrier> Carriers() =>
    [
        new() { Id = "cr-1", Code = "CR-001", Name = "Fleet อินเฮาส์ (คลังบางบัวทอง)", Type = "in-house", ContactName = "ฝ่ายขนส่ง คลังบางบัวทอง", Phone = "02-123-4567", Email = "fleet@mammod.co.th", TaxId = "0105542000111", Active = true },
        new() { Id = "cr-2", Code = "CR-002", Name = "ไทยขนส่งด่วน", Type = "subcontract", ContactName = "คุณสมหมาย ธนกิจ", Phone = "081-999-1122", Email = "ops@thaiexpress.co.th", TaxId = "0105551002233", Active = true },
        new() { Id = "cr-3", Code = "CR-003", Name = "สยามโลจิสติกส์ พาร์ทเนอร์", Type = "subcontract", ContactName = "คุณวราภรณ์ สุขใจ", Phone = "089-444-7788", Email = "dispatch@siamlogistics.co.th", TaxId = "0105560004455", Active = true },
        new() { Id = "cr-4", Code = "CR-004", Name = "บูรพาทรานสปอร์ต", Type = "subcontract", ContactName = "คุณอนันต์ บูรพา", Phone = "086-222-3344", Email = "-", TaxId = "0205549006677", Active = false },
    ];

    /// <summary>Rigid trucks carry no trailer, so their trailer plate is "-".</summary>
    public static List<FleetVehicle> FleetVehicles() =>
    [
        new() { Id = "v-1", Type = "10-wheel", PlateHead = "70-1234 นนทบุรี", PlateTrailer = "71-5678 นนทบุรี", CarrierId = "cr-1", MaxPayloadKg = 15_000, MaxVolumeCbm = 35, Active = true },
        new() { Id = "v-2", Type = "10-wheel", PlateHead = "70-9012 นนทบุรี", PlateTrailer = "71-3344 นนทบุรี", CarrierId = "cr-1", MaxPayloadKg = 15_000, MaxVolumeCbm = 35, Active = true },
        new() { Id = "v-3", Type = "6-wheel", PlateHead = "82-4455 กรุงเทพมหานคร", PlateTrailer = "-", CarrierId = "cr-2", MaxPayloadKg = 8_000, MaxVolumeCbm = 22, Active = true },
        new() { Id = "v-4", Type = "6-wheel", PlateHead = "82-7788 กรุงเทพมหานคร", PlateTrailer = "-", CarrierId = "cr-3", MaxPayloadKg = 8_000, MaxVolumeCbm = 22, Active = true },
        new() { Id = "v-5", Type = "4-wheel", PlateHead = "1กต 2414", PlateTrailer = "-", CarrierId = "cr-2", MaxPayloadKg = 3_500, MaxVolumeCbm = 12, Active = true },
        new() { Id = "v-6", Type = "4-wheel", PlateHead = "1กก 8899", PlateTrailer = "-", CarrierId = "cr-3", MaxPayloadKg = 3_500, MaxVolumeCbm = 12, Active = false },
    ];

    public static List<Driver> Drivers() =>
    [
        new() { Id = "dr-1", Code = "DRV-001", Name = "สมศักดิ์ ขยันส่ง", Phone = "081-234-5678", LicenseNo = "6401234567", LicenseType = "ท.3", CarrierId = "cr-1", Active = true },
        new() { Id = "dr-2", Code = "DRV-002", Name = "สมชาย ใจดี", Phone = "081-111-2222", LicenseNo = "6402345678", LicenseType = "ท.2", CarrierId = "cr-1", Active = true },
        new() { Id = "dr-3", Code = "DRV-003", Name = "ประเสริฐ ศรีสุข", Phone = "086-555-7777", LicenseNo = "6403456789", LicenseType = "ท.2", CarrierId = "cr-2", Active = true },
        new() { Id = "dr-4", Code = "DRV-004", Name = "วิชัย พงษ์ทอง", Phone = "089-876-5432", LicenseNo = "6404567890", LicenseType = "ท.2", CarrierId = "cr-2", Active = true },
        new() { Id = "dr-5", Code = "DRV-005", Name = "อนุชา ทองดี", Phone = "087-321-9900", LicenseNo = "6405678901", LicenseType = "ท.1", CarrierId = "cr-3", Active = true },
        new() { Id = "dr-6", Code = "DRV-006", Name = "ธนพล แสนดี", Phone = "092-448-1100", LicenseNo = "6406789012", LicenseType = "ท.2", CarrierId = "cr-3", Active = false },
    ];

    /// <summary>
    /// Only OMS and MMX appear. MMX's own task assignment, the WMS QC check and
    /// SAP recording the shipment all reach TMS as one Status.Update from OMS —
    /// listing those systems here would put filters in the log that never match.
    /// </summary>
    public static List<IntegrationMessage> IntegrationMessages() =>
    [
        // Channel is "Order.Create", not "SO.Create": what OMS forwards is the
        // customer's order from SAP, and SO in this system means the ใบปิดบรรทุก
        // TMS itself cuts later. Naming the inbound channel SO would say OMS
        // creates loading sheets, which it does not.
        new() { Id = "msg-1", Direction = "in", System = "OMS", Channel = "Order.Create", Reference = "OMS-99200238", At = Seed.At(4, 1, 12), Status = "success", Detail = "รับใบสั่งจากลูกค้าใหม่ 1 รายการ" },
        new() { Id = "msg-2", Direction = "in", System = "OMS", Channel = "Order.Create", Reference = "OMS-99200237", At = Seed.At(4, 1, 12), Status = "success", Detail = "รับใบสั่งจากลูกค้าใหม่ 1 รายการ" },
        new() { Id = "msg-3", Direction = "out", System = "MMX", Channel = "Manifest.Send", Reference = "MN-202608-0041", At = Seed.At(4, 2, 5), Status = "success", Detail = "ส่งใบปิดบรรทุก 2 จุดส่ง" },
        new() { Id = "msg-4", Direction = "in", System = "OMS", Channel = "Status.Update", Reference = "MN-202608-0040", At = Seed.At(3, 10, 2), Status = "success", Detail = "WMS ตรวจ QC ครบถ้วน · SAP รับรู้การจัดส่งแล้ว" },
        new() { Id = "msg-6", Direction = "out", System = "MMX", Channel = "Manifest.Send", Reference = "MN-202608-0039", At = Seed.At(3, 6, 15), Status = "failed", Detail = "เชื่อมต่อ MMX ไม่สำเร็จ (timeout 30s)" },
        new() { Id = "msg-7", Direction = "in", System = "OMS", Channel = "Status.Update", Reference = "MN-202608-0039", At = Seed.At(3, 6, 20), Status = "pending", Detail = "รอ OMS ตอบกลับสถานะ" },
    ];
}
