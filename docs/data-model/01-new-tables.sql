/* =============================================================================
   MamMoD (MMPRD) — ตารางที่ยังไม่มีในฐานจริง
   SQL Server · รันไฟล์นี้ก่อน 02-alter-existing.sql

   ตรงกับ MAMMOD_TABLE2_R03.sql (ฐาน MMDEV) แล้ว ไม่ใช่ตามไดอะแกรม ER
   ซึ่งคลาดเคลื่อนจากฐานหลายจุด (ดู README.md หัวข้อ 1)

   R03 เพิ่ม MST_TRANSPORTATIONZONE กับ TRX_TODODETAIL มาจาก R02 → หัวข้อ 2
   ในไฟล์นี้ถูกถอนออก และหัวข้อ 3, 4, 7 เปลี่ยนไปผูกกับตารางที่มีอยู่แทน
   เหลือตารางที่สร้างจริง 10 ใบ

   ข้อตกลงที่ลอกมาจากตารางเดิม ไม่ได้คิดขึ้นใหม่
   - ทุกตารางมี  [SERIALKEY] int IDENTITY(1,1)  เป็นคีย์แทน
   - คีย์ธุรกิจเป็น NVARCHAR ตามความยาวที่ตารางเดิมใช้:
       WHSEID nvarchar(30) · OWNERKEY nvarchar(15) · SKU nvarchar(50)
       TRANSPORTERKEY / VEHICLEKEY / DRIVERKEY / VEHICLETYPEKEY nvarchar(20)
       SHIPMENTKEY nvarchar(30) · ORDERKEY nvarchar(50) · ROUTE / ZONE nvarchar(20)
   - จำนวน/น้ำหนัก/ปริมาตร  decimal(22,5)  · เงิน decimal(22,5) (ไม่ใช่ float)
   - เวลา  datetime  · วันที่ทางธุรกิจ  date
   - audit  ADDDATE / ADDWHO / EDITDATE / EDITWHO  + SUSR1..SUSR5 สำรอง
   - STATUS เป็น **ตัวพิมพ์ใหญ่** ('ACTIVE' / 'NEW' / 'OK') ตามที่ฐานเดิมตั้ง
     DEFAULT ไว้ — ฝั่ง UI ใช้ตัวพิมพ์เล็ก จึงต้องมี mapping ที่ backend
     (ดู README หัวข้อ 4)
============================================================================= */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* -----------------------------------------------------------------------------
   1 · MST_ROUTE — สายส่ง
   ROUTE เป็นคอลัมน์ข้อความลอยอยู่ใน DOC_DO_HDR, DOC_SHIPMENT_HDR,
   DOC_SHIPMENT_DETAIL, DOC_DO_PICKDETAIL, MST_TRANSPORTER_ROUTE และ
   MST_TRANSPORT_RATE โดยไม่มีตารางแม่ — นี่คือช่องว่างจริงที่ใหญ่สุดที่เหลือ
   ไม่ถือวันที่ รถ หรือซีล เพราะสายส่งหนึ่งถูกวิ่งซ้ำได้ทุกวัน
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ROUTE](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NULL,
    [ROUTE]         [nvarchar](20)  NOT NULL,   -- ชื่อคอลัมน์เดียวกับที่ตารางอื่นใช้อ้าง
    [ROUTENAME]     [nvarchar](200) NOT NULL,
    [DESCRIPTION]   [nvarchar](250) NULL,
    [ORIGIN_WHSEID] [nvarchar](30)  NULL,       -- DC ที่รถออก
    [COLOURHEX]     [nvarchar](7)   NULL,       -- สีเส้นบนแผนที่
    [TRANSIT_DAY]   [int]           NULL,
    [CUT_OFF_TIME]  [time](7)       NULL,
    [STATUS]        [nvarchar](10)  NOT NULL,
    [NOTES]         [nvarchar](500) NULL,
    [ADDDATE]       [datetime]      NOT NULL,
    [ADDWHO]        [nvarchar](100) NULL,
    [EDITDATE]      [datetime]      NULL,
    [EDITWHO]       [nvarchar](100) NULL,
    [SUSR1]         [nvarchar](100) NULL,
    [SUSR2]         [nvarchar](100) NULL,
    [SUSR3]         [nvarchar](100) NULL,
    [SUSR4]         [nvarchar](100) NULL,
    [SUSR5]         [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_ROUTE] PRIMARY KEY CLUSTERED ([ROUTE] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_ROUTE] ADD CONSTRAINT [DF_MST_ROUTE_STATUS]  DEFAULT ('ACTIVE') FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_ROUTE] ADD CONSTRAINT [DF_MST_ROUTE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

/* -----------------------------------------------------------------------------
   2 · ~~MST_DELIVERY_ZONE~~ — ไม่ต้องสร้าง ฐานมีแล้วตั้งแต่ R03

   R02 ไม่มีตารางโซนจัดส่ง จึงเคยเสนอ `MST_DELIVERY_ZONE` ไว้ตรงนี้
   **R03 เพิ่ม `MST_TRANSPORTATIONZONE` มาแล้ว** และทำหน้าที่เดียวกัน:

       PK (WHSEID, OWNERKEY, TRANSPORTZONEKEY)
       TRANSPORTZONENAME · DESCRIPTION · COUNTRY · REGION
       PROVINCE · DISTRICT · POSTALCODE_FROM · POSTALCODE_TO
       DELIVERYLEADDAY · DEFAULTROUTE · PRIORITY · STATUS

   และ `MST_SHIPTO` ก็ได้คอลัมน์ `TRANSPORTZONEKEY` มาชี้กลับหาแล้ว → ปัญหา
   "จัดโซนให้ใบสั่งส่งไม่ได้" ที่ README หัวข้อ 2.4 บอกไว้ ถูกแก้ไปครึ่งหนึ่ง
   สร้างตารางซ้ำอีกใบมีแต่จะได้โซนสองชุดที่ไม่ตรงกัน จึงตัดออก

   ที่ยังขาด: ตารางนี้เก็บ **หนึ่งโซนต่อหนึ่งกฎพื้นที่** (PROVINCE/DISTRICT
   หรือช่วง POSTALCODE ชุดเดียว) เพราะ PK ไม่มีคอลัมน์พื้นที่อยู่ด้วย
   โซนที่กินหลายจังหวัดหรือหลายช่วงไปรษณีย์จึงเขียนลงไปไม่ได้ →
   `MST_ZONE_COVERAGE` ในหัวข้อ 3 มาเติมส่วนนั้น

   สองอย่างที่เสนอไว้แต่ `MST_TRANSPORTATIONZONE` ไม่มี และ **ยังไม่เติมให้**
   เพราะยังไม่มีจอไหนใช้: `MAX_VEHICLE_WEIGHT` (น้ำหนักรถสูงสุดที่เข้าพื้นที่ได้
   — สะพาน ซอยแคบ เขตห้ามรถบรรทุก) กับ `SERVICE_MINUTE` ต่อโซน
   ถ้าจะใช้จริง ให้เพิ่มเป็น ALTER ในไฟล์ 02 ส่วน C ไม่ใช่สร้างตารางใหม่
----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   3 · MST_ZONE_COVERAGE — พื้นที่ที่โซนหนึ่งครอบคลุม
   ทำให้จัดโซนให้ใบสั่งส่งที่ไหลเข้ามาได้เอง โดยแมปจากที่อยู่ปลายทาง
   MST_SHIPTO เก็บที่อยู่แบบตะวันตก (city/state/zip) ส่วน DOC_SHIPMENT_STOP
   เก็บแบบไทย (SUBDISTRICT/DISTRICT/PROVINCE/POSTALCODE) — POSTALCODE คือ
   ตัวที่แมปได้แน่นอนที่สุด จึงเป็นคอลัมน์ที่ควรใช้เป็นกุญแจหลัก

   ลูกของ MST_TRANSPORTATIONZONE ที่มีอยู่แล้ว ไม่ใช่ตารางโซนใบใหม่ — ตัวแม่
   ถือได้กฎเดียว ตารางนี้ถือได้หลายกฎต่อโซน

   ⚠ สองที่ที่บอกพื้นที่ของโซนได้ ต้องเลือกให้ชัดว่าอ่านจากที่ไหน
     `MST_TRANSPORTATIONZONE.PROVINCE/DISTRICT/POSTALCODE_FROM/TO` มีข้อมูลอยู่
     แล้วในฐานจริง ถ้ารับตารางนี้เข้ามา ให้ถือว่าคอลัมน์บนตัวแม่เป็น *ค่าที่แสดง
     บนหน้าจอ master* ส่วนการ **ค้นว่าที่อยู่นี้อยู่โซนไหน ให้อ่านจากตารางนี้
     ที่เดียว** แล้ว migrate ค่าบนตัวแม่ลงมาเป็นแถวแรกของแต่ละโซน
     (ดูสคริปต์ท้ายหัวข้อนี้) — ต้องยืนยันกับทีมที่ดูแลฐานก่อน
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ZONE_COVERAGE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    /* สามคอลัมน์นี้คือ PK ของ MST_TRANSPORTATIONZONE ต้องมีครบถึงจะผูก FK ได้
       OWNERKEY เป็น nvarchar(20) ตามตัวแม่ ไม่ใช่ 15 อย่างที่อีก 16 ตารางใช้ —
       ความไม่ตรงกันนี้เป็นของฐานเดิม ดู README หัวข้อ 2.10 */
    [WHSEID]           [nvarchar](30)  NOT NULL,
    [OWNERKEY]         [nvarchar](20)  NOT NULL,
    [TRANSPORTZONEKEY] [nvarchar](20)  NOT NULL,
    [PROVINCE]     [nvarchar](100) NOT NULL,
    [DISTRICT]     [nvarchar](100) NULL,
    [SUBDISTRICT]  [nvarchar](100) NULL,
    [POSTALCODE]   [nvarchar](10)  NULL,
    [STATUS]       [nvarchar](10)  NOT NULL,
    [ADDDATE]      [datetime]      NOT NULL,
    [ADDWHO]       [nvarchar](100) NULL,
    [EDITDATE]     [datetime]      NULL,
    [EDITWHO]      [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_ZONE_COVERAGE] PRIMARY KEY CLUSTERED ([SERIALKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_ZONE_COVERAGE] ADD CONSTRAINT [DF_MST_ZONE_COVERAGE_STATUS]  DEFAULT ('ACTIVE') FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_ZONE_COVERAGE] ADD CONSTRAINT [DF_MST_ZONE_COVERAGE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[MST_ZONE_COVERAGE] WITH CHECK ADD CONSTRAINT [FK_MST_ZONE_COVERAGE_ZONE]
    FOREIGN KEY([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY])
    REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY])
GO

/* ที่อยู่หนึ่งต้องตกอยู่ในโซนเดียว ไม่ใช่สองโซน — ไม่งั้นการจัดโซนอัตโนมัติ
   ต้องเดา ดัชนีนี้กันไว้ตั้งแต่ระดับฐาน
   ขอบเขตความไม่ซ้ำคือ *ต่อคลัง* เพราะคนละคลังแบ่งโซนคนละแบบได้
   NULL ใน SQL Server ถือว่าเท่ากันในดัชนี unique → กฎแบบครอบทั้งจังหวัด
   (DISTRICT/SUBDISTRICT/POSTALCODE เป็น NULL) มีได้จังหวัดละแถวเดียว ซึ่งถูกต้อง */
CREATE UNIQUE INDEX [UX_MST_ZONE_COVERAGE_AREA]
    ON [dbo].[MST_ZONE_COVERAGE] ([WHSEID], [PROVINCE], [DISTRICT], [SUBDISTRICT], [POSTALCODE])
GO
CREATE INDEX [IX_MST_ZONE_COVERAGE_POSTALCODE]
    ON [dbo].[MST_ZONE_COVERAGE] ([POSTALCODE]) INCLUDE ([TRANSPORTZONEKEY])
GO

/* ย้ายกฎที่อยู่บนตัวแม่ลงมาเป็นแถวแรกของแต่ละโซน — รันครั้งเดียวหลังรับตารางนี้
   เฉพาะโซนที่ระบุจังหวัดไว้ ส่วนโซนที่ใช้แต่ช่วงไปรษณีย์ต้องกางเป็นรายรหัสเอง
   ซึ่งกางอัตโนมัติไม่ได้ (ช่วง 10110-10240 ไม่ได้แปลว่าทุกเลขในช่วงมีจริง)
   ตรวจผลก่อน commit */
-- INSERT INTO dbo.MST_ZONE_COVERAGE
--       (WHSEID, OWNERKEY, TRANSPORTZONEKEY, PROVINCE, DISTRICT, POSTALCODE, STATUS, ADDWHO)
-- SELECT z.WHSEID, z.OWNERKEY, z.TRANSPORTZONEKEY, z.PROVINCE, z.DISTRICT,
--        CASE WHEN z.POSTALCODE_FROM = z.POSTALCODE_TO THEN z.POSTALCODE_FROM END,
--        'ACTIVE', SUSER_SNAME()
-- FROM   dbo.MST_TRANSPORTATIONZONE z
-- WHERE  z.PROVINCE IS NOT NULL;

/* -----------------------------------------------------------------------------
   4 · MST_ROUTE_ZONE — สายส่ง ↔ โซน พร้อมลำดับการวิ่ง
   MST_TRANSPORTER_ROUTE ที่มีอยู่ตอบว่า "ผู้ให้บริการรายไหนวิ่งสายไหน"
   แต่ไม่มีที่ไหนตอบว่า "สายส่งหนึ่งครอบคลุมโซนอะไร ลำดับไหน"
   (และ PK ของตารางนั้นเป็น TRANSPORTERKEY+ROUTE ทำให้แตกเป็นรายโซนไม่ได้)

   ไม่มีคอลัมน์ "สายหลักของโซน" ในตารางนี้ เพราะ
   `MST_TRANSPORTATIONZONE.DEFAULTROUTE` ถืออยู่แล้วตั้งแต่ R03 — ตารางนี้ตอบ
   แค่ว่า *สายไหนผ่านโซนไหน ลำดับที่เท่าไหร่* ให้มีคำตอบเดียวต่อคำถามเดียว
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ROUTE_ZONE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    [ROUTE]        [nvarchar](20) NOT NULL,
    /* สามคอลัมน์ตาม PK ของ MST_TRANSPORTATIONZONE เหมือนใน MST_ZONE_COVERAGE */
    [WHSEID]           [nvarchar](30) NOT NULL,
    [OWNERKEY]         [nvarchar](20) NOT NULL,
    [TRANSPORTZONEKEY] [nvarchar](20) NOT NULL,
    [SEQUENCE]     [int]          NOT NULL,
    [STATUS]       [nvarchar](10) NOT NULL,
    [ADDDATE]      [datetime]      NOT NULL,
    [ADDWHO]       [nvarchar](100) NULL,
    [EDITDATE]     [datetime]      NULL,
    [EDITWHO]      [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_ROUTE_ZONE] PRIMARY KEY CLUSTERED
    ([ROUTE] ASC, [WHSEID] ASC, [OWNERKEY] ASC, [TRANSPORTZONEKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_SEQ]     DEFAULT ((1))      FOR [SEQUENCE]
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_STATUS]  DEFAULT ('ACTIVE') FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[MST_ROUTE_ZONE] WITH CHECK ADD CONSTRAINT [FK_MST_ROUTE_ZONE_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] WITH CHECK ADD CONSTRAINT [FK_MST_ROUTE_ZONE_ZONE]
    FOREIGN KEY([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY])
    REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY])
GO

/* ลำดับการวิ่งห้ามซ้ำในสายเดียวกัน — ไม่งั้นไม่รู้ว่าโซนไหนก่อน */
CREATE UNIQUE INDEX [UX_MST_ROUTE_ZONE_SEQ]
    ON [dbo].[MST_ROUTE_ZONE] ([ROUTE], [SEQUENCE])
GO

/* -----------------------------------------------------------------------------
   5 · DOC_TRANSPORT_PLAN / _LINE — ชั้นแผนขนส่ง PL-…
   ระบบวางแผนก่อนแล้วค่อยออกใบปิดบรรทุก แต่ฐานมีแต่ชั้นใบปิดบรรทุก
   แผนไม่ถือรถ คนขับ หรือซีล เพราะการวางแผนตอบว่า *อะไรไปด้วยกัน*
   ส่วนผู้จัดรถตอบว่า *ไปด้วยอะไร* ตอนแก้ใบปิดบรรทุก

   กฎ "ของอยู่ได้ที่เดียว": ใบสั่งส่งหนึ่งใบอยู่ในคิว หรือในแผน หรือบน
   ใบปิดบรรทุก อย่างใดอย่างเดียว UNIQUE บน ORDERKEY ของบรรทัดแผนบังคับ
   ครึ่งแรก อีกครึ่งอยู่ใน 02-alter-existing.sql
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_TRANSPORT_PLAN](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NOT NULL,
    [PLANKEY]       [nvarchar](30)  NOT NULL,   -- PL-202608-0007
    [PLANDATE]      [datetime]      NOT NULL,
    [DELIVERYDATE]  [date]          NOT NULL,   -- วันที่นัดส่ง คนละวันกับ PLANDATE
    [ZONE]          [nvarchar](20)  NULL,
    [ROUTE]         [nvarchar](20)  NULL,
    [SHIPMENTKEY]   [nvarchar](30)  NULL,       -- ใบปิดบรรทุกที่ออกจากแผนนี้
    [TOTALORDER]    [int]            NULL,
    [TOTALWEIGHT]   [decimal](22, 5) NULL,
    [TOTALCUBE]     [decimal](22, 5) NULL,
    [STATUS]        [nvarchar](20)  NOT NULL,   -- DRAFT | ISSUED | CANCELLED
    [CANCELREASON]  [nvarchar](500) NULL,       -- ไม่บังคับกรอก
    [NOTES]         [nvarchar](1000) NULL,
    [ADDDATE]       [datetime]      NOT NULL,
    [ADDWHO]        [nvarchar](100) NULL,
    [EDITDATE]      [datetime]      NULL,
    [EDITWHO]       [nvarchar](100) NULL,
    [SUSR1]         [nvarchar](100) NULL,
    [SUSR2]         [nvarchar](100) NULL,
    [SUSR3]         [nvarchar](100) NULL,
    [SUSR4]         [nvarchar](100) NULL,
    [SUSR5]         [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_TRANSPORT_PLAN] PRIMARY KEY CLUSTERED ([WHSEID] ASC, [PLANKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] ADD CONSTRAINT [DF_DOC_TRANSPORT_PLAN_STATUS]   DEFAULT ('DRAFT')   FOR [STATUS]
GO
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] ADD CONSTRAINT [DF_DOC_TRANSPORT_PLAN_PLANDATE] DEFAULT (getdate()) FOR [PLANDATE]
GO
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] ADD CONSTRAINT [DF_DOC_TRANSPORT_PLAN_ADDDATE]  DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] WITH CHECK ADD CONSTRAINT [CK_DOC_TRANSPORT_PLAN_STATUS]
    CHECK ([STATUS] IN ('DRAFT', 'ISSUED', 'CANCELLED'))
GO
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] WITH CHECK ADD CONSTRAINT [FK_DOC_TRANSPORT_PLAN_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
/* ZONE ยังไม่มี FK — ดูหมายเหตุ "ทำไมโซนถึงยังผูก FK ไม่ได้" ท้ายไฟล์นี้
   คอลัมน์ตั้งชื่อว่า ZONE ไม่ใช่ TRANSPORTZONEKEY เพื่อให้ตรงกับ
   DOC_SHIPMENT_HDR.ZONE / DOC_SHIPMENT_DETAIL.ZONE ที่แผนนี้ออกใบไปให้ */

CREATE TABLE [dbo].[DOC_TRANSPORT_PLAN_LINE](
    [SERIALKEY]  [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]     [nvarchar](30) NOT NULL,
    [PLANKEY]    [nvarchar](30) NOT NULL,
    [ORDERKEY]   [nvarchar](50) NOT NULL,   -- DOC_DO_HDR.ORDERKEY
    [STATUS]     [nvarchar](20) NOT NULL,
    [ADDDATE]    [datetime]      NOT NULL,
    [ADDWHO]     [nvarchar](100) NULL,
    [EDITDATE]   [datetime]      NULL,
    [EDITWHO]    [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_TRANSPORT_PLAN_LINE] PRIMARY KEY CLUSTERED
    ([WHSEID] ASC, [PLANKEY] ASC, [ORDERKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN_LINE] ADD CONSTRAINT [DF_DOC_TRANSPORT_PLAN_LINE_STATUS]  DEFAULT ('NEW')     FOR [STATUS]
GO
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN_LINE] ADD CONSTRAINT [DF_DOC_TRANSPORT_PLAN_LINE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN_LINE] WITH CHECK ADD CONSTRAINT [FK_DOC_TRANSPORT_PLAN_LINE_PLAN]
    FOREIGN KEY([WHSEID], [PLANKEY]) REFERENCES [dbo].[DOC_TRANSPORT_PLAN] ([WHSEID], [PLANKEY])
GO

/* ใบสั่งส่งเดียวกันอยู่ในสองแผนพร้อมกันไม่ได้ (แผนที่ยกเลิกแล้วไม่นับ) */
CREATE UNIQUE INDEX [UX_DOC_TRANSPORT_PLAN_LINE_ORDER]
    ON [dbo].[DOC_TRANSPORT_PLAN_LINE] ([ORDERKEY]) WHERE [STATUS] <> 'CANCELLED'
GO

/* -----------------------------------------------------------------------------
   6 · DOC_SHIPMENT_STATUS_LOG
   จอติดตามสถานะวาด timeline 5 ขั้น (สร้าง → ยืนยัน → ส่ง MMX → WMS ตรวจ QC →
   SAP/OMS ตอบกลับ) แต่ DOC_SHIPMENT_HDR มี STATUS ช่องเดียวกับ ADDDATE/EDITDATE
   จึงบอกได้แค่ "ตอนนี้อยู่ขั้นไหน" ไม่ใช่ "ถึงแต่ละขั้นเมื่อไหร่"
   และไม่มีที่เก็บข้อความที่ WMS/OMS ตีกลับมา ซึ่งเป็นข้อความที่ผู้ใช้ต้องอ่าน
   เพื่อรู้ว่าต้องแก้อะไร
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_SHIPMENT_STATUS_LOG](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NOT NULL,
    [SHIPMENTKEY]   [nvarchar](30)  NOT NULL,
    [FROMSTATUS]    [nvarchar](20)  NULL,
    [TOSTATUS]      [nvarchar](20)  NOT NULL,
    [SOURCESYSTEM]  [nvarchar](10)  NOT NULL,   -- TMS | OMS | MMX | WMS | SAP
    [MESSAGE]       [nvarchar](1000) NULL,      -- ข้อความที่ระบบปลายทางแจ้งกลับ
    [CHANGEDATE]    [datetime]      NOT NULL,
    [CHANGEWHO]     [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_SHIPMENT_STATUS_LOG] PRIMARY KEY CLUSTERED ([SERIALKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_SHIPMENT_STATUS_LOG] ADD CONSTRAINT [DF_SHIPMENT_STATUS_LOG_CHANGEDATE] DEFAULT (getdate()) FOR [CHANGEDATE]
GO

ALTER TABLE [dbo].[DOC_SHIPMENT_STATUS_LOG] WITH CHECK ADD CONSTRAINT [CK_SHIPMENT_STATUS_LOG_SOURCE]
    CHECK ([SOURCESYSTEM] IN ('TMS', 'OMS', 'MMX', 'WMS', 'SAP'))
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_STATUS_LOG] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_STATUS_LOG_HDR]
    FOREIGN KEY([WHSEID], [SHIPMENTKEY]) REFERENCES [dbo].[DOC_SHIPMENT_HDR] ([WHSEID], [SHIPMENTKEY])
GO

CREATE INDEX [IX_SHIPMENT_STATUS_LOG_SHIPMENT]
    ON [dbo].[DOC_SHIPMENT_STATUS_LOG] ([WHSEID], [SHIPMENTKEY], [CHANGEDATE] DESC)
GO

/* -----------------------------------------------------------------------------
   7 · MST_CUSTOMER — ทะเบียนลูกค้า/จุดส่งฉบับที่ใช้งานได้
   MST_SHIPTO มีอยู่แล้ว แต่ใช้เป็นตารางแม่ไม่ได้จริง:
     - PK เป็น SERIALKEY เดี่ยว ๆ · SHIPTO ไม่มี unique → FK ชี้มาไม่ได้
     - ที่อยู่เป็นแบบตะวันตก (city / state / zip / county) ไม่มี
       ตำบล/อำเภอ ที่ระบบไทยใช้แมปโซน
     - พิกัดเก็บเป็นข้อความก้อนเดียว gps1 nvarchar(200) คำนวณระยะทางไม่ได้
     - ชื่อคอลัมน์ addr##1..addr##4 มี ## และผูกกับ user-defined type
   ตารางนี้จึงเป็นตัวใหม่ที่ FK ชี้ได้ และให้ MST_SHIPTO อยู่ต่อในฐานะข้อมูล
   เดิมของ WMS จนกว่าจะย้ายเสร็จ (README หัวข้อ 3 มีสคริปต์ย้ายข้อมูล)
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_CUSTOMER](
    [SERIALKEY]           [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]              [nvarchar](30)  NULL,
    [OWNERKEY]            [nvarchar](15)  NULL,
    [CUSTOMERKEY]         [nvarchar](30)  NOT NULL,  -- ตรงกับ DOC_SHIPMENT_STOP.CUSTOMERKEY
    [SHIPTO]              [nvarchar](15)  NULL,      -- เลขเดิมใน MST_SHIPTO เพื่อสอบย้อน
    [CUSTOMERNAME]        [nvarchar](200) NOT NULL,
    [ADDRESS1]            [nvarchar](200) NULL,
    [ADDRESS2]            [nvarchar](200) NULL,
    [SUBDISTRICT]         [nvarchar](100) NULL,
    [DISTRICT]            [nvarchar](100) NULL,
    [PROVINCE]            [nvarchar](100) NULL,
    [POSTALCODE]          [nvarchar](10)  NULL,
    [COUNTRY]             [nvarchar](50)  NULL,
    /* decimal ไม่ใช่ข้อความ — และความละเอียดเท่ากับ DOC_SHIPMENT_STOP
       ที่ใช้ decimal(18,10) อยู่แล้ว เพื่อให้เทียบค่ากันได้ตรง */
    [LATITUDE]            [decimal](18, 10) NULL,
    [LONGITUDE]           [decimal](18, 10) NULL,
    /* โซนจัดส่ง — ชื่อคอลัมน์ตาม MST_SHIPTO.TRANSPORTZONEKEY ที่ R03 เพิ่มมา
       ไม่ได้ผูก FK ไป MST_TRANSPORTATIONZONE เพราะ PK ของตารางนั้นคือ
       (WHSEID, OWNERKEY, TRANSPORTZONEKEY) แต่ลูกค้าหนึ่งรายไม่จำเป็นต้อง
       ผูกกับคลังใดคลังหนึ่ง (WHSEID ที่นี่ NULL ได้) → บังคับที่ backend แทน
       ค่าได้มาจาก POSTALCODE ผ่าน MST_ZONE_COVERAGE */
    [TRANSPORTZONEKEY]    [nvarchar](20)  NULL,
    [ROUTE]               [nvarchar](20)  NULL,      -- สายส่งประจำ ถ้ามี
    [CONTACTNAME]         [nvarchar](100) NULL,
    [CONTACTPHONE]        [nvarchar](50)  NULL,
    [TIMEWINDOW_FROM]     [time](7)       NULL,      -- ชื่อเดียวกับ DOC_SHIPMENT_STOP
    [TIMEWINDOW_TO]       [time](7)       NULL,
    [SERVICE_MINUTE]      [int]           NULL,
    [COD_FLAG]            [bit]           NOT NULL,
    [STATUS]              [nvarchar](10)  NOT NULL,
    [NOTES]               [nvarchar](1000) NULL,
    [ADDDATE]             [datetime]      NOT NULL,
    [ADDWHO]              [nvarchar](100) NULL,
    [EDITDATE]            [datetime]      NULL,
    [EDITWHO]             [nvarchar](100) NULL,
    [SUSR1]               [nvarchar](100) NULL,
    [SUSR2]               [nvarchar](100) NULL,
    [SUSR3]               [nvarchar](100) NULL,
    [SUSR4]               [nvarchar](100) NULL,
    [SUSR5]               [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_CUSTOMER] PRIMARY KEY CLUSTERED ([CUSTOMERKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_CUSTOMER] ADD CONSTRAINT [DF_MST_CUSTOMER_COD]     DEFAULT ((0))       FOR [COD_FLAG]
GO
ALTER TABLE [dbo].[MST_CUSTOMER] ADD CONSTRAINT [DF_MST_CUSTOMER_STATUS]  DEFAULT ('ACTIVE')  FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_CUSTOMER] ADD CONSTRAINT [DF_MST_CUSTOMER_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[MST_CUSTOMER] WITH CHECK ADD CONSTRAINT [FK_MST_CUSTOMER_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO

/* พิกัดต้องมาเป็นคู่ ครึ่งเดียววาดแผนที่ไม่ได้และคำนวณระยะทางไม่ได้ */
ALTER TABLE [dbo].[MST_CUSTOMER] WITH CHECK ADD CONSTRAINT [CK_MST_CUSTOMER_LATLNG]
    CHECK (([LATITUDE] IS NULL AND [LONGITUDE] IS NULL)
        OR ([LATITUDE] IS NOT NULL AND [LONGITUDE] IS NOT NULL))
GO
ALTER TABLE [dbo].[MST_CUSTOMER] WITH CHECK ADD CONSTRAINT [CK_MST_CUSTOMER_WINDOW]
    CHECK ([TIMEWINDOW_FROM] IS NULL OR [TIMEWINDOW_TO] IS NULL
        OR [TIMEWINDOW_FROM] < [TIMEWINDOW_TO])
GO

CREATE INDEX [IX_MST_CUSTOMER_ZONE] ON [dbo].[MST_CUSTOMER] ([TRANSPORTZONEKEY]) WHERE [STATUS] = 'ACTIVE'
GO

/* -----------------------------------------------------------------------------
   8 · DOC_DO_PICKHEADER — หัวใบจัดสินค้า
   `DOC_DO_PICKDETAIL.PICKHEADERKEY nvarchar(18)` อ้างถึงตารางที่ **ไม่มีอยู่ใน
   ฐานเลย** ผลคือรายการเบิกลอยอยู่โดยไม่มีหัวเอกสาร: ตอบไม่ได้ว่าใบจัดสินค้า
   ใบหนึ่งมีสถานะอะไร ใครถือ พิมพ์แล้วหรือยัง ปิดเมื่อไหร่ — จอ "ใบคุมเบิกสินค้า"
   และเลข PKL ที่พิมพ์คู่กับ DO ทุกใบต้องอ่านจากที่นี่

   ⚠ รูปร่างตารางนี้อนุมานจากคอลัมน์ใน DOC_DO_PICKDETAIL (PICKHEADERKEY,
     WAVEKEY, PICKMETHOD, ISCLOSED, QCSTATUS, ASSIGNMENTNUMBER) — ต้องให้ทีมที่
     ดูแล WMS ยืนยันก่อนใช้ เพราะอาจมีนิยามเดิมอยู่ในระบบอื่น
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_DO_PICKHEADER](
    [SERIALKEY]           [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]              [nvarchar](30) NOT NULL,
    [PICKHEADERKEY]       [nvarchar](18) NOT NULL,
    [ORDERKEY]            [nvarchar](50) NULL,   -- NULL ได้เพราะ wave รวมหลายใบ
    [WAVEKEY]             [nvarchar](10) NULL,
    [PICKMETHOD]          [nvarchar](1)  NULL,
    [ALLOCATESTRATEGYKEY] [nvarchar](10) NULL,
    [PICKDATE]            [datetime]     NULL,
    [ASSIGNMENTNUMBER]    [nvarchar](10) NULL,
    [ASSIGNEDTO]          [nvarchar](100) NULL,
    [LABELPRINTED]        [nvarchar](10) NULL,
    [ISCLOSED]            [nvarchar](1)  NOT NULL,
    [QCSTATUS]            [nvarchar](10) NULL,
    [TOTALLINES]          [int]            NULL,
    [TOTALQTY]            [decimal](22, 5) NULL,
    [STATUS]              [nvarchar](10) NOT NULL,
    [NOTES]               [nvarchar](1000) NULL,
    [ADDDATE]             [datetime]     NOT NULL,
    [ADDWHO]              [nvarchar](100) NULL,
    [EDITDATE]            [datetime]     NULL,
    [EDITWHO]             [nvarchar](100) NULL,
    [SUSR1]               [nvarchar](100) NULL,
    [SUSR2]               [nvarchar](100) NULL,
    [SUSR3]               [nvarchar](100) NULL,
    [SUSR4]               [nvarchar](100) NULL,
    [SUSR5]               [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_DO_PICKHEADER] PRIMARY KEY CLUSTERED
    ([WHSEID] ASC, [PICKHEADERKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_DO_PICKHEADER] ADD CONSTRAINT [DF_DO_PICKHEADER_ISCLOSED] DEFAULT ('N')      FOR [ISCLOSED]
GO
ALTER TABLE [dbo].[DOC_DO_PICKHEADER] ADD CONSTRAINT [DF_DO_PICKHEADER_STATUS]   DEFAULT ('NEW')    FOR [STATUS]
GO
ALTER TABLE [dbo].[DOC_DO_PICKHEADER] ADD CONSTRAINT [DF_DO_PICKHEADER_ADDDATE]  DEFAULT (getdate()) FOR [ADDDATE]
GO

/* -----------------------------------------------------------------------------
   9 · MST_USER / MST_USER_MODULE
   ฐานไม่มีตารางผู้ใช้เลย แต่แอปมี login, role 4 ระดับ และจำกัดสิทธิ์ *ตามโมดูล*
   (บัญชี tms@ เห็นแค่ /logistics) ซึ่งเป็นสองแกนแยกกัน: role บอกว่าทำได้มาก
   แค่ไหน, module บอกว่าทำที่ไหนได้ — ไม่มีแถวใน MST_USER_MODULE = เข้าได้ทุกโมดูล
   ค่า ROLECODE และ MODULEPATH ลอกจาก USER_ROLES และ modules ใน src/constants
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_USER](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    [USERKEY]      [nvarchar](30)  NOT NULL,
    [USERNAME]     [nvarchar](64)  NOT NULL,
    [EMAIL]        [nvarchar](150) NOT NULL,
    [DISPLAYNAME]  [nvarchar](150) NOT NULL,
    [PASSWORDHASH] [nvarchar](256) NOT NULL,
    [ROLECODE]     [nvarchar](20)  NOT NULL,
    [DEFAULT_WHSEID] [nvarchar](30) NULL,
    [LASTLOGINDATE] [datetime]     NULL,
    [STATUS]       [nvarchar](10)  NOT NULL,
    [ADDDATE]      [datetime]      NOT NULL,
    [ADDWHO]       [nvarchar](100) NULL,
    [EDITDATE]     [datetime]      NULL,
    [EDITWHO]      [nvarchar](100) NULL,
    [SUSR1]        [nvarchar](100) NULL,
    [SUSR2]        [nvarchar](100) NULL,
    [SUSR3]        [nvarchar](100) NULL,
    [SUSR4]        [nvarchar](100) NULL,
    [SUSR5]        [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_USER] PRIMARY KEY CLUSTERED ([USERKEY] ASC) ON [PRIMARY],
 CONSTRAINT [UQ_MST_USER_USERNAME] UNIQUE ([USERNAME]),
 CONSTRAINT [UQ_MST_USER_EMAIL]    UNIQUE ([EMAIL])
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_USER] ADD CONSTRAINT [DF_MST_USER_STATUS]  DEFAULT ('ACTIVE')  FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_USER] ADD CONSTRAINT [DF_MST_USER_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO
ALTER TABLE [dbo].[MST_USER] WITH CHECK ADD CONSTRAINT [CK_MST_USER_ROLE]
    CHECK ([ROLECODE] IN ('ADMIN', 'MANAGER', 'OPERATOR', 'VIEWER'))
GO

CREATE TABLE [dbo].[MST_USER_MODULE](
    [SERIALKEY]  [int] IDENTITY(1,1) NOT NULL,
    [USERKEY]    [nvarchar](30) NOT NULL,
    [MODULEPATH] [nvarchar](50) NOT NULL,   -- /logistics · /inbound · /warehouse …
    [ADDDATE]    [datetime]      NOT NULL,
    [ADDWHO]     [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_USER_MODULE] PRIMARY KEY CLUSTERED ([USERKEY] ASC, [MODULEPATH] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_USER_MODULE] ADD CONSTRAINT [DF_MST_USER_MODULE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO
ALTER TABLE [dbo].[MST_USER_MODULE] WITH CHECK ADD CONSTRAINT [FK_MST_USER_MODULE_USER]
    FOREIGN KEY([USERKEY]) REFERENCES [dbo].[MST_USER] ([USERKEY]) ON DELETE CASCADE
GO

/* -----------------------------------------------------------------------------
   10 · DOC_SO_HDR / DOC_SO_DETAIL — ใบสั่งขาย แยกออกจากใบสั่งส่ง

   ฐานเดิม **ไม่มีตาราง SO เลย** มีแต่ `DOC_DO_HDR.EXTERNORDERKEY nvarchar(55)`
   ซึ่งเป็นข้อความลอย ๆ ที่เก็บเลข SO เอาไว้ ผลคือ:

     - ตอบไม่ได้ว่า SO ใบหนึ่งสั่งอะไรมาบ้าง ใครสั่ง มูลค่าเท่าไหร่ ปิดหรือยัง
     - ตอบไม่ได้ว่า SO ใบหนึ่งถูกแตกเป็น DO กี่ใบ และครบตามที่สั่งหรือยัง
     - จอที่แสดงทั้ง `soNo` และ `doNo` คู่กัน (StopChecklist, PlanContentsDialog)
       อ่าน SO จากคอลัมน์ข้อความบน DO ไม่ใช่จากใบ SO จริง

   ความสัมพันธ์คือ **SO หนึ่งใบ → DO ได้หลายใบ** ไม่ใช่ 1:1 — ของสั่งครั้งเดียว
   แต่ทยอยส่งหลายรอบเป็นเรื่องปกติ (ของไม่พอ ลูกค้าขอแบ่งส่ง หรือคนละคลัง)
   ทิศทาง FK จึงเป็น DO ชี้ขึ้นไปหา SO ไม่ใช่ทางกลับ

   ⚠ ไดอะแกรม ER เรียกตาราง `DOC_SO_HDR` แต่หมายถึงตารางที่ฐานจริงชื่อ
     `DOC_DO_HDR` (README หัวข้อ 1) — **ตารางที่สร้างตรงนี้ไม่ใช่ตัวเดียวกับใน
     ไดอะแกรม** เป็นชั้น SO ของจริงที่ยังไม่เคยมี ชื่อพ้องกันโดยบังเอิญ
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_SO_HDR](
    [SERIALKEY]         [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]            [nvarchar](30)  NOT NULL,
    /* ยาว 55 ให้เท่ากับ DOC_DO_HDR.EXTERNORDERKEY เป๊ะ ๆ เพราะ FK บังคับให้สอง
       ฝั่งชนิดและความยาวตรงกัน (README หัวข้อ 2.10) — ตั้งสั้นกว่านี้แล้ว
       ผูก DO กลับมาหา SO ไม่ได้เลย */
    [SOKEY]             [nvarchar](55)  NOT NULL,   -- SO-9910231
    [OWNERKEY]          [nvarchar](15)  NOT NULL,
    [CUSTOMERKEY]       [nvarchar](30)  NULL,
    [SHIPTO]            [nvarchar](15)  NULL,       -- เลขเดิมฝั่ง WMS เพื่อสอบย้อน
    [ORDERDATE]         [datetime]      NOT NULL,   -- วันที่ลูกค้าสั่ง
    [REQUESTEDDATE]     [date]          NULL,       -- วันที่ลูกค้าอยากได้ของ
    [SOURCESYSTEM]      [nvarchar](10)  NOT NULL,   -- OMS · SAP · MANUAL
    [SOURCEREFERENCE]   [nvarchar](55)  NULL,       -- เลขในระบบต้นทาง ถ้าไม่ใช่เลขเดียวกัน
    [CURRENCY]          [nvarchar](3)   NULL,
    [TOTALAMOUNT]       [decimal](22, 5) NULL,
    [TOTALLINE]         [int]            NULL,
    /* NEW = รับเข้ามาแล้วยังไม่ออก DO · PARTIAL = ออก DO แล้วบางส่วน
       CLOSED = ออกครบตามจำนวนที่สั่ง · CANCELLED = ยกเลิกทั้งใบ
       ยังไม่ใส่ CHECK เพราะค่าที่ระบบต้นทางส่งมาจริงต้องยืนยันก่อน (README หัวข้อ 5) */
    [STATUS]            [nvarchar](10)  NOT NULL,
    [NOTES]             [nvarchar](1000) NULL,
    [ADDDATE]           [datetime]      NOT NULL,
    [ADDWHO]            [nvarchar](100) NULL,
    [EDITDATE]          [datetime]      NULL,
    [EDITWHO]           [nvarchar](100) NULL,
    [SUSR1]             [nvarchar](100) NULL,
    [SUSR2]             [nvarchar](100) NULL,
    [SUSR3]             [nvarchar](100) NULL,
    [SUSR4]             [nvarchar](100) NULL,
    [SUSR5]             [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_SO_HDR] PRIMARY KEY CLUSTERED ([WHSEID] ASC, [SOKEY] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_SO_HDR] ADD CONSTRAINT [DF_DOC_SO_HDR_STATUS]   DEFAULT ('NEW')     FOR [STATUS]
GO
ALTER TABLE [dbo].[DOC_SO_HDR] ADD CONSTRAINT [DF_DOC_SO_HDR_SOURCE]   DEFAULT ('OMS')     FOR [SOURCESYSTEM]
GO
ALTER TABLE [dbo].[DOC_SO_HDR] ADD CONSTRAINT [DF_DOC_SO_HDR_ADDDATE]  DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[DOC_SO_HDR] WITH CHECK ADD CONSTRAINT [FK_DOC_SO_HDR_CUSTOMER]
    FOREIGN KEY([CUSTOMERKEY]) REFERENCES [dbo].[MST_CUSTOMER] ([CUSTOMERKEY])
GO

/* เลข SO ต้องไม่ซ้ำข้ามคลังด้วย — มันมาจากระบบต้นทางระบบเดียว ถ้าซ้ำได้
   `DOC_DO_HDR.EXTERNORDERKEY` จะชี้ไปได้สองใบและตอบไม่ได้ว่าใบไหน */
CREATE UNIQUE INDEX [UX_DOC_SO_HDR_SOKEY] ON [dbo].[DOC_SO_HDR] ([SOKEY])
GO
CREATE INDEX [IX_DOC_SO_HDR_CUSTOMER_DATE]
    ON [dbo].[DOC_SO_HDR] ([CUSTOMERKEY], [ORDERDATE] DESC)
GO

CREATE TABLE [dbo].[DOC_SO_DETAIL](
    [SERIALKEY]       [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]          [nvarchar](30)  NOT NULL,
    [SOKEY]           [nvarchar](55)  NOT NULL,
    [SOLINENUMBER]    [nvarchar](5)   NOT NULL,   -- รูปแบบเดียวกับ DOC_DO_DETAIL.ORDERLINENUMBER
    [OWNERKEY]        [nvarchar](15)  NOT NULL,
    [SKU]             [nvarchar](50)  NOT NULL,
    [UOM]             [nvarchar](10)  NULL,
    /* ORDERQTY คือที่ลูกค้าสั่ง · SHIPPEDQTY คือที่ออก DO ไปแล้วรวมทุกใบ
       ผลต่างคือของที่ยังค้างส่ง ซึ่งเป็นตัวเลขที่ทั้งระบบยังตอบไม่ได้ตอนนี้ */
    [ORDERQTY]        [decimal](22, 5) NOT NULL,
    [SHIPPEDQTY]      [decimal](22, 5) NOT NULL,
    [UNITPRICE]       [decimal](22, 5) NULL,
    [EXTENDEDPRICE]   [decimal](22, 5) NULL,
    [STATUS]          [nvarchar](10)  NOT NULL,
    [ADDDATE]         [datetime]      NOT NULL,
    [ADDWHO]          [nvarchar](100) NULL,
    [EDITDATE]        [datetime]      NULL,
    [EDITWHO]         [nvarchar](100) NULL,
 CONSTRAINT [PK_DOC_SO_DETAIL] PRIMARY KEY CLUSTERED
    ([WHSEID] ASC, [SOKEY] ASC, [SOLINENUMBER] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[DOC_SO_DETAIL] ADD CONSTRAINT [DF_DOC_SO_DETAIL_SHIPPED] DEFAULT ((0))       FOR [SHIPPEDQTY]
GO
ALTER TABLE [dbo].[DOC_SO_DETAIL] ADD CONSTRAINT [DF_DOC_SO_DETAIL_STATUS]  DEFAULT ('NEW')     FOR [STATUS]
GO
ALTER TABLE [dbo].[DOC_SO_DETAIL] ADD CONSTRAINT [DF_DOC_SO_DETAIL_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[DOC_SO_DETAIL] WITH CHECK ADD CONSTRAINT [FK_DOC_SO_DETAIL_HDR]
    FOREIGN KEY([WHSEID], [SOKEY]) REFERENCES [dbo].[DOC_SO_HDR] ([WHSEID], [SOKEY])
GO

/* FK ไป MST_SKU อยู่ในไฟล์ 02 ส่วน D ไม่ใช่ตรงนี้ — `MST_SKU` เป็นตารางเดิมที่
   ยังไม่มี PK จนกว่าส่วน A ของไฟล์นั้นจะใส่ให้ ถ้าประกาศตรงนี้จะได้ Msg 1776
   "There are no primary or candidate keys in the referenced table" */

/* ส่งเกินที่สั่งไม่ได้ — ถ้าจะอนุญาตต้องเป็นการตัดสินใจที่เขียนไว้ ไม่ใช่ผลข้างเคียง
   ของการไม่มี constraint (`MST_VENDOR.OVERRECEIPT_PERCENT` มีแนวคิดนี้ฝั่งขาเข้าอยู่แล้ว) */
ALTER TABLE [dbo].[DOC_SO_DETAIL] WITH CHECK ADD CONSTRAINT [CK_DOC_SO_DETAIL_QTY]
    CHECK ([ORDERQTY] >= (0) AND [SHIPPEDQTY] >= (0) AND [SHIPPEDQTY] <= [ORDERQTY])
GO

/* =============================================================================
   หมายเหตุ · ทำไมคอลัมน์ ZONE ในตารางเอกสารถึงยังผูก FK ไม่ได้

   `MST_TRANSPORTATIONZONE` มี PK เป็นสามคอลัมน์ (WHSEID, OWNERKEY,
   TRANSPORTZONEKEY) แต่ตารางเอกสารที่อ้างโซน — `DOC_SHIPMENT_HDR.ZONE`,
   `DOC_SHIPMENT_DETAIL.ZONE`, `MST_TRANSPORT_RATE.ZONE`,
   `MST_TRANSPORTER_ROUTE.ZONE`, `DOC_TRANSPORT_PLAN.ZONE` — มีแค่คอลัมน์เดียว
   FK ต้องมีคอลัมน์ครบตาม PK ปลายทาง จึงผูกไม่ได้ตามที่เป็นอยู่

   ทางแก้มีสองทาง เลือกได้ทางเดียว และต้องให้ทีมที่ดูแลฐานตัดสิน

   ทาง 1 · รหัสโซนเป็น global (แนะนำถ้าข้อมูลจริงเป็นแบบนั้น)
   ถ้า TRANSPORTZONEKEY ไม่เคยซ้ำข้ามคลัง/ข้ามเจ้าของ ก็เพิ่ม unique index
   แล้ว FK คอลัมน์เดียวจะผูกได้ทั้งหมด ตรวจก่อนด้วย query นี้ ต้องได้ 0 แถว:

     SELECT TRANSPORTZONEKEY, COUNT(*) AS n
     FROM   dbo.MST_TRANSPORTATIONZONE
     GROUP  BY TRANSPORTZONEKEY
     HAVING COUNT(*) > 1;

   ได้ 0 แถวแล้วค่อยรัน:

     CREATE UNIQUE INDEX [UX_MST_TRANSPORTATIONZONE_KEY]
         ON [dbo].[MST_TRANSPORTATIONZONE] ([TRANSPORTZONEKEY]);

     ALTER TABLE [dbo].[DOC_SHIPMENT_HDR]    WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_ZONE]
         FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([TRANSPORTZONEKEY]);
     ALTER TABLE [dbo].[DOC_SHIPMENT_DETAIL] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_DETAIL_ZONE]
         FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([TRANSPORTZONEKEY]);
     ALTER TABLE [dbo].[MST_TRANSPORT_RATE]  WITH CHECK ADD CONSTRAINT [FK_TRANSPORT_RATE_ZONE]
         FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([TRANSPORTZONEKEY]);
     ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN]  WITH CHECK ADD CONSTRAINT [FK_DOC_TRANSPORT_PLAN_ZONE]
         FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_TRANSPORTATIONZONE] ([TRANSPORTZONEKEY]);

   ทาง 2 · รหัสโซนซ้ำข้ามคลังได้
   ต้องเพิ่ม OWNERKEY ลงในตารางเอกสารที่ยังไม่มี แล้วผูก FK สามคอลัมน์ —
   แตะโครงสร้างเยอะกว่ามาก และต้อง backfill ค่าเดิม ควรทำก็ต่อเมื่อ query
   ข้างบนคืนแถวออกมาจริง ๆ เท่านั้น

   จนกว่าจะเลือกได้ **backend ต้องตรวจเองว่าโซนที่รับเข้ามามีอยู่จริง** —
   ไม่มี constraint ไหนกันให้อยู่ตอนนี้
============================================================================= */
