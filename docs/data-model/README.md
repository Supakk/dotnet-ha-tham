# โมเดลข้อมูล MamMoD — สิ่งที่ต้องเพิ่มและแก้

เทียบ **schema จริง** (`MAMMOD_TABLE2_R02.sql`, ฐาน `MMPRD`) กับไดอะแกรม ER
และกับ data model ที่หน้าจอใช้จริงใน `src/features`

> สำเนามาจาก repo ฝั่ง frontend (`Mammod_FrontEnd/docs/data-model`) เพื่อให้
> backend ที่จะต่อฐานจริงอ่านได้จากที่เดียวกับโค้ด · path ที่อ้างถึง `src/…`
> ในเอกสารนี้หมายถึง repo ฝั่ง frontend ไม่ใช่ repo นี้ · **ในนี้ไม่มีข้อมูลจริง
> ไม่มี connection string และไม่มีรหัสผ่าน** มีแต่โครงสร้างตารางกับ query

| ไฟล์ | คืออะไร |
| --- | --- |
| [`er-transport-shipment.mmd`](./er-transport-shipment.mmd) | ER ฝั่งขนส่งตามของจริง + ที่เสนอเพิ่ม |
| [`er-wms-core.mmd`](./er-wms-core.mmd) | ER ฝั่งคลังตามของจริง |
| [`01-new-tables.sql`](./01-new-tables.sql) | **7 ตารางใหม่** ตามธรรมเนียมของฐานจริง |
| [`02-alter-existing.sql`](./02-alter-existing.sql) | PK ที่หายไป · float→decimal · คอลัมน์ที่ขาด · FK · ดัชนี · rowversion |

> เอกสารรอบแรกเขียนจากไดอะแกรมเท่านั้น จึงสรุปผิดหลายข้อ — หัวข้อ 1 คือ
> รายการที่ถอนคืน เก็บไว้เพื่อไม่ให้ใครหยิบข้อสรุปเก่าไปใช้ต่อ

## 1 · ข้อสรุปที่ถอนคืน (ไดอะแกรมไม่ตรงกับฐาน)

ของพวกนี้ **มีอยู่แล้วในฐานจริง** ต่างจากที่รอบแรกบอกว่าขาด

| เคยบอกว่าขาด | ความจริง |
| --- | --- |
| `MST_VENDOR` | มีอยู่ และละเอียดกว่าที่ร่างไว้ (`QC_REQUIRED`, `ASN_REQUIRED`, `LOT_REQUIRED`, `MFGDATE/EXPDATE_REQUIRED`, `OVERRECEIPT_PERCENT`, `MIN_SHELFLIFE_DAYS`) |
| ทะเบียนลูกค้า | มี `MST_SHIPTO` (แต่ใช้เป็นตารางแม่ไม่ได้ — ดูหัวข้อ 3) |
| lat/lng ที่จุดส่ง | `DOC_SHIPMENT_STOP.LATITUDE/LONGITUDE decimal(18,10)` มีอยู่ พร้อม `TIMEWINDOW_FROM/TO`, `SERVICE_MINUTE`, `POD_STATUS/PODNAME/PODDATE/PODFILE`, `DELIVERY_STATUS` |
| ค่าขนส่งบน shipment header | มี `RATEKEY`, `ESTIMATEDCOST`, `ACTUALCOST` และมี `UTILIZATION_WEIGHT/CUBE/PALLET` ให้ด้วย |
| ชั้นงานเบิก | มี `DOC_DO_PICKDETAIL` (`PICKHEADERKEY`, `DROPID`, `WAVEKEY`, `QTYMOVED`, `QCSTATUS`, `ITRNKEY`, `ALLOCATESTRATEGYKEY`) |
| พาเลท / LPN | มี `TRX_TAGID` + `TRX_DROPID` + `TRX_DROPIDDETAIL` (parent/child ครบ) |
| `TRX_ITRN` ไม่อ้างเอกสารต้นทาง | มี `SOURCEKEY`, `SOURCETYPE`, `RECEIPTKEY`, `RECEIPTLINENUMBER` |
| `MST_DRIVER` ไม่มีชั้นใบขับขี่ | มี `LICENSE_TYPE`, `LICENSE_ISSUE_DATE`, `DEFAULT_VEHICLEKEY` |
| เรตไม่มีสกุลเงิน/ค่าขั้นต่ำ | มี `CURRENCY`, `MINIMUM_CHARGE`, `FUEL_SURCHARGE`, `RATE_PER_KG/CUBE/UNIT/PALLET`, MIN/MAX QTY·WEIGHT·CUBE, `FROMPROVINCE/TOPROVINCE` |
| ไม่มี audit column | มี `ADDDATE/ADDWHO/EDITDATE/EDITWHO` ทุกตาราง + `SUSR1..SUSR5` สำรอง (ที่ไม่มีคือ `rowversion`) |
| `MST_SKU` ไม่คุมล็อต/อายุ | มี `SHELFLIFE`, `SHELFLIFEINDICATOR`, `SHELFLIFEONRECEIVING`, `LOTTABLEVALIDATIONKEY`, `ROTATEBY`, `TOEXPIREDAYS` |
| `MST_LOCATION` ไม่มีความจุ | มี `MAXWEIGHT/MAXCUBE/MAXPALLET/MAXCASE`, `MIXSKU/MIXLOT/MIXLPN_ALLOWED`, `TEMPERATURE_MIN/MAX`, `X/Y/Z_COORDINATE` |
| `DOC_RECEIPT_DETAIL` ไม่มี TOLOC | `DOC_RCPT_TDETAIL` มี `TOLOC`, `TOLOT`, `TOID`, `CONDITIONCODE`, `QTYEXPECTED/ADJUSTED/RECEIVED` |

**ชื่อที่ไดอะแกรมเขียนไม่ตรงกับฐาน** — อย่าใช้ไดอะแกรมเป็นแหล่งอ้างชื่อ

| ไดอะแกรม | ฐานจริง |
| --- | --- |
| `DOC_SO_HDR` / `DOC_SO_DETAIL` | `DOC_DO_HDR` / `DOC_DO_DETAIL` |
| `DOC_RECEIPT_HDR` / `_DETAIL` | `DOC_RCPT_HDR` / `DOC_RCPT_TDETAIL` |
| `MST_TRANSPORT_DOCUMENT` | `MST_TRANSPORTER_DOCUMENT` |
| `MST_AREA.AREAKEY` | `MST_AREA.AREACODE` (PK = WHSEID + AREACODE) |
| `MST_ZONE.ZONECODE` | `MST_ZONE.PUTAWAYZONE` (PK = WHSEID + PUTAWAYZONE) |
| `MST_UOM` มี BASEUOM / CONVERSIONRATE / DECIMALPLACES | **ไม่มีเลย** — มีแค่ `UM`, `UM_DESCR` การแปลงหน่วยอยู่ใน `MST_PACK` แบบ 9 ชั้น (`PACKUOM1..9` + `CASECNT/INNERPACK/QTY/PALLET` + มิติต่อชั้น) |
| `MST_PACK` เป็นบรรจุแบบเดียว | เป็นบันไดหน่วย 9 ชั้นพร้อม `PALLETTI/PALLETHI`, `REACHQTY1..4` |
| `DOC_SHIPMENT_HDR.TRANSPORTERKEYK` | สะกดถูกอยู่แล้วในฐาน (`TRANSPORTERKEY`) — พิมพ์ผิดเฉพาะในไดอะแกรม |
| มีตาราง ASN (`ASNKEY`) | **ไม่มีตาราง ASN และไม่มีคอลัมน์ ASNKEY** ใน `DOC_RCPT_HDR` — ไดอะแกรมวาดเกิน |

## 2 · ปัญหาจริงในฐาน เรียงตามความรุนแรง

### 2.1 ตารางส่วนใหญ่ไม่มี PRIMARY KEY เลย ← เร่งด่วนสุด

มีแค่ `SERIALKEY int IDENTITY` ที่ไม่ได้ประกาศเป็น PK → **แถวซ้ำทั้งแถวเข้าไปได้**,
FK ชี้มาไม่ได้, และ EF Core ต้อง map เป็น keyless entity ที่เขียนกลับไม่ได้

ตารางที่ไม่มี PK: `TRX_LOTXLOCXID` `TRX_SKUXLOC` `TRX_ITRN` `TRX_TAGID`
`TRX_DROPID` `TRX_DROPIDDETAIL` `TRX_LOTATTRIBUTE` `TRX_LOTXIDDETAIL`
`TRX_INVENTORYHOLD` `TRX_INVENTORYHOLDCODE` `DOC_DO_DETAIL` `DOC_DO_PICKDETAIL`
`DOC_PO` `DOC_PODETAIL` `DOC_RCPT_HDR` `DOC_RCPT_TDETAIL` `MST_SKU` `MST_PACK`
`MST_OWNER` `MST_UOM` `MST_ALTSKU` `CFG_*` ทั้งสี่

ที่มี PK แล้ว: `DOC_SHIPMENT_*`, `MST_AREA`, `MST_AREADETAIL`, `MST_LOCATION`,
`MST_ZONE`, `MST_DRIVER`, `MST_VEHICLE`, `MST_VEHICLETYPE`, `MST_TRANSPORTER*`,
`MST_TRANSPORT_RATE`, `MST_VENDOR`, `MST_SHIPTO`, `MST_WHSE`, `TRX_LOT`, `DOC_DO_HDR`

### 2.2 `MST_WHSE.WHSEID` เป็น NULL ได้และไม่ unique

ทุกตารางเก็บ `WHSEID nvarchar(30)` และ join กับตารางนี้ แต่ PK ของ `MST_WHSE`
คือ `SERIALKEY` ส่วน `WHSEID` เป็น user-defined type ที่ **NULL ได้** →
คลังสองแถวใช้รหัสเดียวกันได้ และ FK ชี้มาที่ `WHSEID` ไม่ได้ทั้งระบบ
ต้องอุดก่อนจะผูก FK อื่น

### 2.3 เงินเก็บเป็น `float`

`DOC_DO_DETAIL.UNITPRICE/TAX01/TAX02/EXTENDEDPRICE` · `DOC_PODETAIL.UNITPRICE/UNIT_COST` ·
`DOC_RCPT_TDETAIL.UNITPRICE/EXTENDEDPRICE` · `DOC_DO_PICKDETAIL.FREIGHTCHARGES`
เป็น `float` ซึ่งเป็นทศนิยมฐานสอง — บวกกันแล้วไม่ตรง ใบแจ้งหนี้จะเพี้ยน
หน่วยสตางค์และกระทบยอดไม่ได้ ขณะที่ `DOC_SHIPMENT_DETAIL_LINE` ใช้
`decimal(22,5)` อยู่แล้ว จึงไม่สม่ำเสมอกันเองด้วย

### 2.4 ไม่มี MST_ROUTE / ไม่มีตารางโซนจัดส่ง

`ROUTE` และ `ZONE` เป็นคอลัมน์ `nvarchar` ลอยอยู่ใน `DOC_DO_HDR`,
`DOC_SHIPMENT_HDR`, `DOC_SHIPMENT_DETAIL`, `DOC_DO_PICKDETAIL`,
`MST_TRANSPORTER_ROUTE`, `MST_TRANSPORT_RATE` — **ไม่มีตารางแม่ทั้งคู่**
ทั้งที่ระบบมีจอ master ของทั้งสองอยู่แล้ว และไม่มีที่ไหนตอบได้ว่าโซนหนึ่ง
ครอบคลุมพื้นที่ไหน จึงจัดโซนให้ใบสั่งส่งที่ไหลเข้ามาอัตโนมัติไม่ได้

`MST_ZONE` ที่มีอยู่ **คนละเรื่อง** — เป็นโซนใน *คลัง* (PK `WHSEID`+`PUTAWAYZONE`,
ผูก `AREACODE`, มี `PUTAWAYSEQ/PICKSEQ`) ชื่อ "zone" สองความหมายในโมเดลเดียว

### 2.5 FK เกือบทั้งระบบไม่ได้ผูก

มี FK แค่กลุ่ม shipment ↔ vehicle/driver/location/zone/transporter/vehicletype
ฝั่งคลังของ (`TRX_*`) และเอกสารขาเข้า-ออก (`DOC_DO_*`, `DOC_PO*`, `DOC_RCPT_*`)
**ไม่มี FK เลย** → ลบ SKU หรือ location ที่มีธุรกรรมอ้างอยู่ได้

### 2.6 STATUS เป็นตัวพิมพ์ใหญ่ในฐาน แต่ตัวพิมพ์เล็กใน UI

ฐานตั้ง DEFAULT ไว้เป็น `'ACTIVE'` (master), `'NEW'` (เอกสาร), `'OK'` (`TRX_LOT`,
`MST_LOCATION.LOCATIONSTATUS`) ส่วน types ฝั่ง UI (`src/features/logistics/types`)
เป็น `active`, `draft`, `confirmed`, `sent`, … ตัวพิมพ์เล็กทั้งหมด
และค่าก็ไม่ตรงกัน (`NEW` ไม่ใช่ `draft`)

→ ต้องเลือกทางเดียวและเขียนกำกับ: **map ที่ backend** (แนะนำ — ไม่ต้องแตะข้อมูลเดิม)
หรือย้ายฐานให้ตรงกับ UI ห้ามปล่อยให้แต่ละจอเดาเอง และ
`CFG_ALLOCATESTRATEGY.ALLOCATESTRATEGYTYPE` เป็น `nvarchar(1)` (รหัสตัวเดียว)
ไม่ใช่ `'FIFO'/'FEFO'` — ต้องขอตารางรหัสจากทีมเดิม

### 2.7 อื่น ๆ

- **`MST_SHIPTO.[addr##1]`…`[addr##4]`** — `##` ในชื่อคอลัมน์ ต้องครอบ bracket
  ตลอดไป และตารางนี้พึ่ง user-defined type (`dbo.NameType`, `dbo.AddressType`)
  ซึ่ง EF Core / Dapper map ได้แต่ต้องระบุชนิดฐานเอง
- **พิกัดเก็บเป็นข้อความ** `MST_SHIPTO.gps1 nvarchar(200)` — คำนวณระยะทางไม่ได้
  ขณะที่ `DOC_SHIPMENT_STOP` เก็บเป็น `decimal(18,10)` ถูกต้องแล้ว
- **ที่อยู่สองมาตรฐาน** `MST_SHIPTO` เป็นแบบตะวันตก (`city/state/zip/county`)
  แต่ `DOC_SHIPMENT_STOP`, `MST_VENDOR`, `MST_TRANSPORTER` เป็นแบบไทย
  (`SUBDISTRICT/DISTRICT/PROVINCE/POSTALCODE`) → แมปโซนจาก `MST_SHIPTO` ไม่ได้
- **`TRX_LOT` มี CHECK ซ้ำสองชุด** (`CK__LOT__656C112C` กับ `CK__LOT__693CA210`
  เนื้อหาเหมือนกัน, และอีกคู่ `6660...`/`6A30...`) ตรวจซ้ำทุกครั้งที่เขียนโดยไม่ได้อะไรเพิ่ม
- **ค่า sentinel แทน NULL** `TRX_LOT.ARCHIVEDATE NOT NULL DEFAULT '01/01/1901'`,
  `TRX_INVENTORYHOLD.DATEOFF/WHOOFF NOT NULL` แม้ยังไม่ปลด hold
- **`CFG_ALLOCATESTRATEGYDETAIL.PICKCODESQL nvarchar(2000)`** เก็บ SQL ดิบไว้ในคอลัมน์
  ถ้าเอาไปต่อสตริงแล้ว `EXEC` คือช่องทาง SQL injection ที่แก้ได้จากหน้า config —
  ต้องจำกัดสิทธิ์แก้ไขและรันผ่าน `sp_executesql` แบบ parameter เท่านั้น
- **`MST_TRANSPORTER_ROUTE` PK = (TRANSPORTERKEY, ROUTE)** แต่ `ZONE` อยู่นอก PK
  → ผู้ให้บริการรายเดียวกันมีเงื่อนไขต่างกันรายโซนบนสายเดียวกันไม่ได้
- **`DOC_SHIPMENT_STOP` มีทั้ง `CUSTOMERKEY` และ `SHIPTOKEY`** โดยไม่มีตารางแม่
  ของตัวแรกเลย และตัวหลังชี้ไปคอลัมน์ที่ไม่ unique
- **เวลาเป็น `datetime`** ทั้งระบบ (ละเอียด 3.33ms, ช่วงเริ่ม 1753) ไม่ใช่ `datetime2`
  ตารางใหม่ในไฟล์ 01 ใช้ `datetime` ตามให้เข้ากัน แต่ของใหม่ทั้งระบบควรพิจารณา `datetime2(3)`

### 2.8 คอลัมน์ที่อ้างถึงตารางที่ไม่มีอยู่ในฐาน

`MAMMOD_TABLE2_R02.sql` คือฐานทั้งหมด ไม่ใช่บางส่วน — คอลัมน์เหล่านี้จึงชี้ไป
ที่ว่างเปล่าจริง ๆ ไม่ใช่ชี้ไปตารางที่อยู่ในไฟล์อื่น

| คอลัมน์ | อ้างถึง | ผล |
| --- | --- | --- |
| `DOC_DO_PICKDETAIL.PICKHEADERKEY` | หัวใบจัดสินค้า | **ไม่มีตาราง** → รายการเบิกลอยอยู่โดยไม่มีหัวเอกสาร ตอบไม่ได้ว่าใบ PKL ใบหนึ่งสถานะอะไร ใครถือ ปิดเมื่อไหร่ ทั้งที่จอ "ใบคุมเบิกสินค้า" ต้องอ่านจากที่นี่ → เสนอ `DOC_DO_PICKHEADER` |
| `DOC_DO_PICKDETAIL.WAVEKEY` | ตาราง wave | ไม่มี — จัดกลุ่มงานเบิกเป็นรอบไม่ได้ |
| `DOC_RCPT_HDR.CARRIERKEY` (`nvarchar(15)`) | ผู้ขนส่งขาเข้า | ไม่มีตาราง และความยาวไม่ตรงกับ `MST_TRANSPORTER.TRANSPORTERKEY` (`nvarchar(20)`) → คนละ entity หรือแค่ตั้งไม่ตรงกัน ต้องยืนยัน |
| `DOC_DO_HDR.CarrierCode` + `CarrierName…` | ผู้ขนส่ง | เป็น snapshot ล้วน ไม่มี FK ไปไหน |
| `DOC_PO.SELLERNAME` / `BUYERNAME` | ผู้ขาย | `MST_VENDOR` มีอยู่แต่ `DOC_PO` ไม่มี `VENDORKEY` → PO ผูกผู้ขายไม่ได้เลย |
| `MST_OWNER.DEFAULTSTRATEGY`, `DEFAULTPUTAWAYSTRATEGY`, `DEFAULTNEWALLOCATIONSTRATEGY`, `OPPORDERSTRATEGYKEY`, `AMSTRATEGYKEY`, `VENDORCOMPLYSTRATEGYKEY`, `BARCODECONFIGKEY`, `RECEIPTVALIDATIONTEMPLATE`, `PACKINGVALIDATIONTEMPLATE` | ตาราง config ต่าง ๆ | ส่วนใหญ่ไม่มีตาราง — มีแต่ `CFG_PUTAWAYSTRATEGY` กับ `CFG_ALLOCATESTRATEGY` |
| `MST_SKU.STRATEGYKEY`, `REPLENSTRATKEY`, `SPEEDGROUPSTRATKEY`, `OUTLOTVALIDATIONKEY`, `LOTTABLEVALIDATIONKEY`, `PICKCODE`, `CARTONGROUP` | ตารางรหัส | ไม่มีตารางรหัสให้ตรวจค่า |
| `REASONCODE`, `REJECTEDREASON`, `CONDITIONCODE`, `HOLDCODE`, `FREIGHTCLASS`, `CARTONTYPE`, `LABELTYPE` | ตารางรหัส | ไม่มี (ยกเว้น `TRX_INVENTORYHOLDCODE` ที่มี) |
| `MST_SHIPTO`, `MST_SKU`, `MST_WHSE`, `TRX_*` ที่ใช้ `dbo.NameType`, `dbo.AddressType`, `dbo.SiteType`, `dbo.DropSeqType` … | user-defined type | **นิยาม UDT ไม่อยู่ในไฟล์** → สคริปต์นี้รันบนฐานเปล่าไม่ได้ และ EF Core / Dapper ต้องระบุชนิดฐานเอง |

ไม่มีตารางผู้ใช้/สิทธิ์เลย ทั้งที่แอปมี login + role 4 ระดับ + จำกัดตามโมดูล →
เสนอ `MST_USER` / `MST_USER_MODULE`

**และไม่มี index ใดเลยนอกจาก PK** ทั้งฐาน — ตาราง `TRX_LOTXLOCXID`,
`TRX_ITRN`, `DOC_SHIPMENT_*` ที่ query ตามวันที่/สถานะ/สายส่งทุกจอ จะ scan
ทั้งตารางทุกครั้ง

### 2.9 `TRX_LOT` PK ไม่มี `WHSEID`

PK เป็น `(LOT, OWNERKEY, SKU)` ขณะที่ทุกตารางอื่นในระบบขึ้นต้นด้วย `WHSEID`
รวมถึง `TRX_LOTXLOCXID` ที่เป็นลูกของมัน → **เลขล็อตเดียวกันซ้ำข้ามคลังไม่ได้**
ถ้าคลังคนละแห่งรับของจากผู้ผลิตเดียวกันที่ใช้เลขล็อตชุดเดียวกัน จะชนกันทันที
ต้องยืนยันว่าเป็นเจตนา (ล็อตเป็น global) หรือเป็นความพลาด

## 3 · ตารางที่เสนอเพิ่ม (10 ตาราง)

| ตาราง | เหตุผล |
| --- | --- |
| `MST_ROUTE` | ให้ `ROUTE` ที่ลอยอยู่ 6 ตารางมีตารางแม่ |
| `MST_DELIVERY_ZONE` | โซนจัดส่ง แยกจาก `MST_ZONE` ที่เป็นโซนในคลัง |
| `MST_ZONE_COVERAGE` | โซน ↔ จังหวัด/อำเภอ/ตำบล/ไปรษณีย์ = ตัวที่ทำให้จัดโซนอัตโนมัติได้ |
| `MST_ROUTE_ZONE` | สายส่ง ↔ โซน + ลำดับการวิ่ง + สายหลักของโซน |
| `DOC_TRANSPORT_PLAN` / `_LINE` | ชั้นแผน `PL-…` ที่ออกใบปิดบรรทุก |
| `DOC_SHIPMENT_STATUS_LOG` | timeline 5 ขั้น + ข้อความที่ WMS/OMS ตีกลับ |
| `MST_CUSTOMER` | ตารางลูกค้าที่ FK ชี้ได้จริง — `MST_SHIPTO` ทำหน้าที่นี้ไม่ได้เพราะ `SHIPTO` ไม่ unique, ที่อยู่เป็นแบบตะวันตก, พิกัดเป็นข้อความ |
| `DOC_DO_PICKHEADER` | `DOC_DO_PICKDETAIL.PICKHEADERKEY` ชี้ไปที่ว่างเปล่า — **รูปร่างตารางนี้อนุมานจากคอลัมน์ในตารางลูก ต้องให้ทีม WMS ยืนยันก่อนใช้** |
| `MST_USER` / `MST_USER_MODULE` | ไม่มีตารางผู้ใช้เลย ค่า `ROLECODE`/`MODULEPATH` ลอกจาก `USER_ROLES` และ `modules` ใน `src/constants` |

**ย้ายข้อมูลจาก `MST_SHIPTO`** (ตรวจผลก่อน commit — `gps1` เป็น free text
รูปแบบไม่แน่นอน ต้อง parse แล้วตรวจด้วยตา ไม่ควร parse อัตโนมัติทั้งก้อน):

```sql
INSERT INTO dbo.MST_CUSTOMER
      (WHSEID, CUSTOMERKEY, SHIPTO, CUSTOMERNAME, ADDRESS1, ADDRESS2,
       PROVINCE, POSTALCODE, COUNTRY, CONTACTNAME, CONTACTPHONE, STATUS, ADDWHO)
SELECT s.WHSEID, s.SHIPTO, s.SHIPTO, s.[name], s.[addr##1], s.[addr##2],
       s.[state], s.zip, s.country, s.contact, s.phone, 'ACTIVE', SUSER_SNAME()
FROM   dbo.MST_SHIPTO s
WHERE  NOT EXISTS (SELECT 1 FROM dbo.MST_CUSTOMER c WHERE c.CUSTOMERKEY = s.SHIPTO);
```

จากนั้นเติมโซนจากรหัสไปรษณีย์:

```sql
UPDATE c SET c.[ZONE] = v.[ZONE]
FROM   dbo.MST_CUSTOMER c
JOIN   dbo.MST_ZONE_COVERAGE v ON v.POSTALCODE = c.POSTALCODE
WHERE  c.[ZONE] IS NULL;
```

## 4 · ลำดับที่ควรทำ

1. **`01-new-tables.sql`** — เพิ่ม 7 ตาราง (ไม่แตะข้อมูลเดิม รันได้ทันที)
2. **โหลด master**: route → delivery zone → zone coverage → customer
3. **ส่วน A ของ `02`** — ใส่ PK ที่หายไป มี query หาแถวซ้ำกำกับทุกตาราง
   ต้องได้ 0 แถวก่อนใส่ · `MST_WHSE` กับ `MST_SHIPTO` ถูก comment ไว้เพราะ
   ต้องยืนยันข้อมูลก่อน
4. **ส่วน B** — `float` → `decimal` (สำรองตารางก่อน การ ALTER ปัดค่าเดิม)
5. **ส่วน C–E** — คอลัมน์ที่ขาด, FK, ดัชนี, view ตรวจยอดรวม
6. **ส่วน F–G** — rowversion และเก็บกวาด

## 5 · ที่ต้องยืนยันก่อนรัน

1. **`weight` ของโซนจัดส่งคืออะไร** — ไฟล์ 01 ตีความเป็น `MAX_VEHICLE_WEIGHT`
   (น้ำหนักรถสูงสุดที่เข้าพื้นที่ได้: สะพาน ซอยแคบ เขตห้ามรถบรรทุก)
   ถ้าหมายถึงโควตาน้ำหนักต่อวันของโซน ต้องเปลี่ยนทั้งชื่อและที่ใช้งาน
   ตอนนี้ฝั่ง UI ยังไม่มีโค้ดไหนใช้ค่านี้ตรวจอะไรเลย
2. **ค่าที่เป็นไปได้ของ `STATUS` แต่ละตาราง** และ `ALLOCATESTRATEGYTYPE nvarchar(1)` —
   ไม่มีตารางรหัสในฐาน จึงอ่านจาก DDL ไม่ได้ ต้องถามทีมที่ใช้ระบบเดิมหรือ
   `SELECT DISTINCT STATUS` จากข้อมูลจริง ยังไม่ได้ใส่ CHECK ให้เพราะเดาไม่ได้
3. **ใบปิดบรรทุกที่ยกเลิกใช้ STATUS อะไร** — ดัชนี `UX_SHIPMENT_DETAIL_ORDER`
   ในส่วน E สมมติว่า `'CANCELLED'`
4. **PO/ใบรับผูกกับผู้ขายทางไหน** — `MST_VENDOR` มี PK `(WHSEID, OWNERKEY, VENDORKEY)`
   แต่ `DOC_PO` ไม่มี `VENDORKEY` (มีแต่ `SELLERNAME` เป็นข้อความ) และ
   `DOC_RCPT_HDR` ก็ไม่มี (มี `CARRIERKEY` ซึ่งเป็นผู้ขนส่ง ไม่ใช่ผู้ขาย)
   → ถ้าจะผูกจริงต้องเพิ่ม `VENDORKEY` ทั้งสองตารางแล้ว backfill จากชื่อ
5. **`TRX_LOT` PK ไม่มี `WHSEID`** — ล็อตเป็น global ข้ามคลังโดยเจตนา หรือพลาด
6. **`MST_VEHICLETYPE.MAXPALLET` / `MAXUNITS`** — ฝั่งขนส่งของ UI ไม่มีแนวคิด
   พาเลทเลย จะใช้จริงหรือไม่
7. **นิยาม user-defined type** (`dbo.NameType`, `dbo.AddressType`, `dbo.SiteType`,
   `dbo.DropSeqType`, `dbo.PostalCodeType` …) ไม่อยู่ในสคริปต์ → ต้องดึงจากฐานจริง
   ด้วย `SELECT name, system_type_id, max_length, is_nullable FROM sys.types
   WHERE is_user_defined = 1` ก่อนจะ generate DTO ฝั่ง .NET ได้

## 6 · กฎที่ฐานบังคับไม่ได้ backend ต้องบังคับ

constraint ครอบได้เท่าที่ประกาศได้ ที่เหลือเป็นกฎเชิงกระบวนการซึ่ง mock adapter
ฝั่ง client บังคับอยู่แล้ว และ backend ต้องบังคับซ้ำ — **ปุ่มที่กดไม่ได้ไม่ใช่การป้องกัน**

| กฎ | บังคับได้ที่ไหน |
| --- | --- |
| ใบสั่งส่งอยู่ได้ที่เดียว (คิว / แผน / ใบปิดบรรทุก) | ฐานช่วยครึ่งเดียวด้วย `UX_DOC_TRANSPORT_PLAN_LINE_ORDER` + `UX_SHIPMENT_DETAIL_ORDER` ส่วนการย้ายต้องอยู่ใน transaction เดียว |
| การเปลี่ยนสถานะที่อนุญาต — แก้ไข: draft+confirmed · ยืนยัน: draft · ส่ง MMX: confirmed+error · ยกเลิก: draft+confirmed · แยก/ย้าย: draft | backend เท่านั้น |
| ยืนยันไม่ได้ถ้ายังไม่มีรถ + คนขับ + สายส่ง | backend เท่านั้น |
| ยกเลิกแล้วจุดส่งกลับคิวทุกใบ | backend เท่านั้น |
| completed / error มาจาก OMS เท่านั้น TMS ตั้งเองไม่ได้ | backend เท่านั้น |
| แยกใบต้องเหลือของในใบแม่ | backend เท่านั้น |
| น้ำหนักเกินพิกัด = **เตือน ไม่บล็อก** (ตัดสินใจไว้แล้ว) | ห้ามใส่ CHECK ห้ามเกิน — `UTILIZATION_WEIGHT` ที่มีอยู่ใช้แสดงผลได้เลย |

---

อ้างอิง (ทั้งหมดอยู่ใน repo ฝั่ง frontend): `MAMMOD_TABLE2_R02.sql` (ฐาน MMPRD) ·
`src/features/logistics/types` ·
กฎที่ mock บังคับ: `src/features/logistics/api/manifests.mock.ts` ·
ลำดับการทำงาน: `docs/tms-sequence.md`
