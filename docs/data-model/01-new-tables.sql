/* =============================================================================
   MamMoD (MMPRD) â€” à¸•à¸²à¸£à¸²à¸‡à¸—à¸µà¹ˆà¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¸¡à¸µà¹ƒà¸™à¸à¸²à¸™à¸ˆà¸£à¸´à¸‡
   SQL Server Â· à¸£à¸±à¸™à¹„à¸Ÿà¸¥à¹Œà¸™à¸µà¹‰à¸à¹ˆà¸­à¸™ 02-alter-existing.sql

   à¸•à¸£à¸‡à¸à¸±à¸š MAMMOD_TABLE2_R03.sql (à¸à¸²à¸™ MMDEV) à¹à¸¥à¹‰à¸§ à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆà¸•à¸²à¸¡à¹„à¸”à¸­à¸°à¹à¸à¸£à¸¡ ER
   à¸‹à¸¶à¹ˆà¸‡à¸„à¸¥à¸²à¸”à¹€à¸„à¸¥à¸·à¹ˆà¸­à¸™à¸ˆà¸²à¸à¸à¸²à¸™à¸«à¸¥à¸²à¸¢à¸ˆà¸¸à¸” (à¸”à¸¹ README.md à¸«à¸±à¸§à¸‚à¹‰à¸­ 1)

   R03 à¹€à¸žà¸´à¹ˆà¸¡ MST_TRANSPORTATIONZONE à¸à¸±à¸š TRX_TODODETAIL à¸¡à¸²à¸ˆà¸²à¸ R02 â†’ à¸«à¸±à¸§à¸‚à¹‰à¸­ 2
   à¹ƒà¸™à¹„à¸Ÿà¸¥à¹Œà¸™à¸µà¹‰à¸–à¸¹à¸à¸–à¸­à¸™à¸­à¸­à¸ à¹à¸¥à¸°à¸«à¸±à¸§à¸‚à¹‰à¸­ 3, 4, 7 à¹€à¸›à¸¥à¸µà¹ˆà¸¢à¸™à¹„à¸›à¸œà¸¹à¸à¸à¸±à¸šà¸•à¸²à¸£à¸²à¸‡à¸—à¸µà¹ˆà¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¹à¸—à¸™
   à¹€à¸«à¸¥à¸·à¸­à¸•à¸²à¸£à¸²à¸‡à¸—à¸µà¹ˆà¸ªà¸£à¹‰à¸²à¸‡à¸ˆà¸£à¸´à¸‡ 10 à¹ƒà¸š

   à¸‚à¹‰à¸­à¸•à¸à¸¥à¸‡à¸—à¸µà¹ˆà¸¥à¸­à¸à¸¡à¸²à¸ˆà¸²à¸à¸•à¸²à¸£à¸²à¸‡à¹€à¸”à¸´à¸¡ à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¸„à¸´à¸”à¸‚à¸¶à¹‰à¸™à¹ƒà¸«à¸¡à¹ˆ
   - à¸—à¸¸à¸à¸•à¸²à¸£à¸²à¸‡à¸¡à¸µ  [SERIALKEY] int IDENTITY(1,1)  à¹€à¸›à¹‡à¸™à¸„à¸µà¸¢à¹Œà¹à¸—à¸™
   - à¸„à¸µà¸¢à¹Œà¸˜à¸¸à¸£à¸à¸´à¸ˆà¹€à¸›à¹‡à¸™ NVARCHAR à¸•à¸²à¸¡à¸„à¸§à¸²à¸¡à¸¢à¸²à¸§à¸—à¸µà¹ˆà¸•à¸²à¸£à¸²à¸‡à¹€à¸”à¸´à¸¡à¹ƒà¸Šà¹‰:
       WHSEID nvarchar(30) Â· OWNERKEY nvarchar(15) Â· SKU nvarchar(50)
       TRANSPORTERKEY / VEHICLEKEY / DRIVERKEY / VEHICLETYPEKEY nvarchar(20)
       SHIPMENTKEY nvarchar(30) Â· ORDERKEY nvarchar(50) Â· ROUTE / ZONE nvarchar(20)
   - à¸ˆà¸³à¸™à¸§à¸™/à¸™à¹‰à¸³à¸«à¸™à¸±à¸/à¸›à¸£à¸´à¸¡à¸²à¸•à¸£  decimal(22,5)  Â· à¹€à¸‡à¸´à¸™ decimal(22,5) (à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆ float)
   - à¹€à¸§à¸¥à¸²  datetime  Â· à¸§à¸±à¸™à¸—à¸µà¹ˆà¸—à¸²à¸‡à¸˜à¸¸à¸£à¸à¸´à¸ˆ  date
   - audit  ADDDATE / ADDWHO / EDITDATE / EDITWHO  + SUSR1..SUSR5 à¸ªà¸³à¸£à¸­à¸‡
   - STATUS à¹€à¸›à¹‡à¸™ **à¸•à¸±à¸§à¸žà¸´à¸¡à¸žà¹Œà¹ƒà¸«à¸à¹ˆ** ('ACTIVE' / 'NEW' / 'OK') à¸•à¸²à¸¡à¸—à¸µà¹ˆà¸à¸²à¸™à¹€à¸”à¸´à¸¡à¸•à¸±à¹‰à¸‡
     DEFAULT à¹„à¸§à¹‰ â€” à¸à¸±à¹ˆà¸‡ UI à¹ƒà¸Šà¹‰à¸•à¸±à¸§à¸žà¸´à¸¡à¸žà¹Œà¹€à¸¥à¹‡à¸ à¸ˆà¸¶à¸‡à¸•à¹‰à¸­à¸‡à¸¡à¸µ mapping à¸—à¸µà¹ˆ backend
     (à¸”à¸¹ README à¸«à¸±à¸§à¸‚à¹‰à¸­ 4)
============================================================================= */

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/* -----------------------------------------------------------------------------
   1 Â· MST_ROUTE â€” à¸ªà¸²à¸¢à¸ªà¹ˆà¸‡
   ROUTE à¹€à¸›à¹‡à¸™à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡à¸¥à¸­à¸¢à¸­à¸¢à¸¹à¹ˆà¹ƒà¸™ DOC_DO_HDR, DOC_SHIPMENT_HDR,
   DOC_SHIPMENT_DETAIL, DOC_DO_PICKDETAIL, MST_TRANSPORTER_ROUTE à¹à¸¥à¸°
   MST_TRANSPORT_RATE à¹‚à¸”à¸¢à¹„à¸¡à¹ˆà¸¡à¸µà¸•à¸²à¸£à¸²à¸‡à¹à¸¡à¹ˆ â€” à¸™à¸µà¹ˆà¸„à¸·à¸­à¸Šà¹ˆà¸­à¸‡à¸§à¹ˆà¸²à¸‡à¸ˆà¸£à¸´à¸‡à¸—à¸µà¹ˆà¹ƒà¸«à¸à¹ˆà¸ªà¸¸à¸”à¸—à¸µà¹ˆà¹€à¸«à¸¥à¸·à¸­
   à¹„à¸¡à¹ˆà¸–à¸·à¸­à¸§à¸±à¸™à¸—à¸µà¹ˆ à¸£à¸– à¸«à¸£à¸·à¸­à¸‹à¸µà¸¥ à¹€à¸žà¸£à¸²à¸°à¸ªà¸²à¸¢à¸ªà¹ˆà¸‡à¸«à¸™à¸¶à¹ˆà¸‡à¸–à¸¹à¸à¸§à¸´à¹ˆà¸‡à¸‹à¹‰à¸³à¹„à¸”à¹‰à¸—à¸¸à¸à¸§à¸±à¸™
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ROUTE](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NULL,
    [ROUTE]         [nvarchar](20)  NOT NULL,   -- à¸Šà¸·à¹ˆà¸­à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸šà¸—à¸µà¹ˆà¸•à¸²à¸£à¸²à¸‡à¸­à¸·à¹ˆà¸™à¹ƒà¸Šà¹‰à¸­à¹‰à¸²à¸‡
    [ROUTENAME]     [nvarchar](200) NOT NULL,
    [DESCRIPTION]   [nvarchar](250) NULL,
    [ORIGIN_WHSEID] [nvarchar](30)  NULL,       -- DC à¸—à¸µà¹ˆà¸£à¸–à¸­à¸­à¸
    [COLOURHEX]     [nvarchar](7)   NULL,       -- à¸ªà¸µà¹€à¸ªà¹‰à¸™à¸šà¸™à¹à¸œà¸™à¸—à¸µà¹ˆ
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
   2 Â· ~~MST_DELIVERY_ZONE~~ â€” à¹„à¸¡à¹ˆà¸•à¹‰à¸­à¸‡à¸ªà¸£à¹‰à¸²à¸‡ à¸à¸²à¸™à¸¡à¸µà¹à¸¥à¹‰à¸§à¸•à¸±à¹‰à¸‡à¹à¸•à¹ˆ R03

   R02 à¹„à¸¡à¹ˆà¸¡à¸µà¸•à¸²à¸£à¸²à¸‡à¹‚à¸‹à¸™à¸ˆà¸±à¸”à¸ªà¹ˆà¸‡ à¸ˆà¸¶à¸‡à¹€à¸„à¸¢à¹€à¸ªà¸™à¸­ `MST_DELIVERY_ZONE` à¹„à¸§à¹‰à¸•à¸£à¸‡à¸™à¸µà¹‰
   **R03 à¹€à¸žà¸´à¹ˆà¸¡ `MST_TRANSPORTATIONZONE` à¸¡à¸²à¹à¸¥à¹‰à¸§** à¹à¸¥à¸°à¸—à¸³à¸«à¸™à¹‰à¸²à¸—à¸µà¹ˆà¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸™:

       PK (WHSEID, OWNERKEY, TRANSPORTZONEKEY)
       TRANSPORTZONENAME Â· DESCRIPTION Â· COUNTRY Â· REGION
       PROVINCE Â· DISTRICT Â· POSTALCODE_FROM Â· POSTALCODE_TO
       DELIVERYLEADDAY Â· DEFAULTROUTE Â· PRIORITY Â· STATUS

   à¹à¸¥à¸° `MST_SHIPTO` à¸à¹‡à¹„à¸”à¹‰à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ `TRANSPORTZONEKEY` à¸¡à¸²à¸Šà¸µà¹‰à¸à¸¥à¸±à¸šà¸«à¸²à¹à¸¥à¹‰à¸§ â†’ à¸›à¸±à¸à¸«à¸²
   "à¸ˆà¸±à¸”à¹‚à¸‹à¸™à¹ƒà¸«à¹‰à¹ƒà¸šà¸ªà¸±à¹ˆà¸‡à¸ªà¹ˆà¸‡à¹„à¸¡à¹ˆà¹„à¸”à¹‰" à¸—à¸µà¹ˆ README à¸«à¸±à¸§à¸‚à¹‰à¸­ 2.4 à¸šà¸­à¸à¹„à¸§à¹‰ à¸–à¸¹à¸à¹à¸à¹‰à¹„à¸›à¸„à¸£à¸¶à¹ˆà¸‡à¸«à¸™à¸¶à¹ˆà¸‡
   à¸ªà¸£à¹‰à¸²à¸‡à¸•à¸²à¸£à¸²à¸‡à¸‹à¹‰à¸³à¸­à¸µà¸à¹ƒà¸šà¸¡à¸µà¹à¸•à¹ˆà¸ˆà¸°à¹„à¸”à¹‰à¹‚à¸‹à¸™à¸ªà¸­à¸‡à¸Šà¸¸à¸”à¸—à¸µà¹ˆà¹„à¸¡à¹ˆà¸•à¸£à¸‡à¸à¸±à¸™ à¸ˆà¸¶à¸‡à¸•à¸±à¸”à¸­à¸­à¸

   à¸—à¸µà¹ˆà¸¢à¸±à¸‡à¸‚à¸²à¸”: à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¹€à¸à¹‡à¸š **à¸«à¸™à¸¶à¹ˆà¸‡à¹‚à¸‹à¸™à¸•à¹ˆà¸­à¸«à¸™à¸¶à¹ˆà¸‡à¸à¸Žà¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆ** (PROVINCE/DISTRICT
   à¸«à¸£à¸·à¸­à¸Šà¹ˆà¸§à¸‡ POSTALCODE à¸Šà¸¸à¸”à¹€à¸”à¸µà¸¢à¸§) à¹€à¸žà¸£à¸²à¸° PK à¹„à¸¡à¹ˆà¸¡à¸µà¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸”à¹‰à¸§à¸¢
   à¹‚à¸‹à¸™à¸—à¸µà¹ˆà¸à¸´à¸™à¸«à¸¥à¸²à¸¢à¸ˆà¸±à¸‡à¸«à¸§à¸±à¸”à¸«à¸£à¸·à¸­à¸«à¸¥à¸²à¸¢à¸Šà¹ˆà¸§à¸‡à¹„à¸›à¸£à¸©à¸“à¸µà¸¢à¹Œà¸ˆà¸¶à¸‡à¹€à¸‚à¸µà¸¢à¸™à¸¥à¸‡à¹„à¸›à¹„à¸¡à¹ˆà¹„à¸”à¹‰ â†’
   `MST_ZONE_COVERAGE` à¹ƒà¸™à¸«à¸±à¸§à¸‚à¹‰à¸­ 3 à¸¡à¸²à¹€à¸•à¸´à¸¡à¸ªà¹ˆà¸§à¸™à¸™à¸±à¹‰à¸™

   à¸ªà¸­à¸‡à¸­à¸¢à¹ˆà¸²à¸‡à¸—à¸µà¹ˆà¹€à¸ªà¸™à¸­à¹„à¸§à¹‰à¹à¸•à¹ˆ `MST_TRANSPORTATIONZONE` à¹„à¸¡à¹ˆà¸¡à¸µ à¹à¸¥à¸° **à¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¹€à¸•à¸´à¸¡à¹ƒà¸«à¹‰**
   à¹€à¸žà¸£à¸²à¸°à¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¸¡à¸µà¸ˆà¸­à¹„à¸«à¸™à¹ƒà¸Šà¹‰: `MAX_VEHICLE_WEIGHT` (à¸™à¹‰à¸³à¸«à¸™à¸±à¸à¸£à¸–à¸ªà¸¹à¸‡à¸ªà¸¸à¸”à¸—à¸µà¹ˆà¹€à¸‚à¹‰à¸²à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¹„à¸”à¹‰
   â€” à¸ªà¸°à¸žà¸²à¸™ à¸‹à¸­à¸¢à¹à¸„à¸š à¹€à¸‚à¸•à¸«à¹‰à¸²à¸¡à¸£à¸–à¸šà¸£à¸£à¸—à¸¸à¸) à¸à¸±à¸š `SERVICE_MINUTE` à¸•à¹ˆà¸­à¹‚à¸‹à¸™
   à¸–à¹‰à¸²à¸ˆà¸°à¹ƒà¸Šà¹‰à¸ˆà¸£à¸´à¸‡ à¹ƒà¸«à¹‰à¹€à¸žà¸´à¹ˆà¸¡à¹€à¸›à¹‡à¸™ ALTER à¹ƒà¸™à¹„à¸Ÿà¸¥à¹Œ 02 à¸ªà¹ˆà¸§à¸™ C à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆà¸ªà¸£à¹‰à¸²à¸‡à¸•à¸²à¸£à¸²à¸‡à¹ƒà¸«à¸¡à¹ˆ
----------------------------------------------------------------------------- */

/* -----------------------------------------------------------------------------
   3 Â· MST_ZONE_COVERAGE â€” à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¸—à¸µà¹ˆà¹‚à¸‹à¸™à¸«à¸™à¸¶à¹ˆà¸‡à¸„à¸£à¸­à¸šà¸„à¸¥à¸¸à¸¡
   à¸—à¸³à¹ƒà¸«à¹‰à¸ˆà¸±à¸”à¹‚à¸‹à¸™à¹ƒà¸«à¹‰à¹ƒà¸šà¸ªà¸±à¹ˆà¸‡à¸ªà¹ˆà¸‡à¸—à¸µà¹ˆà¹„à¸«à¸¥à¹€à¸‚à¹‰à¸²à¸¡à¸²à¹„à¸”à¹‰à¹€à¸­à¸‡ à¹‚à¸”à¸¢à¹à¸¡à¸›à¸ˆà¸²à¸à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡
   MST_SHIPTO à¹€à¸à¹‡à¸šà¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¹à¸šà¸šà¸•à¸°à¸§à¸±à¸™à¸•à¸ (city/state/zip) à¸ªà¹ˆà¸§à¸™ DOC_SHIPMENT_STOP
   à¹€à¸à¹‡à¸šà¹à¸šà¸šà¹„à¸—à¸¢ (SUBDISTRICT/DISTRICT/PROVINCE/POSTALCODE) â€” POSTALCODE à¸„à¸·à¸­
   à¸•à¸±à¸§à¸—à¸µà¹ˆà¹à¸¡à¸›à¹„à¸”à¹‰à¹à¸™à¹ˆà¸™à¸­à¸™à¸—à¸µà¹ˆà¸ªà¸¸à¸” à¸ˆà¸¶à¸‡à¹€à¸›à¹‡à¸™à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸—à¸µà¹ˆà¸„à¸§à¸£à¹ƒà¸Šà¹‰à¹€à¸›à¹‡à¸™à¸à¸¸à¸à¹à¸ˆà¸«à¸¥à¸±à¸

   à¸¥à¸¹à¸à¸‚à¸­à¸‡ MST_TRANSPORTATIONZONE à¸—à¸µà¹ˆà¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¹à¸¥à¹‰à¸§ à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆà¸•à¸²à¸£à¸²à¸‡à¹‚à¸‹à¸™à¹ƒà¸šà¹ƒà¸«à¸¡à¹ˆ â€” à¸•à¸±à¸§à¹à¸¡à¹ˆ
   à¸–à¸·à¸­à¹„à¸”à¹‰à¸à¸Žà¹€à¸”à¸µà¸¢à¸§ à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¸–à¸·à¸­à¹„à¸”à¹‰à¸«à¸¥à¸²à¸¢à¸à¸Žà¸•à¹ˆà¸­à¹‚à¸‹à¸™

   âš  à¸ªà¸­à¸‡à¸—à¸µà¹ˆà¸—à¸µà¹ˆà¸šà¸­à¸à¸žà¸·à¹‰à¸™à¸—à¸µà¹ˆà¸‚à¸­à¸‡à¹‚à¸‹à¸™à¹„à¸”à¹‰ à¸•à¹‰à¸­à¸‡à¹€à¸¥à¸·à¸­à¸à¹ƒà¸«à¹‰à¸Šà¸±à¸”à¸§à¹ˆà¸²à¸­à¹ˆà¸²à¸™à¸ˆà¸²à¸à¸—à¸µà¹ˆà¹„à¸«à¸™
     `MST_TRANSPORTATIONZONE.PROVINCE/DISTRICT/POSTALCODE_FROM/TO` à¸¡à¸µà¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¸­à¸¢à¸¹à¹ˆ
     à¹à¸¥à¹‰à¸§à¹ƒà¸™à¸à¸²à¸™à¸ˆà¸£à¸´à¸‡ à¸–à¹‰à¸²à¸£à¸±à¸šà¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¹€à¸‚à¹‰à¸²à¸¡à¸² à¹ƒà¸«à¹‰à¸–à¸·à¸­à¸§à¹ˆà¸²à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸šà¸™à¸•à¸±à¸§à¹à¸¡à¹ˆà¹€à¸›à¹‡à¸™ *à¸„à¹ˆà¸²à¸—à¸µà¹ˆà¹à¸ªà¸”à¸‡
     à¸šà¸™à¸«à¸™à¹‰à¸²à¸ˆà¸­ master* à¸ªà¹ˆà¸§à¸™à¸à¸²à¸£ **à¸„à¹‰à¸™à¸§à¹ˆà¸²à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸™à¸µà¹‰à¸­à¸¢à¸¹à¹ˆà¹‚à¸‹à¸™à¹„à¸«à¸™ à¹ƒà¸«à¹‰à¸­à¹ˆà¸²à¸™à¸ˆà¸²à¸à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰
     à¸—à¸µà¹ˆà¹€à¸”à¸µà¸¢à¸§** à¹à¸¥à¹‰à¸§ migrate à¸„à¹ˆà¸²à¸šà¸™à¸•à¸±à¸§à¹à¸¡à¹ˆà¸¥à¸‡à¸¡à¸²à¹€à¸›à¹‡à¸™à¹à¸–à¸§à¹à¸£à¸à¸‚à¸­à¸‡à¹à¸•à¹ˆà¸¥à¸°à¹‚à¸‹à¸™
     (à¸”à¸¹à¸ªà¸„à¸£à¸´à¸›à¸•à¹Œà¸—à¹‰à¸²à¸¢à¸«à¸±à¸§à¸‚à¹‰à¸­à¸™à¸µà¹‰) â€” à¸•à¹‰à¸­à¸‡à¸¢à¸·à¸™à¸¢à¸±à¸™à¸à¸±à¸šà¸—à¸µà¸¡à¸—à¸µà¹ˆà¸”à¸¹à¹à¸¥à¸à¸²à¸™à¸à¹ˆà¸­à¸™
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ZONE_COVERAGE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    /* à¸ªà¸²à¸¡à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸™à¸µà¹‰à¸„à¸·à¸­ PK à¸‚à¸­à¸‡ MST_TRANSPORTATIONZONE à¸•à¹‰à¸­à¸‡à¸¡à¸µà¸„à¸£à¸šà¸–à¸¶à¸‡à¸ˆà¸°à¸œà¸¹à¸ FK à¹„à¸”à¹‰
       OWNERKEY à¹€à¸›à¹‡à¸™ nvarchar(20) à¸•à¸²à¸¡à¸•à¸±à¸§à¹à¸¡à¹ˆ à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆ 15 à¸­à¸¢à¹ˆà¸²à¸‡à¸—à¸µà¹ˆà¸­à¸µà¸ 16 à¸•à¸²à¸£à¸²à¸‡à¹ƒà¸Šà¹‰ â€”
       à¸„à¸§à¸²à¸¡à¹„à¸¡à¹ˆà¸•à¸£à¸‡à¸à¸±à¸™à¸™à¸µà¹‰à¹€à¸›à¹‡à¸™à¸‚à¸­à¸‡à¸à¸²à¸™à¹€à¸”à¸´à¸¡ à¸”à¸¹ README à¸«à¸±à¸§à¸‚à¹‰à¸­ 2.10 */
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

/* à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸«à¸™à¸¶à¹ˆà¸‡à¸•à¹‰à¸­à¸‡à¸•à¸à¸­à¸¢à¸¹à¹ˆà¹ƒà¸™à¹‚à¸‹à¸™à¹€à¸”à¸µà¸¢à¸§ à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆà¸ªà¸­à¸‡à¹‚à¸‹à¸™ â€” à¹„à¸¡à¹ˆà¸‡à¸±à¹‰à¸™à¸à¸²à¸£à¸ˆà¸±à¸”à¹‚à¸‹à¸™à¸­à¸±à¸•à¹‚à¸™à¸¡à¸±à¸•à¸´
   à¸•à¹‰à¸­à¸‡à¹€à¸”à¸² à¸”à¸±à¸Šà¸™à¸µà¸™à¸µà¹‰à¸à¸±à¸™à¹„à¸§à¹‰à¸•à¸±à¹‰à¸‡à¹à¸•à¹ˆà¸£à¸°à¸”à¸±à¸šà¸à¸²à¸™
   à¸‚à¸­à¸šà¹€à¸‚à¸•à¸„à¸§à¸²à¸¡à¹„à¸¡à¹ˆà¸‹à¹‰à¸³à¸„à¸·à¸­ *à¸•à¹ˆà¸­à¸„à¸¥à¸±à¸‡* à¹€à¸žà¸£à¸²à¸°à¸„à¸™à¸¥à¸°à¸„à¸¥à¸±à¸‡à¹à¸šà¹ˆà¸‡à¹‚à¸‹à¸™à¸„à¸™à¸¥à¸°à¹à¸šà¸šà¹„à¸”à¹‰
   NULL à¹ƒà¸™ SQL Server à¸–à¸·à¸­à¸§à¹ˆà¸²à¹€à¸—à¹ˆà¸²à¸à¸±à¸™à¹ƒà¸™à¸”à¸±à¸Šà¸™à¸µ unique â†’ à¸à¸Žà¹à¸šà¸šà¸„à¸£à¸­à¸šà¸—à¸±à¹‰à¸‡à¸ˆà¸±à¸‡à¸«à¸§à¸±à¸”
   (DISTRICT/SUBDISTRICT/POSTALCODE à¹€à¸›à¹‡à¸™ NULL) à¸¡à¸µà¹„à¸”à¹‰à¸ˆà¸±à¸‡à¸«à¸§à¸±à¸”à¸¥à¸°à¹à¸–à¸§à¹€à¸”à¸µà¸¢à¸§ à¸‹à¸¶à¹ˆà¸‡à¸–à¸¹à¸à¸•à¹‰à¸­à¸‡ */
CREATE UNIQUE INDEX [UX_MST_ZONE_COVERAGE_AREA]
    ON [dbo].[MST_ZONE_COVERAGE] ([WHSEID], [PROVINCE], [DISTRICT], [SUBDISTRICT], [POSTALCODE])
GO
CREATE INDEX [IX_MST_ZONE_COVERAGE_POSTALCODE]
    ON [dbo].[MST_ZONE_COVERAGE] ([POSTALCODE]) INCLUDE ([TRANSPORTZONEKEY])
GO

/* à¸¢à¹‰à¸²à¸¢à¸à¸Žà¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¸šà¸™à¸•à¸±à¸§à¹à¸¡à¹ˆà¸¥à¸‡à¸¡à¸²à¹€à¸›à¹‡à¸™à¹à¸–à¸§à¹à¸£à¸à¸‚à¸­à¸‡à¹à¸•à¹ˆà¸¥à¸°à¹‚à¸‹à¸™ â€” à¸£à¸±à¸™à¸„à¸£à¸±à¹‰à¸‡à¹€à¸”à¸µà¸¢à¸§à¸«à¸¥à¸±à¸‡à¸£à¸±à¸šà¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰
   à¹€à¸‰à¸žà¸²à¸°à¹‚à¸‹à¸™à¸—à¸µà¹ˆà¸£à¸°à¸šà¸¸à¸ˆà¸±à¸‡à¸«à¸§à¸±à¸”à¹„à¸§à¹‰ à¸ªà¹ˆà¸§à¸™à¹‚à¸‹à¸™à¸—à¸µà¹ˆà¹ƒà¸Šà¹‰à¹à¸•à¹ˆà¸Šà¹ˆà¸§à¸‡à¹„à¸›à¸£à¸©à¸“à¸µà¸¢à¹Œà¸•à¹‰à¸­à¸‡à¸à¸²à¸‡à¹€à¸›à¹‡à¸™à¸£à¸²à¸¢à¸£à¸«à¸±à¸ªà¹€à¸­à¸‡
   à¸‹à¸¶à¹ˆà¸‡à¸à¸²à¸‡à¸­à¸±à¸•à¹‚à¸™à¸¡à¸±à¸•à¸´à¹„à¸¡à¹ˆà¹„à¸”à¹‰ (à¸Šà¹ˆà¸§à¸‡ 10110-10240 à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¹à¸›à¸¥à¸§à¹ˆà¸²à¸—à¸¸à¸à¹€à¸¥à¸‚à¹ƒà¸™à¸Šà¹ˆà¸§à¸‡à¸¡à¸µà¸ˆà¸£à¸´à¸‡)
   à¸•à¸£à¸§à¸ˆà¸œà¸¥à¸à¹ˆà¸­à¸™ commit */
-- INSERT INTO dbo.MST_ZONE_COVERAGE
--       (WHSEID, OWNERKEY, TRANSPORTZONEKEY, PROVINCE, DISTRICT, POSTALCODE, STATUS, ADDWHO)
-- SELECT z.WHSEID, z.OWNERKEY, z.TRANSPORTZONEKEY, z.PROVINCE, z.DISTRICT,
--        CASE WHEN z.POSTALCODE_FROM = z.POSTALCODE_TO THEN z.POSTALCODE_FROM END,
--        'ACTIVE', SUSER_SNAME()
-- FROM   dbo.MST_TRANSPORTATIONZONE z
-- WHERE  z.PROVINCE IS NOT NULL;

/* -----------------------------------------------------------------------------
   4 Â· MST_ROUTE_ZONE â€” à¸ªà¸²à¸¢à¸ªà¹ˆà¸‡ â†” à¹‚à¸‹à¸™ à¸žà¸£à¹‰à¸­à¸¡à¸¥à¸³à¸”à¸±à¸šà¸à¸²à¸£à¸§à¸´à¹ˆà¸‡
   MST_TRANSPORTER_ROUTE à¸—à¸µà¹ˆà¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¸•à¸­à¸šà¸§à¹ˆà¸² "à¸œà¸¹à¹‰à¹ƒà¸«à¹‰à¸šà¸£à¸´à¸à¸²à¸£à¸£à¸²à¸¢à¹„à¸«à¸™à¸§à¸´à¹ˆà¸‡à¸ªà¸²à¸¢à¹„à¸«à¸™"
   à¹à¸•à¹ˆà¹„à¸¡à¹ˆà¸¡à¸µà¸—à¸µà¹ˆà¹„à¸«à¸™à¸•à¸­à¸šà¸§à¹ˆà¸² "à¸ªà¸²à¸¢à¸ªà¹ˆà¸‡à¸«à¸™à¸¶à¹ˆà¸‡à¸„à¸£à¸­à¸šà¸„à¸¥à¸¸à¸¡à¹‚à¸‹à¸™à¸­à¸°à¹„à¸£ à¸¥à¸³à¸”à¸±à¸šà¹„à¸«à¸™"
   (à¹à¸¥à¸° PK à¸‚à¸­à¸‡à¸•à¸²à¸£à¸²à¸‡à¸™à¸±à¹‰à¸™à¹€à¸›à¹‡à¸™ TRANSPORTERKEY+ROUTE à¸—à¸³à¹ƒà¸«à¹‰à¹à¸•à¸à¹€à¸›à¹‡à¸™à¸£à¸²à¸¢à¹‚à¸‹à¸™à¹„à¸¡à¹ˆà¹„à¸”à¹‰)

   à¹„à¸¡à¹ˆà¸¡à¸µà¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ "à¸ªà¸²à¸¢à¸«à¸¥à¸±à¸à¸‚à¸­à¸‡à¹‚à¸‹à¸™" à¹ƒà¸™à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰ à¹€à¸žà¸£à¸²à¸°
   `MST_TRANSPORTATIONZONE.DEFAULTROUTE` à¸–à¸·à¸­à¸­à¸¢à¸¹à¹ˆà¹à¸¥à¹‰à¸§à¸•à¸±à¹‰à¸‡à¹à¸•à¹ˆ R03 â€” à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¸•à¸­à¸š
   à¹à¸„à¹ˆà¸§à¹ˆà¸² *à¸ªà¸²à¸¢à¹„à¸«à¸™à¸œà¹ˆà¸²à¸™à¹‚à¸‹à¸™à¹„à¸«à¸™ à¸¥à¸³à¸”à¸±à¸šà¸—à¸µà¹ˆà¹€à¸—à¹ˆà¸²à¹„à¸«à¸£à¹ˆ* à¹ƒà¸«à¹‰à¸¡à¸µà¸„à¸³à¸•à¸­à¸šà¹€à¸”à¸µà¸¢à¸§à¸•à¹ˆà¸­à¸„à¸³à¸–à¸²à¸¡à¹€à¸”à¸µà¸¢à¸§
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_ROUTE_ZONE](
    [SERIALKEY]    [int] IDENTITY(1,1) NOT NULL,
    [ROUTE]        [nvarchar](20) NOT NULL,
    /* à¸ªà¸²à¸¡à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸•à¸²à¸¡ PK à¸‚à¸­à¸‡ MST_TRANSPORTATIONZONE à¹€à¸«à¸¡à¸·à¸­à¸™à¹ƒà¸™ MST_ZONE_COVERAGE */
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

/* à¸¥à¸³à¸”à¸±à¸šà¸à¸²à¸£à¸§à¸´à¹ˆà¸‡à¸«à¹‰à¸²à¸¡à¸‹à¹‰à¸³à¹ƒà¸™à¸ªà¸²à¸¢à¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸™ â€” à¹„à¸¡à¹ˆà¸‡à¸±à¹‰à¸™à¹„à¸¡à¹ˆà¸£à¸¹à¹‰à¸§à¹ˆà¸²à¹‚à¸‹à¸™à¹„à¸«à¸™à¸à¹ˆà¸­à¸™ */
CREATE UNIQUE INDEX [UX_MST_ROUTE_ZONE_SEQ]
    ON [dbo].[MST_ROUTE_ZONE] ([ROUTE], [SEQUENCE])
GO

/* -----------------------------------------------------------------------------
   5 Â· DOC_TRANSPORT_PLAN / _LINE â€” à¸Šà¸±à¹‰à¸™à¹à¸œà¸™à¸‚à¸™à¸ªà¹ˆà¸‡ PL-â€¦
   à¸£à¸°à¸šà¸šà¸§à¸²à¸‡à¹à¸œà¸™à¸à¹ˆà¸­à¸™à¹à¸¥à¹‰à¸§à¸„à¹ˆà¸­à¸¢à¸­à¸­à¸à¹ƒà¸šà¸›à¸´à¸”à¸šà¸£à¸£à¸—à¸¸à¸ à¹à¸•à¹ˆà¸à¸²à¸™à¸¡à¸µà¹à¸•à¹ˆà¸Šà¸±à¹‰à¸™à¹ƒà¸šà¸›à¸´à¸”à¸šà¸£à¸£à¸—à¸¸à¸
   à¹à¸œà¸™à¹„à¸¡à¹ˆà¸–à¸·à¸­à¸£à¸– à¸„à¸™à¸‚à¸±à¸š à¸«à¸£à¸·à¸­à¸‹à¸µà¸¥ à¹€à¸žà¸£à¸²à¸°à¸à¸²à¸£à¸§à¸²à¸‡à¹à¸œà¸™à¸•à¸­à¸šà¸§à¹ˆà¸² *à¸­à¸°à¹„à¸£à¹„à¸›à¸”à¹‰à¸§à¸¢à¸à¸±à¸™*
   à¸ªà¹ˆà¸§à¸™à¸œà¸¹à¹‰à¸ˆà¸±à¸”à¸£à¸–à¸•à¸­à¸šà¸§à¹ˆà¸² *à¹„à¸›à¸”à¹‰à¸§à¸¢à¸­à¸°à¹„à¸£* à¸•à¸­à¸™à¹à¸à¹‰à¹ƒà¸šà¸›à¸´à¸”à¸šà¸£à¸£à¸—à¸¸à¸

   à¸à¸Ž "à¸‚à¸­à¸‡à¸­à¸¢à¸¹à¹ˆà¹„à¸”à¹‰à¸—à¸µà¹ˆà¹€à¸”à¸µà¸¢à¸§": à¹ƒà¸šà¸ªà¸±à¹ˆà¸‡à¸ªà¹ˆà¸‡à¸«à¸™à¸¶à¹ˆà¸‡à¹ƒà¸šà¸­à¸¢à¸¹à¹ˆà¹ƒà¸™à¸„à¸´à¸§ à¸«à¸£à¸·à¸­à¹ƒà¸™à¹à¸œà¸™ à¸«à¸£à¸·à¸­à¸šà¸™
   à¹ƒà¸šà¸›à¸´à¸”à¸šà¸£à¸£à¸—à¸¸à¸ à¸­à¸¢à¹ˆà¸²à¸‡à¹ƒà¸”à¸­à¸¢à¹ˆà¸²à¸‡à¹€à¸”à¸µà¸¢à¸§ UNIQUE à¸šà¸™ ORDERKEY à¸‚à¸­à¸‡à¸šà¸£à¸£à¸—à¸±à¸”à¹à¸œà¸™à¸šà¸±à¸‡à¸„à¸±à¸š
   à¸„à¸£à¸¶à¹ˆà¸‡à¹à¸£à¸ à¸­à¸µà¸à¸„à¸£à¸¶à¹ˆà¸‡à¸­à¸¢à¸¹à¹ˆà¹ƒà¸™ 02-alter-existing.sql
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_TRANSPORT_PLAN](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NOT NULL,
    [PLANKEY]       [nvarchar](30)  NOT NULL,   -- PL-202608-0007
    [PLANDATE]      [datetime]      NOT NULL,
    [DELIVERYDATE]  [date]          NOT NULL,   -- à¸§à¸±à¸™à¸—à¸µà¹ˆà¸™à¸±à¸”à¸ªà¹ˆà¸‡ à¸„à¸™à¸¥à¸°à¸§à¸±à¸™à¸à¸±à¸š PLANDATE
    [ZONE]          [nvarchar](20)  NULL,
    [ROUTE]         [nvarchar](20)  NULL,
    [SHIPMENTKEY]   [nvarchar](30)  NULL,       -- à¹ƒà¸šà¸›à¸´à¸”à¸šà¸£à¸£à¸—à¸¸à¸à¸—à¸µà¹ˆà¸­à¸­à¸à¸ˆà¸²à¸à¹à¸œà¸™à¸™à¸µà¹‰
    [TOTALORDER]    [int]            NULL,
    [TOTALWEIGHT]   [decimal](22, 5) NULL,
    [TOTALCUBE]     [decimal](22, 5) NULL,
    [STATUS]        [nvarchar](20)  NOT NULL,   -- DRAFT | ISSUED | CANCELLED
    [CANCELREASON]  [nvarchar](500) NULL,       -- à¹„à¸¡à¹ˆà¸šà¸±à¸‡à¸„à¸±à¸šà¸à¸£à¸­à¸
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
/* ZONE à¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¸¡à¸µ FK â€” à¸”à¸¹à¸«à¸¡à¸²à¸¢à¹€à¸«à¸•à¸¸ "à¸—à¸³à¹„à¸¡à¹‚à¸‹à¸™à¸–à¸¶à¸‡à¸¢à¸±à¸‡à¸œà¸¹à¸ FK à¹„à¸¡à¹ˆà¹„à¸”à¹‰" à¸—à¹‰à¸²à¸¢à¹„à¸Ÿà¸¥à¹Œà¸™à¸µà¹‰
   à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸•à¸±à¹‰à¸‡à¸Šà¸·à¹ˆà¸­à¸§à¹ˆà¸² ZONE à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆ TRANSPORTZONEKEY à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¸•à¸£à¸‡à¸à¸±à¸š
   DOC_SHIPMENT_HDR.ZONE / DOC_SHIPMENT_DETAIL.ZONE à¸—à¸µà¹ˆà¹à¸œà¸™à¸™à¸µà¹‰à¸­à¸­à¸à¹ƒà¸šà¹„à¸›à¹ƒà¸«à¹‰ */

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

/* à¹ƒà¸šà¸ªà¸±à¹ˆà¸‡à¸ªà¹ˆà¸‡à¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸™à¸­à¸¢à¸¹à¹ˆà¹ƒà¸™à¸ªà¸­à¸‡à¹à¸œà¸™à¸žà¸£à¹‰à¸­à¸¡à¸à¸±à¸™à¹„à¸¡à¹ˆà¹„à¸”à¹‰ (à¹à¸œà¸™à¸—à¸µà¹ˆà¸¢à¸à¹€à¸¥à¸´à¸à¹à¸¥à¹‰à¸§à¹„à¸¡à¹ˆà¸™à¸±à¸š) */
CREATE UNIQUE INDEX [UX_DOC_TRANSPORT_PLAN_LINE_ORDER]
    ON [dbo].[DOC_TRANSPORT_PLAN_LINE] ([ORDERKEY]) WHERE [STATUS] <> 'CANCELLED'
GO

/* -----------------------------------------------------------------------------
   6 Â· DOC_SHIPMENT_STATUS_LOG
   à¸ˆà¸­à¸•à¸´à¸”à¸•à¸²à¸¡à¸ªà¸–à¸²à¸™à¸°à¸§à¸²à¸” timeline 5 à¸‚à¸±à¹‰à¸™ (à¸ªà¸£à¹‰à¸²à¸‡ â†’ à¸¢à¸·à¸™à¸¢à¸±à¸™ â†’ à¸ªà¹ˆà¸‡ MMX â†’ WMS à¸•à¸£à¸§à¸ˆ QC â†’
   SAP/OMS à¸•à¸­à¸šà¸à¸¥à¸±à¸š) à¹à¸•à¹ˆ DOC_SHIPMENT_HDR à¸¡à¸µ STATUS à¸Šà¹ˆà¸­à¸‡à¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸š ADDDATE/EDITDATE
   à¸ˆà¸¶à¸‡à¸šà¸­à¸à¹„à¸”à¹‰à¹à¸„à¹ˆ "à¸•à¸­à¸™à¸™à¸µà¹‰à¸­à¸¢à¸¹à¹ˆà¸‚à¸±à¹‰à¸™à¹„à¸«à¸™" à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆ "à¸–à¸¶à¸‡à¹à¸•à¹ˆà¸¥à¸°à¸‚à¸±à¹‰à¸™à¹€à¸¡à¸·à¹ˆà¸­à¹„à¸«à¸£à¹ˆ"
   à¹à¸¥à¸°à¹„à¸¡à¹ˆà¸¡à¸µà¸—à¸µà¹ˆà¹€à¸à¹‡à¸šà¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡à¸—à¸µà¹ˆ WMS/OMS à¸•à¸µà¸à¸¥à¸±à¸šà¸¡à¸² à¸‹à¸¶à¹ˆà¸‡à¹€à¸›à¹‡à¸™à¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡à¸—à¸µà¹ˆà¸œà¸¹à¹‰à¹ƒà¸Šà¹‰à¸•à¹‰à¸­à¸‡à¸­à¹ˆà¸²à¸™
   à¹€à¸žà¸·à¹ˆà¸­à¸£à¸¹à¹‰à¸§à¹ˆà¸²à¸•à¹‰à¸­à¸‡à¹à¸à¹‰à¸­à¸°à¹„à¸£
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_SHIPMENT_STATUS_LOG](
    [SERIALKEY]     [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]        [nvarchar](30)  NOT NULL,
    [SHIPMENTKEY]   [nvarchar](30)  NOT NULL,
    [FROMSTATUS]    [nvarchar](20)  NULL,
    [TOSTATUS]      [nvarchar](20)  NOT NULL,
    [SOURCESYSTEM]  [nvarchar](10)  NOT NULL,   -- TMS | OMS | MMX | WMS | SAP
    [MESSAGE]       [nvarchar](1000) NULL,      -- à¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡à¸—à¸µà¹ˆà¸£à¸°à¸šà¸šà¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡à¹à¸ˆà¹‰à¸‡à¸à¸¥à¸±à¸š
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
   7 Â· MST_CUSTOMER â€” à¸—à¸°à¹€à¸šà¸µà¸¢à¸™à¸¥à¸¹à¸à¸„à¹‰à¸²/à¸ˆà¸¸à¸”à¸ªà¹ˆà¸‡à¸‰à¸šà¸±à¸šà¸—à¸µà¹ˆà¹ƒà¸Šà¹‰à¸‡à¸²à¸™à¹„à¸”à¹‰
   MST_SHIPTO à¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¹à¸¥à¹‰à¸§ à¹à¸•à¹ˆà¹ƒà¸Šà¹‰à¹€à¸›à¹‡à¸™à¸•à¸²à¸£à¸²à¸‡à¹à¸¡à¹ˆà¹„à¸¡à¹ˆà¹„à¸”à¹‰à¸ˆà¸£à¸´à¸‡:
     - PK à¹€à¸›à¹‡à¸™ SERIALKEY à¹€à¸”à¸µà¹ˆà¸¢à¸§ à¹† Â· SHIPTO à¹„à¸¡à¹ˆà¸¡à¸µ unique â†’ FK à¸Šà¸µà¹‰à¸¡à¸²à¹„à¸¡à¹ˆà¹„à¸”à¹‰
     - à¸—à¸µà¹ˆà¸­à¸¢à¸¹à¹ˆà¹€à¸›à¹‡à¸™à¹à¸šà¸šà¸•à¸°à¸§à¸±à¸™à¸•à¸ (city / state / zip / county) à¹„à¸¡à¹ˆà¸¡à¸µ
       à¸•à¸³à¸šà¸¥/à¸­à¸³à¹€à¸ à¸­ à¸—à¸µà¹ˆà¸£à¸°à¸šà¸šà¹„à¸—à¸¢à¹ƒà¸Šà¹‰à¹à¸¡à¸›à¹‚à¸‹à¸™
     - à¸žà¸´à¸à¸±à¸”à¹€à¸à¹‡à¸šà¹€à¸›à¹‡à¸™à¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡à¸à¹‰à¸­à¸™à¹€à¸”à¸µà¸¢à¸§ gps1 nvarchar(200) à¸„à¸³à¸™à¸§à¸“à¸£à¸°à¸¢à¸°à¸—à¸²à¸‡à¹„à¸¡à¹ˆà¹„à¸”à¹‰
     - à¸Šà¸·à¹ˆà¸­à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ addr##1..addr##4 à¸¡à¸µ ## à¹à¸¥à¸°à¸œà¸¹à¸à¸à¸±à¸š user-defined type
   à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¸ˆà¸¶à¸‡à¹€à¸›à¹‡à¸™à¸•à¸±à¸§à¹ƒà¸«à¸¡à¹ˆà¸—à¸µà¹ˆ FK à¸Šà¸µà¹‰à¹„à¸”à¹‰ à¹à¸¥à¸°à¹ƒà¸«à¹‰ MST_SHIPTO à¸­à¸¢à¸¹à¹ˆà¸•à¹ˆà¸­à¹ƒà¸™à¸à¸²à¸™à¸°à¸‚à¹‰à¸­à¸¡à¸¹à¸¥
   à¹€à¸”à¸´à¸¡à¸‚à¸­à¸‡ WMS à¸ˆà¸™à¸à¸§à¹ˆà¸²à¸ˆà¸°à¸¢à¹‰à¸²à¸¢à¹€à¸ªà¸£à¹‡à¸ˆ (README à¸«à¸±à¸§à¸‚à¹‰à¸­ 3 à¸¡à¸µà¸ªà¸„à¸£à¸´à¸›à¸•à¹Œà¸¢à¹‰à¸²à¸¢à¸‚à¹‰à¸­à¸¡à¸¹à¸¥)
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[MST_CUSTOMER](
    [SERIALKEY]           [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]              [nvarchar](30)  NULL,
    [OWNERKEY]            [nvarchar](15)  NULL,
    [CUSTOMERKEY]         [nvarchar](30)  NOT NULL,  -- à¸•à¸£à¸‡à¸à¸±à¸š DOC_SHIPMENT_STOP.CUSTOMERKEY
    [SHIPTO]              [nvarchar](15)  NULL,      -- à¹€à¸¥à¸‚à¹€à¸”à¸´à¸¡à¹ƒà¸™ MST_SHIPTO à¹€à¸žà¸·à¹ˆà¸­à¸ªà¸­à¸šà¸¢à¹‰à¸­à¸™
    [CUSTOMERNAME]        [nvarchar](200) NOT NULL,
    [ADDRESS1]            [nvarchar](200) NULL,
    [ADDRESS2]            [nvarchar](200) NULL,
    [SUBDISTRICT]         [nvarchar](100) NULL,
    [DISTRICT]            [nvarchar](100) NULL,
    [PROVINCE]            [nvarchar](100) NULL,
    [POSTALCODE]          [nvarchar](10)  NULL,
    [COUNTRY]             [nvarchar](50)  NULL,
    /* decimal à¹„à¸¡à¹ˆà¹ƒà¸Šà¹ˆà¸‚à¹‰à¸­à¸„à¸§à¸²à¸¡ â€” à¹à¸¥à¸°à¸„à¸§à¸²à¸¡à¸¥à¸°à¹€à¸­à¸µà¸¢à¸”à¹€à¸—à¹ˆà¸²à¸à¸±à¸š DOC_SHIPMENT_STOP
       à¸—à¸µà¹ˆà¹ƒà¸Šà¹‰ decimal(18,10) à¸­à¸¢à¸¹à¹ˆà¹à¸¥à¹‰à¸§ à¹€à¸žà¸·à¹ˆà¸­à¹ƒà¸«à¹‰à¹€à¸—à¸µà¸¢à¸šà¸„à¹ˆà¸²à¸à¸±à¸™à¹„à¸”à¹‰à¸•à¸£à¸‡ */
    [LATITUDE]            [decimal](18, 10) NULL,
    [LONGITUDE]           [decimal](18, 10) NULL,
    /* à¹‚à¸‹à¸™à¸ˆà¸±à¸”à¸ªà¹ˆà¸‡ â€” à¸Šà¸·à¹ˆà¸­à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸•à¸²à¸¡ MST_SHIPTO.TRANSPORTZONEKEY à¸—à¸µà¹ˆ R03 à¹€à¸žà¸´à¹ˆà¸¡à¸¡à¸²
       à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¸œà¸¹à¸ FK à¹„à¸› MST_TRANSPORTATIONZONE à¹€à¸žà¸£à¸²à¸° PK à¸‚à¸­à¸‡à¸•à¸²à¸£à¸²à¸‡à¸™à¸±à¹‰à¸™à¸„à¸·à¸­
       (WHSEID, OWNERKEY, TRANSPORTZONEKEY) à¹à¸•à¹ˆà¸¥à¸¹à¸à¸„à¹‰à¸²à¸«à¸™à¸¶à¹ˆà¸‡à¸£à¸²à¸¢à¹„à¸¡à¹ˆà¸ˆà¸³à¹€à¸›à¹‡à¸™à¸•à¹‰à¸­à¸‡
       à¸œà¸¹à¸à¸à¸±à¸šà¸„à¸¥à¸±à¸‡à¹ƒà¸”à¸„à¸¥à¸±à¸‡à¸«à¸™à¸¶à¹ˆà¸‡ (WHSEID à¸—à¸µà¹ˆà¸™à¸µà¹ˆ NULL à¹„à¸”à¹‰) â†’ à¸šà¸±à¸‡à¸„à¸±à¸šà¸—à¸µà¹ˆ backend à¹à¸—à¸™
       à¸„à¹ˆà¸²à¹„à¸”à¹‰à¸¡à¸²à¸ˆà¸²à¸ POSTALCODE à¸œà¹ˆà¸²à¸™ MST_ZONE_COVERAGE */
    [TRANSPORTZONEKEY]    [nvarchar](20)  NULL,
    [ROUTE]               [nvarchar](20)  NULL,      -- à¸ªà¸²à¸¢à¸ªà¹ˆà¸‡à¸›à¸£à¸°à¸ˆà¸³ à¸–à¹‰à¸²à¸¡à¸µ
    [CONTACTNAME]         [nvarchar](100) NULL,
    [CONTACTPHONE]        [nvarchar](50)  NULL,
    [TIMEWINDOW_FROM]     [time](7)       NULL,      -- à¸Šà¸·à¹ˆà¸­à¹€à¸”à¸µà¸¢à¸§à¸à¸±à¸š DOC_SHIPMENT_STOP
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

/* à¸žà¸´à¸à¸±à¸”à¸•à¹‰à¸­à¸‡à¸¡à¸²à¹€à¸›à¹‡à¸™à¸„à¸¹à¹ˆ à¸„à¸£à¸¶à¹ˆà¸‡à¹€à¸”à¸µà¸¢à¸§à¸§à¸²à¸”à¹à¸œà¸™à¸—à¸µà¹ˆà¹„à¸¡à¹ˆà¹„à¸”à¹‰à¹à¸¥à¸°à¸„à¸³à¸™à¸§à¸“à¸£à¸°à¸¢à¸°à¸—à¸²à¸‡à¹„à¸¡à¹ˆà¹„à¸”à¹‰ */
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
   8 Â· DOC_DO_PICKHEADER â€” à¸«à¸±à¸§à¹ƒà¸šà¸ˆà¸±à¸”à¸ªà¸´à¸™à¸„à¹‰à¸²
   `DOC_DO_PICKDETAIL.PICKHEADERKEY nvarchar(18)` à¸­à¹‰à¸²à¸‡à¸–à¸¶à¸‡à¸•à¸²à¸£à¸²à¸‡à¸—à¸µà¹ˆ **à¹„à¸¡à¹ˆà¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¹ƒà¸™
   à¸à¸²à¸™à¹€à¸¥à¸¢** à¸œà¸¥à¸„à¸·à¸­à¸£à¸²à¸¢à¸à¸²à¸£à¹€à¸šà¸´à¸à¸¥à¸­à¸¢à¸­à¸¢à¸¹à¹ˆà¹‚à¸”à¸¢à¹„à¸¡à¹ˆà¸¡à¸µà¸«à¸±à¸§à¹€à¸­à¸à¸ªà¸²à¸£: à¸•à¸­à¸šà¹„à¸¡à¹ˆà¹„à¸”à¹‰à¸§à¹ˆà¸²à¹ƒà¸šà¸ˆà¸±à¸”à¸ªà¸´à¸™à¸„à¹‰à¸²
   à¹ƒà¸šà¸«à¸™à¸¶à¹ˆà¸‡à¸¡à¸µà¸ªà¸–à¸²à¸™à¸°à¸­à¸°à¹„à¸£ à¹ƒà¸„à¸£à¸–à¸·à¸­ à¸žà¸´à¸¡à¸žà¹Œà¹à¸¥à¹‰à¸§à¸«à¸£à¸·à¸­à¸¢à¸±à¸‡ à¸›à¸´à¸”à¹€à¸¡à¸·à¹ˆà¸­à¹„à¸«à¸£à¹ˆ â€” à¸ˆà¸­ "à¹ƒà¸šà¸„à¸¸à¸¡à¹€à¸šà¸´à¸à¸ªà¸´à¸™à¸„à¹‰à¸²"
   à¹à¸¥à¸°à¹€à¸¥à¸‚ PKL à¸—à¸µà¹ˆà¸žà¸´à¸¡à¸žà¹Œà¸„à¸¹à¹ˆà¸à¸±à¸š DO à¸—à¸¸à¸à¹ƒà¸šà¸•à¹‰à¸­à¸‡à¸­à¹ˆà¸²à¸™à¸ˆà¸²à¸à¸—à¸µà¹ˆà¸™à¸µà¹ˆ

   âš  à¸£à¸¹à¸›à¸£à¹ˆà¸²à¸‡à¸•à¸²à¸£à¸²à¸‡à¸™à¸µà¹‰à¸­à¸™à¸¸à¸¡à¸²à¸™à¸ˆà¸²à¸à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¹ƒà¸™ DOC_DO_PICKDETAIL (PICKHEADERKEY,
     WAVEKEY, PICKMETHOD, ISCLOSED, QCSTATUS, ASSIGNMENTNUMBER) â€” à¸•à¹‰à¸­à¸‡à¹ƒà¸«à¹‰à¸—à¸µà¸¡à¸—à¸µà¹ˆ
     à¸”à¸¹à¹à¸¥ WMS à¸¢à¸·à¸™à¸¢à¸±à¸™à¸à¹ˆà¸­à¸™à¹ƒà¸Šà¹‰ à¹€à¸žà¸£à¸²à¸°à¸­à¸²à¸ˆà¸¡à¸µà¸™à¸´à¸¢à¸²à¸¡à¹€à¸”à¸´à¸¡à¸­à¸¢à¸¹à¹ˆà¹ƒà¸™à¸£à¸°à¸šà¸šà¸­à¸·à¹ˆà¸™
----------------------------------------------------------------------------- */
CREATE TABLE [dbo].[DOC_DO_PICKHEADER](
    [SERIALKEY]           [int] IDENTITY(1,1) NOT NULL,
    [WHSEID]              [nvarchar](30) NOT NULL,
    [PICKHEADERKEY]       [nvarchar](18) NOT NULL,
    [ORDERKEY]            [nvarchar](50) NULL,   -- NULL à¹„à¸”à¹‰à¹€à¸žà¸£à¸²à¸° wave à¸£à¸§à¸¡à¸«à¸¥à¸²à¸¢à¹ƒà¸š
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
   9 Â· MST_USER / MST_USER_MODULE
   à¸à¸²à¸™à¹„à¸¡à¹ˆà¸¡à¸µà¸•à¸²à¸£à¸²à¸‡à¸œà¸¹à¹‰à¹ƒà¸Šà¹‰à¹€à¸¥à¸¢ à¹à¸•à¹ˆà¹à¸­à¸›à¸¡à¸µ login, role 4 à¸£à¸°à¸”à¸±à¸š à¹à¸¥à¸°à¸ˆà¸³à¸à¸±à¸”à¸ªà¸´à¸—à¸˜à¸´à¹Œ *à¸•à¸²à¸¡à¹‚à¸¡à¸”à¸¹à¸¥*
   (à¸šà¸±à¸à¸Šà¸µ tms@ à¹€à¸«à¹‡à¸™à¹à¸„à¹ˆ /logistics) à¸‹à¸¶à¹ˆà¸‡à¹€à¸›à¹‡à¸™à¸ªà¸­à¸‡à¹à¸à¸™à¹à¸¢à¸à¸à¸±à¸™: role à¸šà¸­à¸à¸§à¹ˆà¸²à¸—à¸³à¹„à¸”à¹‰à¸¡à¸²à¸
   à¹à¸„à¹ˆà¹„à¸«à¸™, module à¸šà¸­à¸à¸§à¹ˆà¸²à¸—à¸³à¸—à¸µà¹ˆà¹„à¸«à¸™à¹„à¸”à¹‰ â€” à¹„à¸¡à¹ˆà¸¡à¸µà¹à¸–à¸§à¹ƒà¸™ MST_USER_MODULE = à¹€à¸‚à¹‰à¸²à¹„à¸”à¹‰à¸—à¸¸à¸à¹‚à¸¡à¸”à¸¹à¸¥
   à¸„à¹ˆà¸² ROLECODE à¹à¸¥à¸° MODULEPATH à¸¥à¸­à¸à¸ˆà¸²à¸ USER_ROLES à¹à¸¥à¸° modules à¹ƒà¸™ src/constants
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
    [MODULEPATH] [nvarchar](50) NOT NULL,   -- /logistics Â· /inbound Â· /warehouse â€¦
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

/* =============================================================================
   à¸«à¸¡à¸²à¸¢à¹€à¸«à¸•à¸¸ Â· à¸—à¸³à¹„à¸¡à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ ZONE à¹ƒà¸™à¸•à¸²à¸£à¸²à¸‡à¹€à¸­à¸à¸ªà¸²à¸£à¸–à¸¶à¸‡à¸¢à¸±à¸‡à¸œà¸¹à¸ FK à¹„à¸¡à¹ˆà¹„à¸”à¹‰

   `MST_TRANSPORTATIONZONE` à¸¡à¸µ PK à¹€à¸›à¹‡à¸™à¸ªà¸²à¸¡à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ (WHSEID, OWNERKEY,
   TRANSPORTZONEKEY) à¹à¸•à¹ˆà¸•à¸²à¸£à¸²à¸‡à¹€à¸­à¸à¸ªà¸²à¸£à¸—à¸µà¹ˆà¸­à¹‰à¸²à¸‡à¹‚à¸‹à¸™ â€” `DOC_SHIPMENT_HDR.ZONE`,
   `DOC_SHIPMENT_DETAIL.ZONE`, `MST_TRANSPORT_RATE.ZONE`,
   `MST_TRANSPORTER_ROUTE.ZONE`, `DOC_TRANSPORT_PLAN.ZONE` â€” à¸¡à¸µà¹à¸„à¹ˆà¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¹€à¸”à¸µà¸¢à¸§
   FK à¸•à¹‰à¸­à¸‡à¸¡à¸µà¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¸„à¸£à¸šà¸•à¸²à¸¡ PK à¸›à¸¥à¸²à¸¢à¸—à¸²à¸‡ à¸ˆà¸¶à¸‡à¸œà¸¹à¸à¹„à¸¡à¹ˆà¹„à¸”à¹‰à¸•à¸²à¸¡à¸—à¸µà¹ˆà¹€à¸›à¹‡à¸™à¸­à¸¢à¸¹à¹ˆ

   à¸—à¸²à¸‡à¹à¸à¹‰à¸¡à¸µà¸ªà¸­à¸‡à¸—à¸²à¸‡ à¹€à¸¥à¸·à¸­à¸à¹„à¸”à¹‰à¸—à¸²à¸‡à¹€à¸”à¸µà¸¢à¸§ à¹à¸¥à¸°à¸•à¹‰à¸­à¸‡à¹ƒà¸«à¹‰à¸—à¸µà¸¡à¸—à¸µà¹ˆà¸”à¸¹à¹à¸¥à¸à¸²à¸™à¸•à¸±à¸”à¸ªà¸´à¸™

   à¸—à¸²à¸‡ 1 Â· à¸£à¸«à¸±à¸ªà¹‚à¸‹à¸™à¹€à¸›à¹‡à¸™ global (à¹à¸™à¸°à¸™à¸³à¸–à¹‰à¸²à¸‚à¹‰à¸­à¸¡à¸¹à¸¥à¸ˆà¸£à¸´à¸‡à¹€à¸›à¹‡à¸™à¹à¸šà¸šà¸™à¸±à¹‰à¸™)
   à¸–à¹‰à¸² TRANSPORTZONEKEY à¹„à¸¡à¹ˆà¹€à¸„à¸¢à¸‹à¹‰à¸³à¸‚à¹‰à¸²à¸¡à¸„à¸¥à¸±à¸‡/à¸‚à¹‰à¸²à¸¡à¹€à¸ˆà¹‰à¸²à¸‚à¸­à¸‡ à¸à¹‡à¹€à¸žà¸´à¹ˆà¸¡ unique index
   à¹à¸¥à¹‰à¸§ FK à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œà¹€à¸”à¸µà¸¢à¸§à¸ˆà¸°à¸œà¸¹à¸à¹„à¸”à¹‰à¸—à¸±à¹‰à¸‡à¸«à¸¡à¸” à¸•à¸£à¸§à¸ˆà¸à¹ˆà¸­à¸™à¸”à¹‰à¸§à¸¢ query à¸™à¸µà¹‰ à¸•à¹‰à¸­à¸‡à¹„à¸”à¹‰ 0 à¹à¸–à¸§:

     SELECT TRANSPORTZONEKEY, COUNT(*) AS n
     FROM   dbo.MST_TRANSPORTATIONZONE
     GROUP  BY TRANSPORTZONEKEY
     HAVING COUNT(*) > 1;

   à¹„à¸”à¹‰ 0 à¹à¸–à¸§à¹à¸¥à¹‰à¸§à¸„à¹ˆà¸­à¸¢à¸£à¸±à¸™:

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

   à¸—à¸²à¸‡ 2 Â· à¸£à¸«à¸±à¸ªà¹‚à¸‹à¸™à¸‹à¹‰à¸³à¸‚à¹‰à¸²à¸¡à¸„à¸¥à¸±à¸‡à¹„à¸”à¹‰
   à¸•à¹‰à¸­à¸‡à¹€à¸žà¸´à¹ˆà¸¡ OWNERKEY à¸¥à¸‡à¹ƒà¸™à¸•à¸²à¸£à¸²à¸‡à¹€à¸­à¸à¸ªà¸²à¸£à¸—à¸µà¹ˆà¸¢à¸±à¸‡à¹„à¸¡à¹ˆà¸¡à¸µ à¹à¸¥à¹‰à¸§à¸œà¸¹à¸ FK à¸ªà¸²à¸¡à¸„à¸­à¸¥à¸±à¸¡à¸™à¹Œ â€”
   à¹à¸•à¸°à¹‚à¸„à¸£à¸‡à¸ªà¸£à¹‰à¸²à¸‡à¹€à¸¢à¸­à¸°à¸à¸§à¹ˆà¸²à¸¡à¸²à¸ à¹à¸¥à¸°à¸•à¹‰à¸­à¸‡ backfill à¸„à¹ˆà¸²à¹€à¸”à¸´à¸¡ à¸„à¸§à¸£à¸—à¸³à¸à¹‡à¸•à¹ˆà¸­à¹€à¸¡à¸·à¹ˆà¸­ query
   à¸‚à¹‰à¸²à¸‡à¸šà¸™à¸„à¸·à¸™à¹à¸–à¸§à¸­à¸­à¸à¸¡à¸²à¸ˆà¸£à¸´à¸‡ à¹† à¹€à¸—à¹ˆà¸²à¸™à¸±à¹‰à¸™

   à¸ˆà¸™à¸à¸§à¹ˆà¸²à¸ˆà¸°à¹€à¸¥à¸·à¸­à¸à¹„à¸”à¹‰ **backend à¸•à¹‰à¸­à¸‡à¸•à¸£à¸§à¸ˆà¹€à¸­à¸‡à¸§à¹ˆà¸²à¹‚à¸‹à¸™à¸—à¸µà¹ˆà¸£à¸±à¸šà¹€à¸‚à¹‰à¸²à¸¡à¸²à¸¡à¸µà¸­à¸¢à¸¹à¹ˆà¸ˆà¸£à¸´à¸‡** â€”
   à¹„à¸¡à¹ˆà¸¡à¸µ constraint à¹„à¸«à¸™à¸à¸±à¸™à¹ƒà¸«à¹‰à¸­à¸¢à¸¹à¹ˆà¸•à¸­à¸™à¸™à¸µà¹‰
============================================================================= */
