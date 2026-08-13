/* =============================================================================
   MamMoD (MMPRD) — ตารางที่ยังไม่มีในฐานจริง
   SQL Server · รันไฟล์นี้ก่อน 02-alter-existing.sql

   ปรับใหม่ทั้งไฟล์ให้ตรงกับ MAMMOD_TABLE2_R02.sql แล้ว ไม่ใช่ตามไดอะแกรม ER
   ซึ่งคลาดเคลื่อนจากฐานหลายจุด (ดู README.md หัวข้อ 1)

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
   2 · MST_DELIVERY_ZONE — พื้นที่จัดส่งของ TMS
   คนละเรื่องกับ MST_ZONE ที่มีอยู่ ซึ่งเป็นโซนใน *คลัง* (PK = WHSEID +
   PUTAWAYZONE, ผูก AREACODE, มี PUTAWAYSEQ/PICKSEQ) ชื่อ ZONE ในตารางขนส่ง
   หมายถึงพื้นที่ส่งของ ไม่เกี่ยวกับ aisle/bay เลย
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_DELIVERY_ZONE](
    [SERIALKEY]         [int] IDENTITY(1,1) NOT NULL,
    [ZONE]              [nvarchar](20)  NOT NULL,  -- ตรงกับคอลัมน์ ZONE ที่ตารางอื่นอ้าง
    [ZONENAME]          [nvarchar](200) NOT NULL,
    [DESCRIPTION]       [nvarchar](250) NULL,
    /* น้ำหนักรถสูงสุดที่เข้าพื้นที่ได้ — สะพานรับน้ำหนัก ซอยแคบ เขตห้ามรถบรรทุก
       เป็นข้อจำกัดของ *พื้นที่* ต่อ *รถ* ไม่ใช่ความจุของโซน ให้ใช้ตอนเลือกรถ
       ต้องยืนยันความหมายก่อนใช้งานจริง (README หัวข้อ 5) */
    [MAX_VEHICLE_WEIGHT] [decimal](22, 5) NULL,
    [WEIGHT_UOM]        [nvarchar](10)  NULL,
    [SERVICE_MINUTE]    [int]           NULL,     -- เวลาให้บริการมาตรฐานต่อจุดในโซนนี้
    [STATUS]            [nvarchar](10)  NOT NULL,
    [NOTES]             [nvarchar](500) NULL,
    [ADDDATE]           [datetime]      NOT NULL,
    [ADDWHO]            [nvarchar](100) NULL,
    [EDITDATE]          [datetime]      NULL,
    [EDITWHO]           [nvarchar](100) NULL,
    [SUSR1]             [nvarchar](100) NULL,
    [SUSR2]             [nvarchar](100) NULL,
    [SUSR3]             [nvarchar](100) NULL,
    [SUSR4]             [nvarchar](100) NULL,
    [SUSR5]             [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_DELIVERY_ZONE] PRIMARY KEY CLUSTERED ([ZONE] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_DELIVERY_ZONE] ADD CONSTRAINT [DF_MST_DELIVERY_ZONE_STATUS]  DEFAULT ('ACTIVE') FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_DELIVERY_ZONE] ADD CONSTRAINT [DF_MST_DELIVERY_ZONE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

/* -----------------------------------------------------------------------------
   3 · MST_ZONE_COVERAGE — พื้นที่ที่โซนหนึ่งครอบคลุม
   ทำให้จัดโซนให้ใบสั่งส่งที่ไหลเข้ามาได้เอง โดยแมปจากที่อยู่ปลายทาง
   MST_SHIPTO เก็บที่อยู่แบบตะวันตก (city/state/zip) ส่วน DOC_SHIPMENT_STOP
   เก็บแบบไทย (SUBDISTRICT/DISTRICT/PROVINCE/POSTALCODE) — POSTALCODE คือ
   ตัวที่แมปได้แน่นอนที่สุด จึงเป็นคอลัมน์ที่ควรใช้เป็นกุญแจหลัก
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ZONE_COVERAGE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    [ZONE]         [nvarchar](20)  NOT NULL,
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
    FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_DELIVERY_ZONE] ([ZONE])
GO

/* ที่อยู่หนึ่งต้องตกอยู่ในโซนเดียว ไม่ใช่สองโซน — ไม่งั้นการจัดโซนอัตโนมัติ
   ต้องเดา ดัชนีนี้กันไว้ตั้งแต่ระดับฐาน */
CREATE UNIQUE INDEX [UX_MST_ZONE_COVERAGE_AREA]
    ON [dbo].[MST_ZONE_COVERAGE] ([PROVINCE], [DISTRICT], [SUBDISTRICT], [POSTALCODE])
GO
CREATE INDEX [IX_MST_ZONE_COVERAGE_POSTALCODE]
    ON [dbo].[MST_ZONE_COVERAGE] ([POSTALCODE]) INCLUDE ([ZONE])
GO

/* -----------------------------------------------------------------------------
   4 · MST_ROUTE_ZONE — สายส่ง ↔ โซน พร้อมลำดับการวิ่ง
   MST_TRANSPORTER_ROUTE ที่มีอยู่ตอบว่า "ผู้ให้บริการรายไหนวิ่งสายไหน"
   แต่ไม่มีที่ไหนตอบว่า "สายส่งหนึ่งครอบคลุมโซนอะไร ลำดับไหน"
   (และ PK ของตารางนั้นเป็น TRANSPORTERKEY+ROUTE ทำให้แตกเป็นรายโซนไม่ได้)
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ROUTE_ZONE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    [ROUTE]        [nvarchar](20) NOT NULL,
    [ZONE]         [nvarchar](20) NOT NULL,
    [SEQUENCE]     [int]          NOT NULL,
    [DEFAULT_FLAG] [bit]          NOT NULL,
    [STATUS]       [nvarchar](10) NOT NULL,
    [ADDDATE]      [datetime]      NOT NULL,
    [ADDWHO]       [nvarchar](100) NULL,
    [EDITDATE]     [datetime]      NULL,
    [EDITWHO]      [nvarchar](100) NULL,
 CONSTRAINT [PK_MST_ROUTE_ZONE] PRIMARY KEY CLUSTERED ([ROUTE] ASC, [ZONE] ASC) ON [PRIMARY]
) ON [PRIMARY]
GO

ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_SEQ]     DEFAULT ((1))      FOR [SEQUENCE]
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_DEFAULT] DEFAULT ((0))      FOR [DEFAULT_FLAG]
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_STATUS]  DEFAULT ('ACTIVE') FOR [STATUS]
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] ADD CONSTRAINT [DF_MST_ROUTE_ZONE_ADDDATE] DEFAULT (getdate()) FOR [ADDDATE]
GO

ALTER TABLE [dbo].[MST_ROUTE_ZONE] WITH CHECK ADD CONSTRAINT [FK_MST_ROUTE_ZONE_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
ALTER TABLE [dbo].[MST_ROUTE_ZONE] WITH CHECK ADD CONSTRAINT [FK_MST_ROUTE_ZONE_ZONE]
    FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_DELIVERY_ZONE] ([ZONE])
GO

/* หนึ่งโซนมีสายหลักได้สายเดียว — ใช้เสนอสายส่งให้อัตโนมัติตอนสร้างเอกสาร */
CREATE UNIQUE INDEX [UX_MST_ROUTE_ZONE_DEFAULT]
    ON [dbo].[MST_ROUTE_ZONE] ([ZONE]) WHERE [DEFAULT_FLAG] = 1
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
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN] WITH CHECK ADD CONSTRAINT [FK_DOC_TRANSPORT_PLAN_ZONE]
    FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_DELIVERY_ZONE] ([ZONE])
GO

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
    [ZONE]                [nvarchar](20)  NULL,      -- ได้จาก POSTALCODE ผ่าน MST_ZONE_COVERAGE
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

ALTER TABLE [dbo].[MST_CUSTOMER] WITH CHECK ADD CONSTRAINT [FK_MST_CUSTOMER_ZONE]
    FOREIGN KEY([ZONE]) REFERENCES [dbo].[MST_DELIVERY_ZONE] ([ZONE])
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

CREATE INDEX [IX_MST_CUSTOMER_ZONE] ON [dbo].[MST_CUSTOMER] ([ZONE]) WHERE [STATUS] = 'ACTIVE'
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
