/* =============================================================================
   MamMoD (MMPRD) — แก้ตารางเดิมให้ครบและสอดคล้อง
   รันหลัง 01-new-tables.sql

   ปรับใหม่ตาม MAMMOD_TABLE2_R02.sql ทั้งไฟล์ ชื่อตาราง/คอลัมน์ในนี้คือชื่อจริง
   ไม่ใช่ชื่อจากไดอะแกรม ER (ฐานใช้ DOC_DO_HDR ไม่ใช่ DOC_SO_HDR,
   DOC_RCPT_HDR ไม่ใช่ DOC_RECEIPT_HDR, MST_TRANSPORTER_DOCUMENT ไม่ใช่
   MST_TRANSPORT_DOCUMENT ฯลฯ)

   ส่วน A · PRIMARY KEY ที่หายไป  ← เร่งด่วนสุด
   ส่วน B · เงินที่เก็บเป็น float
   ส่วน C · คอลัมน์ที่จอที่มีอยู่ต้องใช้แต่ตารางไม่มี
   ส่วน D · FK ที่ยังไม่ผูก
   ส่วน E · กฎ "ของอยู่ได้ที่เดียว" + ดัชนี
   ส่วน F · ROWVERSION
   ส่วน G · เก็บกวาด constraint ซ้ำและค่า sentinel

   ⚠ ทุกส่วนต้องรันบน dev ที่มีสำเนาข้อมูลจริงก่อน — ส่วน A กับ B แตะข้อมูล
     ที่มีอยู่ และจะล้มถ้าข้อมูลเดิมละเมิดกฎ ซึ่งเป็นเจตนา: ให้เห็นตอนนี้
     ดีกว่าให้ระบบเชื่อสิ่งที่ไม่จริง
============================================================================= */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* =============================================================================
   A · ตารางที่ไม่มี PRIMARY KEY เลย

   ตารางเหล่านี้มีแค่ SERIALKEY IDENTITY โดยไม่มี PK/unique constraint —
   แถวซ้ำเข้าไปได้ทั้งแถว, FK ชี้มาไม่ได้, และ EF Core map เป็น entity
   ที่แก้ไขได้ไม่ได้ (ต้องประกาศเป็น keyless) นี่คือปัญหาที่ต้องแก้ก่อนอย่างอื่น

   ขั้นตอนของแต่ละตาราง: หาแถวซ้ำ → แก้ข้อมูล → ค่อยใส่ PK
   ตัวอย่าง query หาแถวซ้ำก่อนใส่ PK ให้ TRX_LOTXLOCXID:

     SELECT WHSEID, OWNERKEY, SKU, LOT, LOC, HUID, COUNT(*)
     FROM   dbo.TRX_LOTXLOCXID
     GROUP  BY WHSEID, OWNERKEY, SKU, LOT, LOC, HUID
     HAVING COUNT(*) > 1;
============================================================================= */

/* -----------------------------------------------------------------------------
   A.0 · WHSEID ต้อง NOT NULL ก่อน ไม่งั้นใส่ PK ไม่ได้เลยสักตาราง

   ทุก PK ข้างล่างขึ้นต้นด้วย WHSEID แต่ฐานประกาศ `[WHSEID] nvarchar(30) NULL`
   ไว้ทุกตาราง → SQL Server ตอบ **Msg 8111 "Cannot define PRIMARY KEY constraint
   on nullable column"** และล้มทั้ง 14 ตารางรวด (ยืนยันแล้วด้วยการรันจริงบน
   SQL Server 2025 Express กับฐานที่สร้างจาก R03) จึงต้องบังคับชนิดก่อน

   ⚠ บนฐานที่มีข้อมูลจริง ALTER พวกนี้ **จะล้มถ้ามีแถวไหน WHSEID เป็น NULL**
     ซึ่งเป็นเจตนา — ต้องรู้ว่าแถวพวกนั้นเป็นของคลังไหนก่อน ไม่ใช่เดาแล้วเติม
     ตรวจก่อนด้วย query นี้ ต้องได้ 0 ทุกตาราง:

       SELECT 'TRX_LOTXLOCXID'   AS t, COUNT(*) FROM dbo.TRX_LOTXLOCXID   WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_SKUXLOC',       COUNT(*) FROM dbo.TRX_SKUXLOC       WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_ITRN',          COUNT(*) FROM dbo.TRX_ITRN          WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_TAGID',         COUNT(*) FROM dbo.TRX_TAGID         WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_DROPID',        COUNT(*) FROM dbo.TRX_DROPID        WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_DROPIDDETAIL',  COUNT(*) FROM dbo.TRX_DROPIDDETAIL  WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_LOTATTRIBUTE',  COUNT(*) FROM dbo.TRX_LOTATTRIBUTE  WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_LOTXIDDETAIL',  COUNT(*) FROM dbo.TRX_LOTXIDDETAIL  WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_INVENTORYHOLD', COUNT(*) FROM dbo.TRX_INVENTORYHOLD WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_INVENTORYHOLDCODE', COUNT(*) FROM dbo.TRX_INVENTORYHOLDCODE WHERE WHSEID IS NULL
       UNION ALL SELECT 'TRX_TODODETAIL',   COUNT(*) FROM dbo.TRX_TODODETAIL   WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_DO_DETAIL',    COUNT(*) FROM dbo.DOC_DO_DETAIL    WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_DO_PICKDETAIL',COUNT(*) FROM dbo.DOC_DO_PICKDETAIL WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_PO',           COUNT(*) FROM dbo.DOC_PO           WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_PODETAIL',     COUNT(*) FROM dbo.DOC_PODETAIL     WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_RCPT_HDR',     COUNT(*) FROM dbo.DOC_RCPT_HDR     WHERE WHSEID IS NULL
       UNION ALL SELECT 'DOC_RCPT_TDETAIL', COUNT(*) FROM dbo.DOC_RCPT_TDETAIL WHERE WHSEID IS NULL;
----------------------------------------------------------------------------- */
ALTER TABLE [dbo].[TRX_LOTXLOCXID]        ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_SKUXLOC]           ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_ITRN]              ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_TAGID]             ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_DROPID]            ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_DROPIDDETAIL]      ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_LOTATTRIBUTE]      ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_LOTXIDDETAIL]      ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_INVENTORYHOLD]     ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_INVENTORYHOLDCODE] ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_TODODETAIL]        ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_DETAIL]         ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_PICKDETAIL]     ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_PO]                ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_PODETAIL]          ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_RCPT_HDR]          ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[DOC_RCPT_TDETAIL]      ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
GO

/* -----------------------------------------------------------------------------
   A.1 · คอลัมน์เดียวกันคนละความยาว — ต้องปรับก่อน ไม่งั้น FK ผูกไม่ได้

   FK บังคับให้คอลัมน์สองฝั่ง **ความยาวเท่ากันเป๊ะ** (Msg 1753) และของจริง
   ไม่เท่า ซึ่งไม่ใช่แค่เรื่องผูก FK — มันแปลว่าข้อมูลหายจริงตอนไหลข้ามตาราง

   ROUTE  · MST_ROUTE / DOC_SHIPMENT_HDR / DOC_SHIPMENT_DETAIL /
           MST_TRANSPORT_RATE / MST_TRANSPORTER_ROUTE = nvarchar(20)
           แต่ DOC_DO_HDR = nvarchar(10) · DOC_DO_PICKDETAIL = nvarchar(18)
           → รหัสสายส่งยาวเกิน 10 ตัวอยู่บนใบปิดบรรทุกได้ แต่เขียนกลับลง
             ใบสั่งส่งต้นทางไม่ได้ (TRX_TODODETAIL.ROUTE ก็ 10 เหมือนกัน
             แต่ยังไม่แตะเพราะเป็นคิวงานฝั่งคลัง ไม่ได้ผูก FK ในไฟล์นี้)

   LOC    · MST_LOCATION.LOC = nvarchar(30)
           แต่ TRX_LOTXLOCXID.LOC / TRX_SKUXLOC.LOC = nvarchar(10)
           → ตั้งรหัสตำแหน่งยาว 30 ในตาราง master ได้ แล้วบันทึกของเข้าไป
             ในตำแหน่งนั้นไม่ได้ · TRX_ITRN.FROMLOC/TOLOC ก็ 10 เช่นกัน

   ทิศทางที่เลือกคือ **ขยายให้เท่าตัวที่กว้างสุด** ไม่ใช่หดตัวแม่ลง —
   ขยายไม่ทำให้ข้อมูลเดิมหาย ส่วนหดอาจตัดค่าที่มีอยู่ทิ้ง
   ต้องทำก่อนใส่ PK เพราะ LOC เป็นส่วนหนึ่งของ PK ที่จะใส่ข้างล่าง
   (คอลัมน์ที่อยู่ใน PK แล้ว ALTER ไม่ได้จนกว่าจะ drop PK ทิ้งก่อน)
----------------------------------------------------------------------------- */
ALTER TABLE [dbo].[DOC_DO_HDR]        ALTER COLUMN [ROUTE] [nvarchar](20) NULL
GO
ALTER TABLE [dbo].[DOC_DO_PICKDETAIL] ALTER COLUMN [ROUTE] [nvarchar](20) NULL
GO
ALTER TABLE [dbo].[TRX_LOTXLOCXID]    ALTER COLUMN [LOC] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_SKUXLOC]       ALTER COLUMN [LOC] [nvarchar](30) NOT NULL
GO
ALTER TABLE [dbo].[TRX_ITRN]          ALTER COLUMN [FROMLOC] [nvarchar](30) NULL
GO
ALTER TABLE [dbo].[TRX_ITRN]          ALTER COLUMN [TOLOC]   [nvarchar](30) NULL
GO

/* คลังของ: ยอดคงเหลือต่อ ล็อต × ตำแหน่ง × พาเลท — ต้นฉบับของสต็อก */
ALTER TABLE [dbo].[TRX_LOTXLOCXID] ADD CONSTRAINT [PK_TRX_LOTXLOCXID]
    PRIMARY KEY CLUSTERED ([WHSEID], [OWNERKEY], [SKU], [LOT], [LOC], [ID])
GO

/* ยอดคงเหลือต่อ SKU × ตำแหน่ง — ตารางนี้มี LOT ด้วย จึงต้องอยู่ใน PK */
ALTER TABLE [dbo].[TRX_SKUXLOC] ADD CONSTRAINT [PK_TRX_SKUXLOC]
    PRIMARY KEY CLUSTERED ([WHSEID], [OWNERKEY], [SKU], [LOC], [LOT])
GO

/* บันทึกการเคลื่อนไหว — ITRNKEY ควรไม่ซ้ำต่อคลัง */
ALTER TABLE [dbo].[TRX_ITRN] ADD CONSTRAINT [PK_TRX_ITRN]
    PRIMARY KEY CLUSTERED ([WHSEID], [ITRNKEY])
GO

ALTER TABLE [dbo].[TRX_TAGID] ADD CONSTRAINT [PK_TRX_TAGID]
    PRIMARY KEY CLUSTERED ([WHSEID], [ID])
GO
ALTER TABLE [dbo].[TRX_DROPID] ADD CONSTRAINT [PK_TRX_DROPID]
    PRIMARY KEY CLUSTERED ([WHSEID], [DROPID])
GO
ALTER TABLE [dbo].[TRX_DROPIDDETAIL] ADD CONSTRAINT [PK_TRX_DROPIDDETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [DROPID], [CHILDID])
GO
ALTER TABLE [dbo].[TRX_LOTATTRIBUTE] ADD CONSTRAINT [PK_TRX_LOTATTRIBUTE]
    PRIMARY KEY CLUSTERED ([WHSEID], [OWNERKEY], [SKU], [LOT])
GO
ALTER TABLE [dbo].[TRX_INVENTORYHOLD] ADD CONSTRAINT [PK_TRX_INVENTORYHOLD]
    PRIMARY KEY CLUSTERED ([WHSEID], [INVENTORYHOLDKEY])
GO
ALTER TABLE [dbo].[TRX_INVENTORYHOLDCODE] ADD CONSTRAINT [PK_TRX_INVENTORYHOLDCODE]
    PRIMARY KEY CLUSTERED ([WHSEID], [CODE])
GO
ALTER TABLE [dbo].[TRX_LOTXIDDETAIL] ADD CONSTRAINT [PK_TRX_LOTXIDDETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [LOTXIDKEY], [LOTXIDLINENUMBER])
GO

/* TRX_TODODETAIL เป็นตารางใหม่ใน R03 — คิวงานในคลัง (เบิก/เก็บ/ย้าย) ที่ทั้ง
   PICKDETAILKEY, WAVEKEY, LISTKEY, ORDERKEY ชี้ออกไปหาเอกสารต้นทาง
   มาแบบไม่มี PK เหมือนตาราง TRX_ อื่น ๆ */
ALTER TABLE [dbo].[TRX_TODODETAIL] ADD CONSTRAINT [PK_TRX_TODODETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [TODODETAILKEY])
GO

/* เอกสารขาออก */
ALTER TABLE [dbo].[DOC_DO_DETAIL] ADD CONSTRAINT [PK_DOC_DO_DETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [ORDERKEY], [ORDERLINENUMBER])
GO
ALTER TABLE [dbo].[DOC_DO_PICKDETAIL] ADD CONSTRAINT [PK_DOC_DO_PICKDETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [PICKDETAILKEY])
GO

/* เอกสารขาเข้า */
ALTER TABLE [dbo].[DOC_PO] ADD CONSTRAINT [PK_DOC_PO]
    PRIMARY KEY CLUSTERED ([WHSEID], [POKEY])
GO
ALTER TABLE [dbo].[DOC_PODETAIL] ADD CONSTRAINT [PK_DOC_PODETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [POKEY], [POLINENUMBER])
GO
ALTER TABLE [dbo].[DOC_RCPT_HDR] ADD CONSTRAINT [PK_DOC_RCPT_HDR]
    PRIMARY KEY CLUSTERED ([WHSEID], [RECEIPTKEY])
GO
ALTER TABLE [dbo].[DOC_RCPT_TDETAIL] ADD CONSTRAINT [PK_DOC_RCPT_TDETAIL]
    PRIMARY KEY CLUSTERED ([WHSEID], [RECEIPTKEY], [RECEIPTLINENUMBER], [SUBLINENUMBER])
GO

/* master ที่ยังไม่มี PK */
ALTER TABLE [dbo].[MST_SKU] ADD CONSTRAINT [PK_MST_SKU]
    PRIMARY KEY CLUSTERED ([OWNERKEY], [SKU])
GO
ALTER TABLE [dbo].[MST_PACK] ADD CONSTRAINT [PK_MST_PACK]
    PRIMARY KEY CLUSTERED ([PACKKEY])
GO
ALTER TABLE [dbo].[MST_OWNER] ADD CONSTRAINT [PK_MST_OWNER]
    PRIMARY KEY CLUSTERED ([OWNERKEY])
GO
ALTER TABLE [dbo].[MST_UOM] ADD CONSTRAINT [PK_MST_UOM]
    PRIMARY KEY CLUSTERED ([UM])
GO
ALTER TABLE [dbo].[MST_ALTSKU] ADD CONSTRAINT [PK_MST_ALTSKU]
    PRIMARY KEY CLUSTERED ([OWNERKEY], [SKU], [ALTSKU])
GO

/* ตารางรหัสกลาง — เก็บว่าฟิลด์ประเภทไหนมีค่าอะไรได้บ้าง
   นี่คือที่ที่ควรตอบคำถาม "STATUS มีค่าอะไรได้บ้าง" ของ README หัวข้อ 5 ข้อ 2
   ถ้าฐานจริงมีข้อมูลอยู่ในนี้ ให้ SELECT ออกมาก่อนจะไปถามทีมเดิม */
ALTER TABLE [dbo].[MST_UserDefinedTypes] ADD CONSTRAINT [PK_MST_UserDefinedTypes]
    PRIMARY KEY CLUSTERED ([Name])
GO
ALTER TABLE [dbo].[MST_UserDefinedTypeValues] ADD CONSTRAINT [PK_MST_UserDefinedTypeValues]
    PRIMARY KEY CLUSTERED ([TypeName], [Value])
GO

/* config */
ALTER TABLE [dbo].[CFG_ALLOCATESTRATEGY] ADD CONSTRAINT [PK_CFG_ALLOCATESTRATEGY]
    PRIMARY KEY CLUSTERED ([ALLOCATESTRATEGYKEY])
GO
ALTER TABLE [dbo].[CFG_ALLOCATESTRATEGYDETAIL] ADD CONSTRAINT [PK_CFG_ALLOCATESTRATEGYDETAIL]
    PRIMARY KEY CLUSTERED ([ALLOCATESTRATEGYKEY], [ALLOCATESTRATEGYLINENUMBER])
GO
ALTER TABLE [dbo].[CFG_PUTAWAYSTRATEGY] ADD CONSTRAINT [PK_CFG_PUTAWAYSTRATEGY]
    PRIMARY KEY CLUSTERED ([PUTAWAYSTRATEGYKEY])
GO
ALTER TABLE [dbo].[CFG_PUTAWAYSTRATEGYDETAIL] ADD CONSTRAINT [PK_CFG_PUTAWAYSTRATEGYDETAIL]
    PRIMARY KEY CLUSTERED ([PUTAWAYSTRATEGYKEY], [PUTAWAYSTRATEGYLINENUMBER])
GO

/* -----------------------------------------------------------------------------
   MST_WHSE — รากของทุกอย่าง แต่ WHSEID เป็น NULL ได้และไม่ unique
   ทุกตารางในระบบเก็บ WHSEID nvarchar(30) และ join กับตารางนี้ แต่ PK ของมัน
   คือ SERIALKEY ส่วน WHSEID เป็น NameType NULL → คลังสองแถวใช้รหัสเดียวกันได้
   และ FK ชี้มาที่ WHSEID ไม่ได้เลย ต้องอุดก่อนจะผูก FK ที่เหลือทั้งระบบ
----------------------------------------------------------------------------- */
-- 1) ตรวจว่าไม่มี NULL และไม่มีซ้ำ:
--    SELECT WHSEID, COUNT(*) FROM dbo.MST_WHSE GROUP BY WHSEID HAVING COUNT(*) > 1 OR WHSEID IS NULL;
-- 2) แล้วจึงบังคับ:
-- ALTER TABLE [dbo].[MST_WHSE] ALTER COLUMN [WHSEID] [nvarchar](30) NOT NULL
-- GO
-- ALTER TABLE [dbo].[MST_WHSE] ADD CONSTRAINT [UQ_MST_WHSE_WHSEID] UNIQUE ([WHSEID])
-- GO

/* MST_SHIPTO — SHIPTO ไม่ unique ทำให้ DOC_DO_HDR.SHIPTO ผูก FK ไม่ได้
   ต้องยืนยันก่อนว่าซ้ำจริงหรือไม่ (อาจซ้ำได้ถ้าแยกตาม WHSEID) */
-- SELECT SHIPTO, COUNT(*) FROM dbo.MST_SHIPTO GROUP BY SHIPTO HAVING COUNT(*) > 1;
-- ALTER TABLE [dbo].[MST_SHIPTO] ADD CONSTRAINT [UQ_MST_SHIPTO] UNIQUE ([WHSEID], [SHIPTO])
-- GO

/* =============================================================================
   B · เงินที่เก็บเป็น float

   float เป็นทศนิยมฐานสอง บวกกันแล้วไม่ตรง: 0.1 + 0.2 <> 0.3 ใบแจ้งหนี้ที่
   รวมมาจากคอลัมน์พวกนี้จะเพี้ยนหน่วยสตางค์และกระทบกันไม่ได้ทุกงวด
   DOC_SHIPMENT_DETAIL_LINE ใช้ decimal(22,5) อยู่แล้ว — ที่เหลือควรตามให้ตรง

   ⚠ ALTER COLUMN จาก float เป็น decimal จะปัดค่าเดิม ให้สำรองตารางก่อน
============================================================================= */
ALTER TABLE [dbo].[DOC_DO_DETAIL]     ALTER COLUMN [UNITPRICE]      [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_DETAIL]     ALTER COLUMN [TAX01]          [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_DETAIL]     ALTER COLUMN [TAX02]          [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_DETAIL]     ALTER COLUMN [EXTENDEDPRICE]  [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_PODETAIL]      ALTER COLUMN [UNITPRICE]      [decimal](22, 5) NULL
GO
ALTER TABLE [dbo].[DOC_PODETAIL]      ALTER COLUMN [UNIT_COST]      [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_RCPT_TDETAIL]  ALTER COLUMN [UNITPRICE]      [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_RCPT_TDETAIL]  ALTER COLUMN [EXTENDEDPRICE]  [decimal](22, 5) NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_PICKDETAIL] ALTER COLUMN [FREIGHTCHARGES] [decimal](22, 5) NULL
GO

/* =============================================================================
   C · คอลัมน์ที่จอที่มีอยู่ต้องใช้ แต่ตารางไม่มี
============================================================================= */

/* --- DOC_SHIPMENT_HDR ----------------------------------------------------
   มีของครบกว่าที่ไดอะแกรมวาดไว้มาก (LICENSEPLATE, DRIVERNAME, DRIVERMOBILE,
   TRAILERID, PLANNED/ACTUAL DEPARTURE+ARRIVAL, TOTAL*, MAX*, UTILIZATION_*,
   RATEKEY, ESTIMATEDCOST, ACTUALCOST) — ที่ยังขาดคือของบนหน้าเอกสารจริง  */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] ADD
    [PLANKEY]            [nvarchar](30)  NULL,   -- แผนที่ออกใบนี้
    [PARENT_SHIPMENTKEY] [nvarchar](30)  NULL,   -- ใบแม่ตอนแยกใบ (ใบลูก -1, -2)
    [DELIVERYDATE]       [date]          NULL,   -- วันนัดส่ง คนละวันกับ SHIPMENTDATE
    [SEALNO]             [nvarchar](30)  NULL,
    [ASSISTANTCOUNT]     [int]           NULL,   -- เด็กติดรถ 0-3
    /* ค่าขนส่งที่คิดจริงแยกเป็นส่วน ๆ — ESTIMATEDCOST/ACTUALCOST บอกได้แค่
       ยอดรวม ตอบไม่ได้ว่าทำไมสองเที่ยวเหมือนกันคิดไม่เท่ากัน */
    [TRIPPRICE]          [decimal](22, 5) NULL,
    [PRICEADD]           [decimal](22, 5) NULL,
    [PRICEDEDUCT]        [decimal](22, 5) NULL,
    [FREIGHTNOTE]        [nvarchar](500) NULL,
    [CURRENCY]           [nvarchar](10)  NULL,
    [EXPRESS_FLAG]       [bit]           NULL,
    [EXPRESS_REQUESTER]  [nvarchar](150) NULL,
    [EXPRESS_APPROVER]   [nvarchar](150) NULL,
    [CONFIRMDATE]        [datetime]      NULL,   -- ถึงขั้น "ยืนยัน" เมื่อไหร่
    [SENTDATE]           [datetime]      NULL,   -- ส่งให้ MMX เมื่อไหร่
    [STATUSMESSAGE]      [nvarchar](1000) NULL,  -- ข้อความที่ WMS/OMS ตีกลับ
    [CANCELREASON]       [nvarchar](500) NULL    -- ไม่บังคับกรอก
GO

ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] ADD CONSTRAINT [DF_SHIPMENT_HDR_EXPRESS] DEFAULT ((0)) FOR [EXPRESS_FLAG]
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] ADD CONSTRAINT [DF_SHIPMENT_HDR_ASSIST]  DEFAULT ((0)) FOR [ASSISTANTCOUNT]
GO

/* เด็กติดรถ 0-3 คน ตามที่ฟอร์มให้เลือก */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [CK_SHIPMENT_HDR_ASSIST]
    CHECK ([ASSISTANTCOUNT] IS NULL OR [ASSISTANTCOUNT] BETWEEN 0 AND 3)
GO

/* ส่วนลดมากกว่ายอดจนค่าขนส่งติดลบไม่ได้ — เคสที่เจอจริงคือ 0 + 0 - 3 = -3 */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [CK_SHIPMENT_HDR_FREIGHT_SIGN]
    CHECK (ISNULL([TRIPPRICE],0) >= 0 AND ISNULL([PRICEADD],0) >= 0
       AND ISNULL([PRICEDEDUCT],0) >= 0
       AND ISNULL([TRIPPRICE],0) + ISNULL([PRICEADD],0) - ISNULL([PRICEDEDUCT],0) >= 0)
GO

/* ส่งด่วนต้องมีทั้งผู้แจ้งและผู้อนุมัติ ข้อยกเว้นที่ไม่มีใครเซ็นคืออันที่
   จะถูกเถียงกันภายหลัง */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [CK_SHIPMENT_HDR_EXPRESS]
    CHECK ([EXPRESS_FLAG] = 0 OR [EXPRESS_FLAG] IS NULL
        OR ([EXPRESS_REQUESTER] IS NOT NULL AND [EXPRESS_APPROVER] IS NOT NULL))
GO

/* --- DOC_SHIPMENT_STOP ---------------------------------------------------
   มี LATITUDE/LONGITUDE, TIMEWINDOW, SERVICE_MINUTE, POD_* ครบแล้ว
   ขาดแค่สองอย่างที่จอใช้ */
ALTER TABLE [dbo].[DOC_SHIPMENT_STOP] ADD
    [CODAMOUNT]  [decimal](22, 5) NULL,  -- เก็บเงินปลายทาง
    [DUEDATE]    [date]           NULL,  -- ใช้คำนวณ badge "ล่าช้า +N วัน"
    [DELIVERTO]  [nvarchar](300)  NULL   -- ส่งต่างที่: ไซต์งาน สาขา ผู้รับแทน
GO

ALTER TABLE [dbo].[DOC_SHIPMENT_STOP] ADD CONSTRAINT [DF_SHIPMENT_STOP_COD] DEFAULT ((0)) FOR [CODAMOUNT]
GO

/* พิกัดต้องมาเป็นคู่ */
ALTER TABLE [dbo].[DOC_SHIPMENT_STOP] WITH CHECK ADD CONSTRAINT [CK_SHIPMENT_STOP_LATLNG]
    CHECK (([LATITUDE] IS NULL AND [LONGITUDE] IS NULL)
        OR ([LATITUDE] IS NOT NULL AND [LONGITUDE] IS NOT NULL))
GO

/* --- MST_VEHICLE: รถพ่วงมีสองทะเบียน ---------------------------------------
   LICENSEPLATE + LICENSEPROVINCE มีอยู่แล้ว แต่ทะเบียนพ่วงไม่มี
   (TRAILERID อยู่บน DOC_SHIPMENT_HDR ซึ่งเป็นรายเที่ยว ไม่ใช่รายคัน)   */
ALTER TABLE [dbo].[MST_VEHICLE] ADD
    [PLATE_TRAILER]          [nvarchar](30)  NULL,
    [PLATE_TRAILER_PROVINCE] [nvarchar](100) NULL
GO

/* ทะเบียนคือสิ่งที่ระบุรถบนถนน สองคันใช้ร่วมกันไม่ได้ */
CREATE UNIQUE INDEX [UX_MST_VEHICLE_PLATE] ON [dbo].[MST_VEHICLE] ([LICENSEPLATE])
GO

/* --- MST_TRANSPORT_RATE: ผูกสายส่ง/โซนเป็น FK ได้แล้ว ---------------------
   คอลัมน์ ROUTE / ZONE มีอยู่เดิมและเป็นข้อความ ตอนนี้มีตารางแม่ให้ชี้    */
ALTER TABLE [dbo].[MST_TRANSPORT_RATE] WITH CHECK ADD CONSTRAINT [FK_TRANSPORT_RATE_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
/* ZONE ยังผูกไม่ได้ — PK ของ MST_TRANSPORTATIONZONE เป็นสามคอลัมน์
   ดูทางเลือกและ query ตรวจซ้ำที่ท้ายไฟล์ 01-new-tables.sql */

/* ช่วงวันที่ต้องเรียงถูก ไม่งั้นเรตไม่มีวันถูกเลือก */
ALTER TABLE [dbo].[MST_TRANSPORT_RATE] WITH CHECK ADD CONSTRAINT [CK_TRANSPORT_RATE_PERIOD]
    CHECK ([EXPIRE_DATE] IS NULL OR [EFFECTIVE_DATE] IS NULL
        OR [EFFECTIVE_DATE] <= [EXPIRE_DATE])
GO

/* --- MST_TRANSPORTER_ROUTE ------------------------------------------------
   PK เดิมเป็น (TRANSPORTERKEY, ROUTE) แต่ ZONE เป็นคอลัมน์ธรรมดา →
   ผู้ให้บริการรายเดียวกันมีเรตต่างกันรายโซนบนสายเดียวกันไม่ได้
   ต้องเปลี่ยน PK ให้รวม ZONE ด้วย (ZONE ต้อง NOT NULL ก่อน)  */
-- UPDATE dbo.MST_TRANSPORTER_ROUTE SET ZONE = '*' WHERE ZONE IS NULL;   -- '*' = ทุกโซน
-- ALTER TABLE [dbo].[MST_TRANSPORTER_ROUTE] ALTER COLUMN [ZONE] [nvarchar](20) NOT NULL
-- GO
-- ALTER TABLE [dbo].[MST_TRANSPORTER_ROUTE] DROP CONSTRAINT [PK_MST_TRANSPORTER_ROUTE]
-- GO
-- ALTER TABLE [dbo].[MST_TRANSPORTER_ROUTE] ADD CONSTRAINT [PK_MST_TRANSPORTER_ROUTE]
--     PRIMARY KEY CLUSTERED ([TRANSPORTERKEY], [ROUTE], [ZONE])
-- GO

ALTER TABLE [dbo].[MST_TRANSPORTER_ROUTE] WITH CHECK ADD CONSTRAINT [FK_TRANSPORTER_ROUTE_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO

/* --- MST_TRANSPORTER_DOCUMENT: เอกสารส่วนใหญ่ผูกกับคันรถ ------------------
   ประกันภัยและภาษีเป็นของ *รถ* ไม่ใช่ของผู้ให้บริการ และ MST_VEHICLE ก็มี
   INSURANCEEXPIRE / REGISTRATIONEXPIRE อยู่แล้ว — คอลัมน์นี้ทำให้แนบไฟล์
   เอกสารเข้ากับคันที่ถูกต้องได้ */
ALTER TABLE [dbo].[MST_TRANSPORTER_DOCUMENT] ADD [VEHICLEKEY] [nvarchar](20) NULL
GO
ALTER TABLE [dbo].[MST_TRANSPORTER_DOCUMENT] WITH CHECK ADD CONSTRAINT [FK_TRANSPORT_DOCUMENT_VEHICLE]
    FOREIGN KEY([VEHICLEKEY]) REFERENCES [dbo].[MST_VEHICLE] ([VEHICLEKEY])
GO

/* --- DOC_DO_HDR: ผูกสายส่งและโซน ----------------------------------------
   มี ROUTE, STOP, SHIPMENTID, REQUESTEDSHIPDATE, DELIVERYDATE อยู่แล้ว
   ที่ขาดคือ ZONE (มีแต่ ROUTE) และ FK ของทั้งคู่  */
ALTER TABLE [dbo].[DOC_DO_HDR] ADD [ZONE] [nvarchar](20) NULL
GO
ALTER TABLE [dbo].[DOC_DO_HDR] WITH CHECK ADD CONSTRAINT [FK_DO_HDR_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
/* FK ของ ZONE ยังผูกไม่ได้ — ดูท้ายไฟล์ 01-new-tables.sql */

/* =============================================================================
   D · FK ที่ยังไม่ผูก
   ตอนนี้มี FK อยู่แค่กลุ่ม shipment / vehicle / driver / location / zone
   ส่วนคลังของกับเอกสารขาเข้า-ออกไม่มีเลย ทำให้ลบ master ทิ้งได้ทั้งที่มี
   ธุรกรรมอ้างอยู่ (ใส่หลังส่วน A เพราะต้องมี PK ปลายทางก่อน)
============================================================================= */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_PLAN]
    FOREIGN KEY([WHSEID], [PLANKEY]) REFERENCES [dbo].[DOC_TRANSPORT_PLAN] ([WHSEID], [PLANKEY])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_TRANSPORTER]
    FOREIGN KEY([TRANSPORTERKEY]) REFERENCES [dbo].[MST_TRANSPORTER] ([TRANSPORTERKEY])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_VEHICLE]
    FOREIGN KEY([VEHICLEKEY]) REFERENCES [dbo].[MST_VEHICLE] ([VEHICLEKEY])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_DRIVER]
    FOREIGN KEY([DRIVERKEY]) REFERENCES [dbo].[MST_DRIVER] ([DRIVERKEY])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_HDR_RATE]
    FOREIGN KEY([RATEKEY]) REFERENCES [dbo].[MST_TRANSPORT_RATE] ([RATEKEY])
GO

ALTER TABLE [dbo].[DOC_SHIPMENT_STOP] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_STOP_CUSTOMER]
    FOREIGN KEY([CUSTOMERKEY]) REFERENCES [dbo].[MST_CUSTOMER] ([CUSTOMERKEY])
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_DETAIL] WITH CHECK ADD CONSTRAINT [FK_SHIPMENT_DETAIL_ROUTE]
    FOREIGN KEY([ROUTE]) REFERENCES [dbo].[MST_ROUTE] ([ROUTE])
GO
/* FK ของ ZONE ทั้งสองตารางนี้ยังผูกไม่ได้ — ดูท้ายไฟล์ 01-new-tables.sql */

ALTER TABLE [dbo].[DOC_DO_DETAIL] WITH CHECK ADD CONSTRAINT [FK_DO_DETAIL_SKU]
    FOREIGN KEY([OWNERKEY], [SKU]) REFERENCES [dbo].[MST_SKU] ([OWNERKEY], [SKU])
GO

/* --- ใบสั่งส่งชี้กลับไปหาใบสั่งขาย ---------------------------------------
   `EXTERNORDERKEY` เก็บเลข SO เป็นข้อความมาตลอด และเป็น NOT NULL อยู่แล้วในฐาน
   เดิม — FK นี้ไม่ได้เพิ่มข้อบังคับใหม่ว่า "ต้องมีเลข SO" แต่เพิ่มว่า
   **เลขนั้นต้องมีใบ SO อยู่จริง** ซึ่งเดิมไม่มีอะไรตรวจเลย
   ทิศทางคือ DO → SO เพราะ SO ใบเดียวแตกเป็นได้หลาย DO

   ⚠ บนฐานที่มีข้อมูลจริง อันนี้จะล้มถ้ามี DO ที่อ้างเลข SO ที่ไม่มีใบรองรับ
     ซึ่งเป็นเรื่องที่ต้องรู้ ไม่ใช่เรื่องที่ควรข้าม ตรวจก่อนด้วย query นี้
     ต้องได้ 0 แถว:

       SELECT d.WHSEID, d.ORDERKEY, d.EXTERNORDERKEY
       FROM   dbo.DOC_DO_HDR d
       WHERE  NOT EXISTS (SELECT 1 FROM dbo.DOC_SO_HDR s
                          WHERE s.WHSEID = d.WHSEID AND s.SOKEY = d.EXTERNORDERKEY);

     ถ้าได้แถวออกมา แปลว่าต้องสร้างใบ SO ย้อนหลังจากข้อมูลที่มีบน DO ก่อน
     (backfill) อย่าลบ DO ทิ้งและอย่าล้างค่า EXTERNORDERKEY เพื่อให้ FK ผ่าน */
ALTER TABLE [dbo].[DOC_DO_HDR] WITH CHECK ADD CONSTRAINT [FK_DO_HDR_SO]
    FOREIGN KEY([WHSEID], [EXTERNORDERKEY]) REFERENCES [dbo].[DOC_SO_HDR] ([WHSEID], [SOKEY])
GO

/* บรรทัดใบสั่งขายชี้ไปสินค้า — อยู่ตรงนี้เพราะ PK ของ MST_SKU เพิ่งถูกใส่ในส่วน A
   ของไฟล์นี้ ตอน 01-new-tables.sql รัน ตารางนั้นยังไม่มีคีย์ให้ FK เกาะ */
ALTER TABLE [dbo].[DOC_SO_DETAIL] WITH CHECK ADD CONSTRAINT [FK_DOC_SO_DETAIL_SKU]
    FOREIGN KEY([OWNERKEY], [SKU]) REFERENCES [dbo].[MST_SKU] ([OWNERKEY], [SKU])
GO

/* หา DO ทุกใบของ SO หนึ่งใบ — เส้นทางที่จอ "SO ใบนี้ส่งครบหรือยัง" ต้องใช้ */
CREATE INDEX [IX_DO_HDR_EXTERNORDERKEY]
    ON [dbo].[DOC_DO_HDR] ([WHSEID], [EXTERNORDERKEY]) INCLUDE ([ORDERKEY], [STATUS])
GO
ALTER TABLE [dbo].[DOC_RCPT_TDETAIL] WITH CHECK ADD CONSTRAINT [FK_RCPT_TDETAIL_HDR]
    FOREIGN KEY([WHSEID], [RECEIPTKEY]) REFERENCES [dbo].[DOC_RCPT_HDR] ([WHSEID], [RECEIPTKEY])
GO
ALTER TABLE [dbo].[DOC_PODETAIL] WITH CHECK ADD CONSTRAINT [FK_PODETAIL_PO]
    FOREIGN KEY([WHSEID], [POKEY]) REFERENCES [dbo].[DOC_PO] ([WHSEID], [POKEY])
GO
ALTER TABLE [dbo].[TRX_LOTXLOCXID] WITH CHECK ADD CONSTRAINT [FK_LOTXLOCXID_SKU]
    FOREIGN KEY([OWNERKEY], [SKU]) REFERENCES [dbo].[MST_SKU] ([OWNERKEY], [SKU])
GO
ALTER TABLE [dbo].[TRX_LOTXLOCXID] WITH CHECK ADD CONSTRAINT [FK_LOTXLOCXID_LOC]
    FOREIGN KEY([WHSEID], [LOC]) REFERENCES [dbo].[MST_LOCATION] ([WHSEID], [LOC])
GO
ALTER TABLE [dbo].[TRX_SKUXLOC] WITH CHECK ADD CONSTRAINT [FK_SKUXLOC_LOC]
    FOREIGN KEY([WHSEID], [LOC]) REFERENCES [dbo].[MST_LOCATION] ([WHSEID], [LOC])
GO

/* =============================================================================
   E · กฎ "ของอยู่ได้ที่เดียว" + ดัชนีที่ควรมี
============================================================================= */

/* ใบสั่งส่งหนึ่งใบอยู่บนใบปิดบรรทุกได้ใบเดียว — คู่กับ UNIQUE บน
   DOC_TRANSPORT_PLAN_LINE.ORDERKEY ที่ทำไว้ใน 01 ทั้งสองอันรวมกันคือกฎที่
   mock adapter บังคับอยู่แล้วฝั่ง client และต้องบังคับซ้ำที่นี่ เพราะ
   ปุ่มที่กดไม่ได้ไม่ใช่การป้องกัน
   ⚠ ต้องตรวจก่อนว่าข้อมูลเดิมไม่ละเมิด — ใบที่ยกเลิกใช้ STATUS อะไรต้องยืนยัน */
-- SELECT ORDERKEY, COUNT(*) FROM dbo.DOC_SHIPMENT_DETAIL
-- WHERE STATUS <> 'CANCELLED' GROUP BY ORDERKEY HAVING COUNT(*) > 1;
CREATE UNIQUE INDEX [UX_SHIPMENT_DETAIL_ORDER]
    ON [dbo].[DOC_SHIPMENT_DETAIL] ([ORDERKEY]) WHERE [STATUS] <> 'CANCELLED'
GO

/* ลำดับจุดส่งซ้ำกันในใบเดียวไม่ได้ */
CREATE UNIQUE INDEX [UX_SHIPMENT_STOP_SEQ]
    ON [dbo].[DOC_SHIPMENT_STOP] ([WHSEID], [SHIPMENTKEY], [STOPSEQ])
GO

/* ดัชนีที่จอเรียกใช้ทุกครั้ง */
CREATE INDEX [IX_SHIPMENT_HDR_STATUS_DATE] ON [dbo].[DOC_SHIPMENT_HDR] ([STATUS], [SHIPMENTDATE] DESC)
GO
CREATE INDEX [IX_SHIPMENT_HDR_ROUTE_DATE]  ON [dbo].[DOC_SHIPMENT_HDR] ([ROUTE], [DELIVERYDATE])
GO
CREATE INDEX [IX_DO_HDR_STATUS_ROUTE]      ON [dbo].[DOC_DO_HDR] ([STATUS], [ROUTE])
GO

/* ยอดรวมบน HDR เป็นค่าที่เก็บไว้ จะเพี้ยนทันทีที่มีการเพิ่ม/ถอดจุดส่ง
   (จอแก้ไขทำได้จนถึงก่อนส่ง MMX) view นี้คือตัวเทียบว่าค่าที่เก็บยังตรง
   ทางที่ดีกว่าคือให้ backend คำนวณใหม่ทุกครั้งที่เขียน แล้วใช้ view นี้
   เป็น reconciliation check ใน job กลางคืน
   น้ำหนัก/ปริมาตรอ่านจาก DOC_SHIPMENT_DETAIL_LINE ที่มี GROSSWGT/CUBE
   ของตัวเองอยู่แล้ว ไม่ต้องไปคูณจาก MST_PACK */
CREATE OR ALTER VIEW [dbo].[VW_SHIPMENT_TOTALS_CHECK]
AS
SELECT  h.WHSEID,
        h.SHIPMENTKEY,
        h.TOTALSTOP,   a.STOPCOUNT,
        h.TOTALWEIGHT, a.SUMWEIGHT,
        h.TOTALCUBE,   a.SUMCUBE
FROM    [dbo].[DOC_SHIPMENT_HDR] h
CROSS APPLY (
    SELECT  COUNT(DISTINCT s.SHIPMENTSTOPID)                AS STOPCOUNT,
            ISNULL(SUM(ISNULL(l.GROSSWGT, 0)), 0)           AS SUMWEIGHT,
            ISNULL(SUM(ISNULL(l.CUBE, 0)), 0)               AS SUMCUBE
    FROM    [dbo].[DOC_SHIPMENT_STOP] s
    LEFT JOIN [dbo].[DOC_SHIPMENT_DETAIL] d
           ON d.WHSEID = s.WHSEID AND d.SHIPMENTKEY = s.SHIPMENTKEY
          AND d.SHIPMENTSTOPID = s.SHIPMENTSTOPID
    LEFT JOIN [dbo].[DOC_SHIPMENT_DETAIL_LINE] l
           ON l.WHSEID = d.WHSEID AND l.SHIPMENTKEY = d.SHIPMENTKEY
          AND l.SHIPMENTDETAILID = d.SHIPMENTDETAILID
    WHERE   s.WHSEID = h.WHSEID AND s.SHIPMENTKEY = h.SHIPMENTKEY
) a
WHERE   ISNULL(h.TOTALSTOP, 0)   <> a.STOPCOUNT
   OR   ISNULL(h.TOTALWEIGHT, 0) <> a.SUMWEIGHT
   OR   ISNULL(h.TOTALCUBE, 0)   <> a.SUMCUBE
GO

/* =============================================================================
   F · ROWVERSION
   ADDDATE/ADDWHO/EDITDATE/EDITWHO มีครบทุกตารางแล้ว — ที่ไม่มีคือตัวเทียบ
   เวอร์ชันสำหรับ optimistic concurrency frontend รับ 409 conflict อยู่แล้ว
   และจอแก้ไขใบปิดบรรทุกเปิดพร้อมกันได้หลายคน จึงต้องรู้ว่าแถวถูกคนอื่น
   แก้ไปก่อนหรือยัง EDITDATE ใช้แทนไม่ได้เพราะละเอียดแค่ 3ms และแก้มือได้
============================================================================= */
ALTER TABLE [dbo].[DOC_SHIPMENT_HDR]     ADD [ROWVER] [rowversion] NOT NULL
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_STOP]    ADD [ROWVER] [rowversion] NOT NULL
GO
ALTER TABLE [dbo].[DOC_SHIPMENT_DETAIL]  ADD [ROWVER] [rowversion] NOT NULL
GO
ALTER TABLE [dbo].[DOC_DO_HDR]           ADD [ROWVER] [rowversion] NOT NULL
GO
ALTER TABLE [dbo].[DOC_TRANSPORT_PLAN]   ADD [ROWVER] [rowversion] NOT NULL
GO

/* =============================================================================
   G · เก็บกวาด
============================================================================= */

/* TRX_LOT มี CHECK เดียวกันสองชุด (ต่างกันแค่ชื่อที่ระบบตั้งให้)
   ชุดที่ซ้ำไม่ได้เพิ่มความปลอดภัยแต่ต้องถูกตรวจทุกครั้งที่เขียน */
-- ALTER TABLE [dbo].[TRX_LOT] DROP CONSTRAINT [CK__LOT__693CA210]
-- GO
-- ALTER TABLE [dbo].[TRX_LOT] DROP CONSTRAINT [CK__LOT__6A30C649]
-- GO

/* ค่า sentinel แทน NULL: TRX_LOT.ARCHIVEDATE NOT NULL DEFAULT '01/01/1901'
   และ TRX_INVENTORYHOLD.DATEOFF/WHOOFF NOT NULL แม้ยังไม่ปลด hold
   "ยังไม่เกิด" กับ "เกิดเมื่อปี 1901" เป็นสองเรื่อง และทุก query ที่กรอง
   ช่วงวันต้องรู้ค่าวิเศษนี้เอง — ควรเปลี่ยนเป็น NULL ได้
   (ต้องแก้โค้ดที่อ่านค่านี้พร้อมกัน จึงไม่รันอัตโนมัติ) */
-- ALTER TABLE [dbo].[TRX_LOT] ALTER COLUMN [ARCHIVEDATE] [datetime] NULL
-- GO
-- UPDATE dbo.TRX_LOT SET ARCHIVEDATE = NULL WHERE ARCHIVEDATE = '19010101';
-- GO

/* CFG_ALLOCATESTRATEGYDETAIL.PICKCODESQL nvarchar(2000) เก็บ SQL ดิบไว้ใน
   คอลัมน์แล้วเอาไปรัน — ถ้าประกอบเป็นสตริงแล้ว EXEC ตรง ๆ คือช่องทาง
   SQL injection ที่แก้ไขได้จากหน้าจอ config ควรทำ 2 อย่างในฝั่งแอป:
     1) จำกัดสิทธิ์แก้ไขคอลัมน์นี้ให้เฉพาะ role ที่เชื่อถือได้
     2) รันผ่าน sp_executesql พร้อม parameter เท่านั้น ห้ามต่อสตริง
   ไม่มี DDL แก้ให้ได้ — บันทึกไว้เป็นข้อสังเกตด้านความปลอดภัย */
