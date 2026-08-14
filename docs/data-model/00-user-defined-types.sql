/* =============================================================================
   MamMoD (MMPRD) — user-defined type ที่สคริปต์ฐานอ้างถึงแต่ไม่ได้นิยามไว้
   SQL Server · รันไฟล์นี้ **ก่อน** MAMMOD_TABLE2_R03.sql

   ทำไมต้องมีไฟล์นี้
   ---------------------------------------------------------------------------
   `MAMMOD_TABLE2_R03.sql` ที่ได้มาเป็น script ของ "ตาราง" อย่างเดียว ตอน generate
   ออกมาไม่ได้ติด user-defined type มาด้วย แต่ 6 ตารางในนั้นประกาศคอลัมน์ด้วย
   type พวกนี้ (`MST_WHSE`, `MST_SHIPTO`, `MST_UserDefinedTypeValues` และตารางที่
   มี `site_ref`) → รันบนฐานเปล่าจะล้มทันทีที่ `CREATE TABLE [dbo].[MST_WHSE]`
   ด้วย error 2715 "Column, parameter, or variable #2: Cannot find data type"

   ⚠ ความยาวในไฟล์นี้เป็นการ **อนุมาน** ไม่ใช่ของจริง
   ---------------------------------------------------------------------------
   ของจริงอยู่ในฐาน production เท่านั้น ดึงออกมาด้วย:

     SELECT  t.name,
             bt.name AS base_type,
             t.max_length,        -- หน่วยเป็นไบต์ nvarchar ต้องหาร 2
             t.precision, t.scale, t.is_nullable
     FROM    sys.types t
     JOIN    sys.types bt ON bt.user_type_id = t.system_type_id
     WHERE   t.is_user_defined = 1
     ORDER BY t.name;

   เอาผลลัพธ์มาแทนค่าในไฟล์นี้ก่อนจะเชื่อผลการทดสอบใด ๆ ที่กระทบความยาวข้อมูล
   ระหว่างนี้ไฟล์นี้ทำให้ฐาน dev ในเครื่อง "ขึ้นได้" และ shape ของตารางถูกต้อง
   ซึ่งพอสำหรับพัฒนา backend และ generate EF Core model

   ที่มาของค่าที่เลือก — เดาจากหลักฐานในสคริปต์ ไม่ได้เดาลอย ๆ
   ---------------------------------------------------------------------------
   - `RowPointerType`  → `uniqueidentifier` เพราะ `DF_site_RowPointer DEFAULT (newid())`
   - `CurrentDateType` → `datetime`         เพราะ `DEFAULT (getdate())`
   - `UsernameType`    → รับค่าจาก `suser_sname()` ซึ่งคืน `nvarchar(128)` ได้
                         แต่คอลัมน์ audit อื่นทั้งฐานใช้ `nvarchar(100)` จึงตามนั้น
   - `NameType`        → ใช้กับ `MST_WHSE.WHSEID` ด้วย ซึ่งตารางอื่นทั้งฐานเก็บเป็น
                         `nvarchar(30)` · ตั้งไว้ที่ 50 เพราะ `MST_SHIPTO.name`
                         ก็ใช้ type เดียวกันและชื่อลูกค้า 30 ตัวอักษรสั้นเกินไป
                         **ผลข้างเคียง: `MST_WHSE.WHSEID` ยาวกว่าที่ตารางลูกรับได้**
                         ซึ่งเป็นอาการเดียวกับที่ README หัวข้อ 2.2 บอกไว้อยู่แล้ว
                         ว่าคีย์คลังทั้งระบบไม่ได้ถูกบังคับให้ตรงกัน
   - ที่เหลือ          → ตั้งตามความยาวมาตรฐานของฟิลด์ชนิดนั้นในตารางอื่นของฐานเดียวกัน
                         (เช่น `PROVINCE nvarchar(100)`, `POSTALCODE nvarchar(10)`,
                         `PHONE nvarchar(30)` ใน `MST_TRANSPORTER` / `MST_VENDOR`)
============================================================================= */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* ── คีย์และชื่อ ────────────────────────────────────────────────────────────── */

/* ใช้กับ MST_WHSE.WHSEID และ MST_SHIPTO.name — ดูหมายเหตุด้านบน */
IF TYPE_ID(N'dbo.NameType') IS NULL
    CREATE TYPE [dbo].[NameType]        FROM [nvarchar](50) NULL;
GO

/* site_ref — อ้างถึงคลัง เท่ากับความยาว WHSEID ที่ตารางอื่นใช้ */
IF TYPE_ID(N'dbo.SiteType') IS NULL
    CREATE TYPE [dbo].[SiteType]        FROM [nvarchar](30) NULL;
GO

/* MST_WHSE.type — รหัสประเภทคลัง สั้น */
IF TYPE_ID(N'dbo.SiteTypeType') IS NULL
    CREATE TYPE [dbo].[SiteTypeType]    FROM [nvarchar](10) NULL;
GO

/* MST_SHIPTO.drop_seq — ลำดับจุดส่งในสาย เก็บเป็นข้อความตามที่ฐานทำทั้งระบบ */
IF TYPE_ID(N'dbo.DropSeqType') IS NULL
    CREATE TYPE [dbo].[DropSeqType]     FROM [nvarchar](10) NULL;
GO

/* ── ที่อยู่ ────────────────────────────────────────────────────────────────── */
/* กลุ่มนี้อยู่บน MST_SHIPTO ทั้งหมด และเป็นที่อยู่แบบตะวันตก (city/state/zip/county)
   ซึ่งเข้ากับที่อยู่แบบไทยของ DOC_SHIPMENT_STOP ไม่ได้ — README หัวข้อ 2.7 */

IF TYPE_ID(N'dbo.AddressType') IS NULL
    CREATE TYPE [dbo].[AddressType]     FROM [nvarchar](100) NULL;
GO
IF TYPE_ID(N'dbo.CityType') IS NULL
    CREATE TYPE [dbo].[CityType]        FROM [nvarchar](50) NULL;
GO
IF TYPE_ID(N'dbo.StateType') IS NULL
    CREATE TYPE [dbo].[StateType]       FROM [nvarchar](50) NULL;
GO
IF TYPE_ID(N'dbo.CountyType') IS NULL
    CREATE TYPE [dbo].[CountyType]      FROM [nvarchar](50) NULL;
GO
IF TYPE_ID(N'dbo.CountryType') IS NULL
    CREATE TYPE [dbo].[CountryType]     FROM [nvarchar](50) NULL;
GO
IF TYPE_ID(N'dbo.PostalCodeType') IS NULL
    CREATE TYPE [dbo].[PostalCodeType]  FROM [nvarchar](20) NULL;
GO

/* ── ติดต่อ ─────────────────────────────────────────────────────────────────── */

IF TYPE_ID(N'dbo.ContactType') IS NULL
    CREATE TYPE [dbo].[ContactType]     FROM [nvarchar](50) NULL;
GO
IF TYPE_ID(N'dbo.PhoneType') IS NULL
    CREATE TYPE [dbo].[PhoneType]       FROM [nvarchar](30) NULL;
GO

/* ── คำบรรยาย ──────────────────────────────────────────────────────────────── */
/* MediumDescType ใช้กับ MST_UserDefinedTypeValues.TypeName ซึ่งต้องตรงกับ
   MST_UserDefinedTypes.Name ที่ประกาศเป็น nvarchar(80) ตรง ๆ → ใช้ 80 ให้ตรงกัน */

IF TYPE_ID(N'dbo.MediumDescType') IS NULL
    CREATE TYPE [dbo].[MediumDescType]  FROM [nvarchar](80) NULL;
GO
IF TYPE_ID(N'dbo.LongDescType') IS NULL
    CREATE TYPE [dbo].[LongDescType]    FROM [nvarchar](255) NULL;
GO
IF TYPE_ID(N'dbo.DescriptionType') IS NULL
    CREATE TYPE [dbo].[DescriptionType] FROM [nvarchar](255) NULL;
GO

/* ── ระบบ ──────────────────────────────────────────────────────────────────── */

/* app_db_name — ชื่อฐาน/พาธของ instance ที่คลังนั้นใช้ */
IF TYPE_ID(N'dbo.OSLocationType') IS NULL
    CREATE TYPE [dbo].[OSLocationType]  FROM [nvarchar](255) NULL;
GO
IF TYPE_ID(N'dbo.LangCodeType') IS NULL
    CREATE TYPE [dbo].[LangCodeType]    FROM [nvarchar](10) NULL;
GO
IF TYPE_ID(N'dbo.TimeZoneType') IS NULL
    CREATE TYPE [dbo].[TimeZoneType]    FROM [nvarchar](50) NULL;
GO

/* suser_sname() คืนค่าได้ถึง 128 แต่ทั้งฐานใช้ nvarchar(100) กับคอลัมน์ ADDWHO/EDITWHO
   จึงใช้ 100 ให้เท่ากัน — ชื่อ login ที่ยาวกว่านี้จะถูกตัด ซึ่งกระทบแค่ audit trail */
IF TYPE_ID(N'dbo.UsernameType') IS NULL
    CREATE TYPE [dbo].[UsernameType]    FROM [nvarchar](100) NULL;
GO

/* DEFAULT (getdate()) บอกว่าเป็นวันเวลา ไม่ใช่ข้อความ · ทั้งฐานใช้ datetime ไม่ใช่
   datetime2 (README หัวข้อ 2.7) จึงตามให้เข้ากันไว้ก่อน */
IF TYPE_ID(N'dbo.CurrentDateType') IS NULL
    CREATE TYPE [dbo].[CurrentDateType] FROM [datetime] NULL;
GO

/* DEFAULT (newid()) บอกชัดว่าเป็น GUID */
IF TYPE_ID(N'dbo.RowPointerType') IS NULL
    CREATE TYPE [dbo].[RowPointerType]  FROM [uniqueidentifier] NULL;
GO

/* ── ตรวจว่าครบ ────────────────────────────────────────────────────────────── */
/* ควรได้ 21 แถว ถ้าน้อยกว่านั้นแปลว่ามี GO ไหนล้ม ให้ดู error ก่อนรันไฟล์ถัดไป */
SELECT  t.name                                   AS [type],
        bt.name                                  AS base_type,
        CASE WHEN bt.name LIKE N'n%char'
             THEN t.max_length / 2 ELSE t.max_length END AS [length]
FROM    sys.types t
JOIN    sys.types bt ON bt.user_type_id = t.system_type_id
WHERE   t.is_user_defined = 1
ORDER BY t.name;
GO
