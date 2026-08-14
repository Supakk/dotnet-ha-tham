/* =============================================================================
   ข้อมูลตัวอย่างสำหรับฐาน MMDEV — **สร้างอัตโนมัติ ห้ามแก้ไฟล์นี้ด้วยมือ**

   สร้างจาก  tests/generate_sql_data.py  ถ้าจะเปลี่ยนข้อมูล ให้แก้ที่สคริปต์นั้น
   แล้ว generate ใหม่ ไม่งั้นการรันครั้งถัดไปจะทับที่แก้ไว้ทิ้ง

   รันหลัง 02-alter-existing.sql · รันซ้ำได้ (ลบของเดิมก่อนเสมอ)

   ⚠ ทุกแถวเป็นข้อมูลสมมติ ชื่อบริษัท เลขผู้เสียภาษี เบอร์โทร ทะเบียนรถ และอีเมล
     ไม่ใช่ของจริงและตั้งใจให้ดูออกว่าไม่จริง (อีเมลใช้โดเมน .test ตาม RFC 2606
     ซึ่งสงวนไว้ไม่ให้จดจริงได้) **ห้ามแทนที่ด้วยข้อมูลลูกค้าจริง** เพราะไฟล์นี้
     ขึ้น repo สาธารณะ

   PASSWORDHASH ใน MST_USER ไม่ใช่ hash — เป็นข้อความบอกว่ายังไม่มีการตรวจรหัสผ่าน
   ใส่ค่าที่หน้าตาเหมือน bcrypt ไว้จะทำให้เข้าใจผิดว่าระบบตรวจแล้ว
============================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;   -- error ใด ๆ ให้ rollback ทั้งก้อน ไม่ใช่ค้างครึ่งทาง

-- ต้องเปิดสองตัวนี้ ไม่ใช่ของประดับ: ฐานนี้มี filtered index อยู่ (เช่น
-- IX_MST_CUSTOMER_ZONE ที่มี WHERE STATUS = 'ACTIVE') และ SQL Server ปฏิเสธ
-- INSERT/UPDATE/DELETE ทุกคำสั่งบนตารางที่มี filtered index ถ้า QUOTED_IDENTIFIER
-- ปิดอยู่ — ตอบด้วย Msg 1934 ซึ่งอ่านแล้วไม่รู้เลยว่าเกี่ยวกับ index
-- sqlcmd ตั้ง QUOTED_IDENTIFIER OFF มาให้เป็นค่าเริ่มต้น (SSMS ตั้ง ON)
-- สคริปต์นี้จึงต้องตั้งเองทุกครั้ง ไม่งั้นรันใน SSMS ผ่านแต่รันใน sqlcmd ล้ม
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

BEGIN TRANSACTION;
GO

-- ข้อความ PRINT เป็นอังกฤษเพราะ console ของ sqlcmd ใช้ codepage เดิมของ Windows
-- ภาษาไทยจะออกมาเป็น ????? (เว้นแต่สั่ง -f 65001) ส่วนคอมเมนต์กับข้อมูลในตาราง
-- เป็นไทยได้ตามปกติ เพราะไม่ได้วิ่งผ่าน console
PRINT 'clearing previous demo rows';

DELETE FROM dbo.DOC_SHIPMENT_STATUS_LOG;
DELETE FROM dbo.DOC_SHIPMENT_DETAIL_LINE;
DELETE FROM dbo.DOC_SHIPMENT_DETAIL;
DELETE FROM dbo.DOC_SHIPMENT_STOP;
DELETE FROM dbo.DOC_SHIPMENT_HDR;
DELETE FROM dbo.DOC_TRANSPORT_PLAN_LINE;
DELETE FROM dbo.DOC_TRANSPORT_PLAN;
DELETE FROM dbo.DOC_DO_DETAIL;
DELETE FROM dbo.DOC_DO_HDR;
DELETE FROM dbo.MST_USER_MODULE;
DELETE FROM dbo.MST_USER;
DELETE FROM dbo.MST_CUSTOMER;
DELETE FROM dbo.MST_SKU;
DELETE FROM dbo.MST_ROUTE_ZONE;
DELETE FROM dbo.MST_ZONE_COVERAGE;
DELETE FROM dbo.MST_TRANSPORTATIONZONE;
DELETE FROM dbo.MST_DRIVER;
DELETE FROM dbo.MST_VEHICLE;
DELETE FROM dbo.MST_VEHICLETYPE;
DELETE FROM dbo.MST_TRANSPORTER;
DELETE FROM dbo.MST_ROUTE;
DELETE FROM dbo.MST_OWNER;
DELETE FROM dbo.MST_WHSE;
GO

PRINT 'inserting demo rows';

PRINT '  MST_WHSE';
INSERT INTO dbo.MST_WHSE
    ([WHSEID], [description], [type], [lang_code], [time_zone], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'คลังสีคิ้ว', N'S', N'th-TH', N'Asia/Bangkok', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'คลังปทุมธานี', N'S', N'th-TH', N'Asia/Bangkok', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'คลังวังน้อย', N'S', N'th-TH', N'Asia/Bangkok', '2026-08-05T09:00:00', N'seed'),
    (N'WNB', N'DC นนทบุรี', N'S', N'th-TH', N'Asia/Bangkok', '2026-08-05T09:00:00', N'seed'),
    (N'WBN', N'DC บางนา', N'S', N'th-TH', N'Asia/Bangkok', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_OWNER';
INSERT INTO dbo.MST_OWNER
    ([TYPE], [SOURCEVERSION], [CARTONGROUP], [PICKCODE], [CREATEPATASKONRFRECEIPT], [CALCULATEPUTAWAYLOCATION], [ROLLRECEIPT], [RECEIPTVALIDATIONTEMPLATE], [ALLOWAUTOCLOSEFORPO], [ALLOWAUTOCLOSEFORASN], [ALLOWAUTOCLOSEFORPS], [ALLOWSYSTEMGENERATEDLPN], [ALLOWDUPLICATELICENSEPLATES], [ALLOWCOMMINGLEDLPN], [ALLOWSINGLESCANRECEIVING], [LPNLENGTH], [APPLICATIONID], [SSCC1STDIGIT], [UCCVENDORNUMBER], [AUTOPRINTLABELLPN], [AUTOPRINTLABELPUTAWAY], [LPNSTARTNUMBER], [NEXTLPNNUMBER], [LPNROLLBACKNUMBER], [AUTOCLOSEASN], [AUTOCLOSEPO], [DEFAULTRETURNSLOC], [DEFAULTQCLOC], [PISKUXLOC], [CCSKUXLOC], [CCDISCREPANCYRULE], [CCADJBYRF], [ORDERBREAKDEFAULT], [SKUSETUPREQUIRED], [DEFAULTQCLOCOUT], [KSHIP_CARRIER], [REQREASONSHORTSHIP], [CONTAINEREXCHANGEFLAG], [CARTONIZEFTDFLT], [DEFFTLABELPRINT], [DEFFTTASKCONTROL], [PLANDAYS], [ARCHIVEPLANNINGDAYS], [ARCHIVEREPORTINGDATA], [PLANENABLED], [DEFAULTHOURLYRATE], [SAVESTANDARDSAUDIT], [TEMPFORASN], [MIXEDLPNPUTSTRATEGY], [RFAUTOFILLRCVLPN], [INBOUNDLPNLENGTH], [USEPARTNERLPNCONTROL], [AUTOFINALIZEPRODORDER], [CREATEMOVESFROMPROD], [PRODCOUNTLOC], [QUARANTINEINDICATOR], [OWNERKEY], [WHSEID], [ADDDATE], [ADDWHO])
VALUES
    (N'OWNER', N'1', N'STD', N'STD', N'N', N'N', N'N', N'STD', N'N', N'N', N'N', N'Y', N'N', N'N', N'N', 20, N'00', 0, N'000000000', N'N', N'N', N'1', N'1', N'1', N'N', N'N', N'RETURNS', N'QC', N'N', N'N', N'STD', N'N', N'N', N'Y', N'QCOUT', 0, 0, 0, N'N', N'N', N'N', 7, 30, 90, 0, 0, 0, N'N', N'STD', N'N', 20, N'N', N'N', N'N', N'PROD', N'N', N'MAMMOD', N'WSK', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_ROUTE';
INSERT INTO dbo.MST_ROUTE
    ([ROUTE], [WHSEID], [ROUTENAME], [ORIGIN_WHSEID], [COLOURHEX], [TRANSIT_DAY], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'RT-NORTH-01', N'WSK', N'สายเหนือ (นครสวรรค์ - พิษณุโลก)', N'WNB', N'#2563eb', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-EAST-01', N'WSK', N'สายตะวันออก (ชลบุรี - ระยอง)', N'WBN', N'#16a34a', 2, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-WEST-02', N'WSK', N'สายตะวันตก (นครปฐม - ราชบุรี)', N'WNB', N'#ea580c', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-SOUTH-01', N'WSK', N'สายใต้ (เพชรบุรี - ประจวบฯ)', N'WBN', N'#9333ea', 2, N'INACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_TRANSPORTATIONZONE';
INSERT INTO dbo.MST_TRANSPORTATIONZONE
    ([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY], [TRANSPORTZONENAME], [COUNTRY], [PROVINCE], [DELIVERYLEADDAY], [DEFAULTROUTE], [PRIORITY], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MAMMOD', N'TH-001', N'โซนนครสวรรค์', N'TH', N'นครสวรรค์', 1, N'RT-NORTH-01', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-002', N'โซนพิจิตร', N'TH', N'พิจิตร', 2, N'RT-NORTH-01', 2, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-003', N'โซนพิษณุโลก', N'TH', N'พิษณุโลก', 3, N'RT-NORTH-01', 3, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'โซนพระนครศรีอยุธยา', N'TH', N'พระนครศรีอยุธยา', 1, NULL, 4, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-005', N'โซนลพบุรี', N'TH', N'ลพบุรี', 2, NULL, 5, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-006', N'โซนสระบุรี', N'TH', N'สระบุรี', 3, NULL, 6, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'โซนชลบุรี', N'TH', N'ชลบุรี', 1, N'RT-EAST-01', 7, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'โซนระยอง', N'TH', N'ระยอง', 2, N'RT-EAST-01', 8, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'โซนนครปฐม', N'TH', N'นครปฐม', 3, N'RT-WEST-02', 9, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'โซนราชบุรี', N'TH', N'ราชบุรี', 1, N'RT-WEST-02', 10, N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_ZONE_COVERAGE';
INSERT INTO dbo.MST_ZONE_COVERAGE
    ([WHSEID], [OWNERKEY], [TRANSPORTZONEKEY], [PROVINCE], [DISTRICT], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MAMMOD', N'TH-001', N'นครสวรรค์', N'อำเภอเมืองนครสวรรค์', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-001', N'นครสวรรค์', N'อำเภอพยุหะคีรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-001', N'นครสวรรค์', N'อำเภอโกรกพระ', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-001', N'นครสวรรค์', N'อำเภอชุมแสง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-001', N'นครสวรรค์', N'อำเภอท่าตะโก', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-002', N'พิจิตร', N'อำเภอเมืองพิจิตร', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-002', N'พิจิตร', N'อำเภอตะพานหิน', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-002', N'พิจิตร', N'อำเภอบางมูลนาก', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-002', N'พิจิตร', N'อำเภอสามง่าม', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-003', N'พิษณุโลก', N'อำเภอเมืองพิษณุโลก', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-003', N'พิษณุโลก', N'อำเภอวังทอง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-003', N'พิษณุโลก', N'อำเภอบางระกำ', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-003', N'พิษณุโลก', N'อำเภอพรหมพิราม', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'พระนครศรีอยุธยา', N'อำเภอพระนครศรีอยุธยา', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'พระนครศรีอยุธยา', N'อำเภอบางปะอิน', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'พระนครศรีอยุธยา', N'อำเภอวังน้อย', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'พระนครศรีอยุธยา', N'อำเภอนครหลวง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-004', N'พระนครศรีอยุธยา', N'อำเภออุทัย', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-005', N'ลพบุรี', N'อำเภอเมืองลพบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-005', N'ลพบุรี', N'อำเภอบ้านหมี่', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-005', N'ลพบุรี', N'อำเภอโคกสำโรง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-005', N'ลพบุรี', N'อำเภอท่าวุ้ง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-006', N'สระบุรี', N'อำเภอเมืองสระบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-006', N'สระบุรี', N'อำเภอแก่งคอย', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-006', N'สระบุรี', N'อำเภอหนองแค', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-006', N'สระบุรี', N'อำเภอวิหารแดง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'ชลบุรี', N'อำเภอเมืองชลบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'ชลบุรี', N'อำเภอศรีราชา', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'ชลบุรี', N'อำเภอบางละมุง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'ชลบุรี', N'อำเภอพานทอง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-007', N'ชลบุรี', N'อำเภอสัตหีบ', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'ระยอง', N'อำเภอเมืองระยอง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'ระยอง', N'อำเภอบ้านฉาง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'ระยอง', N'อำเภอปลวกแดง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'ระยอง', N'อำเภอนิคมพัฒนา', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-008', N'ระยอง', N'อำเภอแกลง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'นครปฐม', N'อำเภอเมืองนครปฐม', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'นครปฐม', N'อำเภอสามพราน', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'นครปฐม', N'อำเภอนครชัยศรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'นครปฐม', N'อำเภอกำแพงแสน', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-009', N'นครปฐม', N'อำเภอบางเลน', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'ราชบุรี', N'อำเภอเมืองราชบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'ราชบุรี', N'อำเภอบ้านโป่ง', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'ราชบุรี', N'อำเภอโพธาราม', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'ราชบุรี', N'อำเภอดำเนินสะดวก', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'TH-010', N'ราชบุรี', N'อำเภอบางแพ', N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_ROUTE_ZONE';
INSERT INTO dbo.MST_ROUTE_ZONE
    ([ROUTE], [WHSEID], [OWNERKEY], [TRANSPORTZONEKEY], [SEQUENCE], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'RT-NORTH-01', N'WSK', N'MAMMOD', N'TH-001', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-NORTH-01', N'WSK', N'MAMMOD', N'TH-002', 2, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-NORTH-01', N'WSK', N'MAMMOD', N'TH-003', 3, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-EAST-01', N'WSK', N'MAMMOD', N'TH-007', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-EAST-01', N'WSK', N'MAMMOD', N'TH-008', 2, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-WEST-02', N'WSK', N'MAMMOD', N'TH-009', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'RT-WEST-02', N'WSK', N'MAMMOD', N'TH-010', 2, N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_TRANSPORTER';
INSERT INTO dbo.MST_TRANSPORTER
    ([TRANSPORTERKEY], [TRANSPORTERNAME], [TRANSPORTERTYPE], [CONTACTNAME], [PHONE], [EMAIL], [TAXID], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'CR-001', N'Fleet อินเฮาส์ (คลังบางบัวทอง)', N'INHOUSE', N'ฝ่ายขนส่ง คลังบางบัวทอง', N'02-123-4567', N'fleet@example.test', N'0105542000111', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'CR-002', N'ไทยขนส่งด่วน', N'SUBCONTRACT', N'คุณสมหมาย ธนกิจ', N'081-999-1122', N'ops@example.test', N'0105551002233', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'CR-003', N'สยามโลจิสติกส์ พาร์ทเนอร์', N'SUBCONTRACT', N'คุณวราภรณ์ สุขใจ', N'089-444-7788', N'dispatch@example.test', N'0105560004455', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'CR-004', N'บูรพาทรานสปอร์ต', N'SUBCONTRACT', N'คุณอนันต์ บูรพา', N'086-222-3344', NULL, N'0205549006677', N'INACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_VEHICLETYPE';
INSERT INTO dbo.MST_VEHICLETYPE
    ([VEHICLETYPEKEY], [VEHICLETYPENAME], [MAXWEIGHT], [MAXCUBE], [MAXPALLET], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'4W', N'รถ 4 ล้อ', 3500, 12, 4, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'6W', N'รถ 6 ล้อ', 8000, 22, 8, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'10W', N'รถ 10 ล้อ', 15000, 35, 14, N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_VEHICLE';
INSERT INTO dbo.MST_VEHICLE
    ([VEHICLEKEY], [TRANSPORTERKEY], [VEHICLETYPEKEY], [LICENSEPLATE], [PLATE_TRAILER], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'VH-001', N'CR-001', N'10W', N'70-1234 นนทบุรี', N'71-5678 นนทบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'VH-002', N'CR-001', N'10W', N'70-9012 นนทบุรี', N'71-3344 นนทบุรี', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'VH-003', N'CR-002', N'6W', N'82-4455 กรุงเทพมหานคร', NULL, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'VH-004', N'CR-003', N'6W', N'82-7788 กรุงเทพมหานคร', NULL, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'VH-005', N'CR-002', N'4W', N'1กต 2414', NULL, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'VH-006', N'CR-003', N'4W', N'1กก 8899', NULL, N'INACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_DRIVER';
INSERT INTO dbo.MST_DRIVER
    ([DRIVERKEY], [TRANSPORTERKEY], [DRIVERNAME], [MOBILE], [LICENSE_NO], [LICENSE_TYPE], [DEFAULT_VEHICLEKEY], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'DRV-001', N'CR-001', N'สมศักดิ์ ขยันส่ง', N'081-234-5678', N'6401234567', N'ท.3', N'VH-002', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'DRV-002', N'CR-001', N'สมชาย ใจดี', N'081-111-2222', N'6402345678', N'ท.2', N'VH-001', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'DRV-003', N'CR-002', N'ประเสริฐ ศรีสุข', N'086-555-7777', N'6403456789', N'ท.2', N'VH-004', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'DRV-004', N'CR-002', N'วิชัย พงษ์ทอง', N'089-876-5432', N'6404567890', N'ท.2', N'VH-003', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'DRV-005', N'CR-003', N'อนุชา ทองดี', N'087-321-9900', N'6405678901', N'ท.1', N'VH-005', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'DRV-006', N'CR-003', N'ธนพล แสนดี', N'092-448-1100', N'6406789012', N'ท.2', NULL, N'INACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_CUSTOMER';
INSERT INTO dbo.MST_CUSTOMER
    ([WHSEID], [OWNERKEY], [CUSTOMERKEY], [CUSTOMERNAME], [ADDRESS1], [SUBDISTRICT], [DISTRICT], [PROVINCE], [POSTALCODE], [COUNTRY], [LATITUDE], [LONGITUDE], [TRANSPORTZONEKEY], [ROUTE], [COD_FLAG], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MAMMOD', N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'125/7 ถนนสวรรค์วิถี', N'ปากน้ำโพ', N'อำเภอเมืองนครสวรรค์', N'นครสวรรค์', N'60000', N'TH', 15.7047, 100.1372, N'TH-001', N'RT-NORTH-01', 0, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'88 ถนนบุษบา', N'ในเมือง', N'อำเภอเมืองพิจิตร', N'พิจิตร', N'66000', N'TH', 16.4429, 100.3487, N'TH-002', N'RT-NORTH-01', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'302 ถนนพิชัยสงคราม', N'ในเมือง', N'อำเภอเมืองพิษณุโลก', N'พิษณุโลก', N'65000', N'TH', 16.8211, 100.2659, N'TH-003', N'RT-NORTH-01', 0, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'45 หมู่ 3 ถนนโรจนะ', N'ไผ่ลิง', N'อำเภอพระนครศรีอยุธยา', N'พระนครศรีอยุธยา', N'13000', N'TH', 14.3532, 100.5689, N'TH-004', NULL, 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0005', N'สหกรณ์ลพบุรี', N'9 ถนนนารายณ์มหาราช', N'ทะเลชุบศร', N'อำเภอเมืองลพบุรี', N'ลพบุรี', N'15000', N'TH', 14.7995, 100.6534, N'TH-005', NULL, 0, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'77/1 ถนนพหลโยธิน', N'ปากเพรียว', N'อำเภอเมืองสระบุรี', N'สระบุรี', N'18000', N'TH', 14.5289, 100.9101, N'TH-006', NULL, 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'199 ถนนสุขุมวิท', N'ศรีราชา', N'อำเภอศรีราชา', N'ชลบุรี', N'20110', N'TH', 13.1731, 100.931, N'TH-007', N'RT-EAST-01', 0, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0008', N'ระยองฟู้ดส์', N'56 ถนนสุขุมวิท', N'เนินพระ', N'อำเภอเมืองระยอง', N'ระยอง', N'21000', N'TH', 12.6814, 101.2816, N'TH-008', N'RT-EAST-01', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0009', N'นครปฐมค้าส่ง', N'12 ถนนเพชรเกษม', N'พระปฐมเจดีย์', N'อำเภอเมืองนครปฐม', N'นครปฐม', N'73000', N'TH', 13.8199, 100.0621, N'TH-009', N'RT-WEST-02', 0, N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MAMMOD', N'CUS-0010', N'ราชบุรีมาร์ท', N'410 ถนนศรีสุริยวงศ์', N'หน้าเมือง', N'อำเภอเมืองราชบุรี', N'ราชบุรี', N'70000', N'TH', 13.5282, 99.8134, N'TH-010', N'RT-WEST-02', 1, N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_SKU';
INSERT INTO dbo.MST_SKU
    ([ITEMREFERENCE], [PACKKEY], [TARE], [CLASS], [ACTIVE], [SKUGROUP], [PICKCODE], [CARTONGROUP], [PUTCODE], [PUTAWAYLOC], [INNERPACK], [SHELFLIFECODETYPE], [SHELFLIFEONRECEIVING], [LOTTABLEVALIDATIONKEY], [RETURNSLOC], [QCLOC], [SKUTYPE], [StackLimit], [MaxPalletsPerZone], [CATCHGROSSWGT], [CATCHNETWGT], [CATCHTAREWGT], [TAREWGT1], [STDNETWGT1], [STDGROSSWGT1], [site_ref], [OWNERKEY], [SKU], [DESCR], [STDGROSSWGT], [STDNETWGT], [STDCUBE], [CUBE], [GROSSWGT], [NETWGT], [PICKUOM], [ADDDATE], [ADDWHO])
VALUES
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1001', N'น้ำดื่ม 600ml แพ็ค 12', 7.2, 7.2, 0.012, 0.012, 7.2, 7.2, N'CS', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1002', N'น้ำอัดลม 325ml แพ็ค 24', 8.6, 8.6, 0.015, 0.015, 8.6, 8.6, N'CS', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1003', N'ข้าวสารหอมมะลิ 5 กก.', 5.0, 5.0, 0.007, 0.007, 5.0, 5.0, N'BG', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1004', N'น้ำมันพืช 1 ลิตร แพ็ค 12', 11.4, 11.4, 0.014, 0.014, 11.4, 11.4, N'CS', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1005', N'บะหมี่กึ่งสำเร็จรูป ลัง 30', 2.4, 2.4, 0.021, 0.021, 2.4, 2.4, N'CS', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1006', N'ผงซักฟอก 900 กรัม แพ็ค 12', 10.8, 10.8, 0.018, 0.018, 10.8, 10.8, N'CS', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1007', N'กระดาษชำระ 12 ม้วน', 1.9, 1.9, 0.045, 0.045, 1.9, 1.9, N'PK', '2026-08-05T09:00:00', N'seed'),
    (N'STD', N'STD', 0, N'A', N'Y', N'GEN', N'STD', N'STD', N'STD', N'STAGE', 1, N'N', 0, N'STD', N'RETURNS', N'QC', N'S', 5, 20, 0, 0, 0, 0, 0, 0, N'WSK', N'MAMMOD', N'SKU-1008', N'นมยูเอชที 200ml แพ็ค 36', 7.6, 7.6, 0.013, 0.013, 7.6, 7.6, N'CS', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_USER';
INSERT INTO dbo.MST_USER
    ([USERKEY], [USERNAME], [EMAIL], [DISPLAYNAME], [PASSWORDHASH], [ROLECODE], [DEFAULT_WHSEID], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'admin', N'admin', N'admin@example.test', N'ผู้ดูแลระบบ', N'!! NOT A HASH — login does not verify passwords yet !!', N'ADMIN', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'manager', N'manager', N'manager@example.test', N'ผู้จัดการ', N'!! NOT A HASH — login does not verify passwords yet !!', N'MANAGER', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'operator', N'operator', N'operator@example.test', N'ผู้ปฏิบัติงาน', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'viewer', N'viewer', N'viewer@example.test', N'ผู้ดูข้อมูล', N'!! NOT A HASH — login does not verify passwords yet !!', N'VIEWER', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'tms', N'tms', N'tms@example.test', N'ฝ่ายขนส่ง (TMS)', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'inbound', N'inbound', N'inbound@example.test', N'ฝ่ายรับสินค้า', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'outbound', N'outbound', N'outbound@example.test', N'ฝ่ายจัดส่งออก', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'warehouse', N'warehouse', N'warehouse@example.test', N'ฝ่ายคลังสินค้า', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'inventory', N'inventory', N'inventory@example.test', N'ฝ่ายสต็อก', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'reports', N'reports', N'reports@example.test', N'ฝ่ายรายงาน', N'!! NOT A HASH — login does not verify passwords yet !!', N'VIEWER', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed'),
    (N'wms', N'wms', N'wms@example.test', N'ฝ่ายคลัง (WMS)', N'!! NOT A HASH — login does not verify passwords yet !!', N'OPERATOR', N'WSK', N'ACTIVE', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  MST_USER_MODULE';
INSERT INTO dbo.MST_USER_MODULE
    ([USERKEY], [MODULEPATH], [ADDDATE], [ADDWHO])
VALUES
    (N'tms', N'/logistics', '2026-08-05T09:00:00', N'seed'),
    (N'inbound', N'/inbound', '2026-08-05T09:00:00', N'seed'),
    (N'outbound', N'/outbound', '2026-08-05T09:00:00', N'seed'),
    (N'warehouse', N'/warehouse', '2026-08-05T09:00:00', N'seed'),
    (N'inventory', N'/inventory', '2026-08-05T09:00:00', N'seed'),
    (N'reports', N'/reports', '2026-08-05T09:00:00', N'seed'),
    (N'wms', N'/inbound', '2026-08-05T09:00:00', N'seed'),
    (N'wms', N'/outbound', '2026-08-05T09:00:00', N'seed'),
    (N'wms', N'/warehouse', '2026-08-05T09:00:00', N'seed'),
    (N'wms', N'/inventory', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_DO_HDR';
INSERT INTO dbo.DOC_DO_HDR
    ([WHSEID], [ORDERKEY], [OWNERKEY], [EXTERNORDERKEY], [ORDERDATE], [DELIVERYDATE], [PRIORITY], [SHIPTO], [C_COMPANY], [DOOR], [BATCHFLAG], [STATUS], [TYPE], [ORDERGROUP], [ROUTE], [ZONE], [ADDDATE], [ADDWHO])
VALUES
    (N'WWP', N'DO-2026-9001', N'MAMMOD', N'SO-99200001', '2026-07-19T17:00:00', '2026-08-11', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9002', N'MAMMOD', N'SO-99200002', '2026-07-22T17:00:00', '2026-07-24', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9003', N'MAMMOD', N'SO-99200003', '2026-07-31T16:00:00', '2026-07-24', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9004', N'MAMMOD', N'SO-99200004', '2026-07-23T15:00:00', '2026-08-02', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9005', N'MAMMOD', N'SO-99200005', '2026-07-24T12:00:00', '2026-07-31', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9006', N'MAMMOD', N'SO-99200006', '2026-07-18T07:00:00', '2026-07-28', N'5', N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-001', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9007', N'MAMMOD', N'SO-99200007', '2026-07-26T11:00:00', '2026-08-06', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9008', N'MAMMOD', N'SO-99200008', '2026-07-21T12:00:00', '2026-07-24', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9009', N'MAMMOD', N'SO-99200009', '2026-07-24T13:00:00', '2026-08-08', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9010', N'MAMMOD', N'SO-99200010', '2026-07-26T06:00:00', '2026-08-04', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9011', N'MAMMOD', N'SO-99200011', '2026-07-16T15:00:00', '2026-08-02', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9012', N'MAMMOD', N'SO-99200012', '2026-07-31T16:00:00', '2026-08-03', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9013', N'MAMMOD', N'SO-99200013', '2026-08-03T07:00:00', '2026-08-02', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9014', N'MAMMOD', N'SO-99200014', '2026-07-25T16:00:00', '2026-08-10', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9015', N'MAMMOD', N'SO-99200015', '2026-07-30T12:00:00', '2026-07-31', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9016', N'MAMMOD', N'SO-99200016', '2026-07-28T06:00:00', '2026-08-04', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9017', N'MAMMOD', N'SO-99200017', '2026-07-31T15:00:00', '2026-08-03', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9018', N'MAMMOD', N'SO-99200018', '2026-07-22T15:00:00', '2026-08-11', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9019', N'MAMMOD', N'SO-99200019', '2026-07-29T07:00:00', '2026-08-07', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9020', N'MAMMOD', N'SO-99200020', '2026-07-25T17:00:00', '2026-07-28', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9021', N'MAMMOD', N'SO-99200021', '2026-07-20T16:00:00', '2026-08-04', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9022', N'MAMMOD', N'SO-99200022', '2026-07-24T08:00:00', '2026-07-31', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9023', N'MAMMOD', N'SO-99200023', '2026-07-20T17:00:00', '2026-07-24', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9024', N'MAMMOD', N'SO-99200024', '2026-08-03T09:00:00', '2026-08-02', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9025', N'MAMMOD', N'SO-99200025', '2026-07-16T12:00:00', '2026-08-08', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9026', N'MAMMOD', N'SO-99200026', '2026-07-18T16:00:00', '2026-07-31', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9027', N'MAMMOD', N'SO-99200027', '2026-08-03T15:00:00', '2026-07-31', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9028', N'MAMMOD', N'SO-99200028', '2026-07-25T18:00:00', '2026-08-07', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9029', N'MAMMOD', N'SO-99200029', '2026-07-31T18:00:00', '2026-08-04', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9030', N'MAMMOD', N'SO-99200030', '2026-07-25T17:00:00', '2026-08-04', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9031', N'MAMMOD', N'SO-99200031', '2026-07-26T13:00:00', '2026-08-04', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9032', N'MAMMOD', N'SO-99200032', '2026-07-19T15:00:00', '2026-08-05', N'5', N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-001', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9033', N'MAMMOD', N'SO-99200033', '2026-07-17T10:00:00', '2026-08-08', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9034', N'MAMMOD', N'SO-99200034', '2026-08-04T11:00:00', '2026-08-09', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9035', N'MAMMOD', N'SO-99200035', '2026-07-23T14:00:00', '2026-08-09', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9036', N'MAMMOD', N'SO-99200036', '2026-07-27T12:00:00', '2026-08-02', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9037', N'MAMMOD', N'SO-99200037', '2026-08-04T16:00:00', '2026-08-10', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9038', N'MAMMOD', N'SO-99200038', '2026-07-31T11:00:00', '2026-08-06', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9039', N'MAMMOD', N'SO-99200039', '2026-07-22T07:00:00', '2026-07-28', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9040', N'MAMMOD', N'SO-99200040', '2026-07-25T07:00:00', '2026-08-05', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_DO_DETAIL';
INSERT INTO dbo.DOC_DO_DETAIL
    ([MANUFACTURERSKU], [RETAILSKU], [ALTSKU], [SHIPPEDQTY], [ADJUSTEDQTY], [QTYPREALLOCATED], [QTYALLOCATED], [QTYPICKED], [PACKKEY], [CARTONGROUP], [LOT], [ID], [FACILITY], [TAX01], [TAX02], [UPDATESOURCE], [LOTTABLE01], [LOTTABLE02], [LOTTABLE03], [LOTTABLE06], [LOTTABLE07], [LOTTABLE08], [LOTTABLE09], [LOTTABLE10], [WHSEID], [ORDERKEY], [ORDERLINENUMBER], [EXTERNORDERKEY], [EXTERNLINENO], [SKU], [OWNERKEY], [ORIGINALQTY], [OPENQTY], [UOM], [STATUS], [UNITPRICE], [EXTENDEDPRICE], [PRODUCT_WEIGHT], [PRODUCT_CUBE], [ADDDATE], [ADDWHO])
VALUES
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9001', N'00001', N'SO-99200001', N'1', N'SKU-1006', N'MAMMOD', 264, 264, N'CS', N'NEW', 43, 11352, 2851.2, 4.752, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9002', N'00001', N'SO-99200002', N'1', N'SKU-1002', N'MAMMOD', 84, 84, N'CS', N'NEW', 26, 2184, 722.4, 1.26, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9003', N'00001', N'SO-99200003', N'1', N'SKU-1004', N'MAMMOD', 94, 94, N'CS', N'NEW', 41, 3854, 1071.6, 1.316, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9004', N'00001', N'SO-99200004', N'1', N'SKU-1006', N'MAMMOD', 144, 144, N'CS', N'NEW', 43, 6192, 1555.2, 2.592, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9005', N'00001', N'SO-99200005', N'1', N'SKU-1006', N'MAMMOD', 33, 33, N'CS', N'NEW', 43, 1419, 356.4, 0.594, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9006', N'00001', N'SO-99200006', N'1', N'SKU-1001', N'MAMMOD', 14, 14, N'CS', N'NEW', 50, 700, 100.8, 0.168, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00001', N'SO-99200007', N'1', N'SKU-1001', N'MAMMOD', 41, 41, N'CS', N'NEW', 50, 2050, 295.2, 0.492, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00002', N'SO-99200007', N'2', N'SKU-1008', N'MAMMOD', 118, 118, N'CS', N'NEW', 30, 3540, 896.8, 1.534, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00003', N'SO-99200007', N'3', N'SKU-1002', N'MAMMOD', 39, 39, N'CS', N'NEW', 26, 1014, 335.4, 0.585, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9008', N'00001', N'SO-99200008', N'1', N'SKU-1002', N'MAMMOD', 159, 159, N'CS', N'NEW', 26, 4134, 1367.4, 2.385, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9008', N'00002', N'SO-99200008', N'2', N'SKU-1003', N'MAMMOD', 212, 212, N'BG', N'NEW', 30, 6360, 1060.0, 1.484, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9008', N'00003', N'SO-99200008', N'3', N'SKU-1006', N'MAMMOD', 16, 16, N'CS', N'NEW', 43, 688, 172.8, 0.288, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9008', N'00004', N'SO-99200008', N'4', N'SKU-1005', N'MAMMOD', 120, 120, N'CS', N'NEW', 18, 2160, 288.0, 2.52, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9009', N'00001', N'SO-99200009', N'1', N'SKU-1008', N'MAMMOD', 120, 120, N'CS', N'NEW', 30, 3600, 912.0, 1.56, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9009', N'00002', N'SO-99200009', N'2', N'SKU-1002', N'MAMMOD', 238, 238, N'CS', N'NEW', 26, 6188, 2046.8, 3.57, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9010', N'00001', N'SO-99200010', N'1', N'SKU-1005', N'MAMMOD', 111, 111, N'CS', N'NEW', 18, 1998, 266.4, 2.331, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9011', N'00001', N'SO-99200011', N'1', N'SKU-1007', N'MAMMOD', 69, 69, N'PK', N'NEW', 52, 3588, 131.1, 3.105, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9012', N'00001', N'SO-99200012', N'1', N'SKU-1002', N'MAMMOD', 75, 75, N'CS', N'NEW', 26, 1950, 645.0, 1.125, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9012', N'00002', N'SO-99200012', N'2', N'SKU-1001', N'MAMMOD', 135, 135, N'CS', N'NEW', 50, 6750, 972.0, 1.62, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9012', N'00003', N'SO-99200012', N'3', N'SKU-1002', N'MAMMOD', 143, 143, N'CS', N'NEW', 26, 3718, 1229.8, 2.145, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9012', N'00004', N'SO-99200012', N'4', N'SKU-1007', N'MAMMOD', 238, 238, N'PK', N'NEW', 52, 12376, 452.2, 10.71, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9013', N'00001', N'SO-99200013', N'1', N'SKU-1007', N'MAMMOD', 71, 71, N'PK', N'NEW', 52, 3692, 134.9, 3.195, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9013', N'00002', N'SO-99200013', N'2', N'SKU-1002', N'MAMMOD', 60, 60, N'CS', N'NEW', 26, 1560, 516.0, 0.9, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9013', N'00003', N'SO-99200013', N'3', N'SKU-1007', N'MAMMOD', 78, 78, N'PK', N'NEW', 52, 4056, 148.2, 3.51, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9013', N'00004', N'SO-99200013', N'4', N'SKU-1003', N'MAMMOD', 13, 13, N'BG', N'NEW', 30, 390, 65.0, 0.091, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9014', N'00001', N'SO-99200014', N'1', N'SKU-1003', N'MAMMOD', 270, 270, N'BG', N'NEW', 30, 8100, 1350.0, 1.89, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9014', N'00002', N'SO-99200014', N'2', N'SKU-1004', N'MAMMOD', 292, 292, N'CS', N'NEW', 41, 11972, 3328.8, 4.088, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9014', N'00003', N'SO-99200014', N'3', N'SKU-1001', N'MAMMOD', 24, 24, N'CS', N'NEW', 50, 1200, 172.8, 0.288, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9015', N'00001', N'SO-99200015', N'1', N'SKU-1005', N'MAMMOD', 281, 281, N'CS', N'NEW', 18, 5058, 674.4, 5.901, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9015', N'00002', N'SO-99200015', N'2', N'SKU-1004', N'MAMMOD', 112, 112, N'CS', N'NEW', 41, 4592, 1276.8, 1.568, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9015', N'00003', N'SO-99200015', N'3', N'SKU-1004', N'MAMMOD', 183, 183, N'CS', N'NEW', 41, 7503, 2086.2, 2.562, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9016', N'00001', N'SO-99200016', N'1', N'SKU-1006', N'MAMMOD', 24, 24, N'CS', N'NEW', 43, 1032, 259.2, 0.432, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9016', N'00002', N'SO-99200016', N'2', N'SKU-1002', N'MAMMOD', 298, 298, N'CS', N'NEW', 26, 7748, 2562.8, 4.47, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9017', N'00001', N'SO-99200017', N'1', N'SKU-1005', N'MAMMOD', 292, 292, N'CS', N'NEW', 18, 5256, 700.8, 6.132, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9017', N'00002', N'SO-99200017', N'2', N'SKU-1003', N'MAMMOD', 29, 29, N'BG', N'NEW', 30, 870, 145.0, 0.203, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9017', N'00003', N'SO-99200017', N'3', N'SKU-1008', N'MAMMOD', 8, 8, N'CS', N'NEW', 30, 240, 60.8, 0.104, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9017', N'00004', N'SO-99200017', N'4', N'SKU-1003', N'MAMMOD', 87, 87, N'BG', N'NEW', 30, 2610, 435.0, 0.609, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9018', N'00001', N'SO-99200018', N'1', N'SKU-1002', N'MAMMOD', 163, 163, N'CS', N'NEW', 26, 4238, 1401.8, 2.445, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9018', N'00002', N'SO-99200018', N'2', N'SKU-1002', N'MAMMOD', 283, 283, N'CS', N'NEW', 26, 7358, 2433.8, 4.245, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9018', N'00003', N'SO-99200018', N'3', N'SKU-1003', N'MAMMOD', 92, 92, N'BG', N'NEW', 30, 2760, 460.0, 0.644, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9019', N'00001', N'SO-99200019', N'1', N'SKU-1005', N'MAMMOD', 184, 184, N'CS', N'NEW', 18, 3312, 441.6, 3.864, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9020', N'00001', N'SO-99200020', N'1', N'SKU-1008', N'MAMMOD', 45, 45, N'CS', N'NEW', 30, 1350, 342.0, 0.585, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9021', N'00001', N'SO-99200021', N'1', N'SKU-1006', N'MAMMOD', 236, 236, N'CS', N'NEW', 43, 10148, 2548.8, 4.248, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9022', N'00001', N'SO-99200022', N'1', N'SKU-1007', N'MAMMOD', 136, 136, N'PK', N'NEW', 52, 7072, 258.4, 6.12, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9022', N'00002', N'SO-99200022', N'2', N'SKU-1003', N'MAMMOD', 170, 170, N'BG', N'NEW', 30, 5100, 850.0, 1.19, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9023', N'00001', N'SO-99200023', N'1', N'SKU-1003', N'MAMMOD', 70, 70, N'BG', N'NEW', 30, 2100, 350.0, 0.49, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00001', N'SO-99200024', N'1', N'SKU-1004', N'MAMMOD', 43, 43, N'CS', N'NEW', 41, 1763, 490.2, 0.602, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00002', N'SO-99200024', N'2', N'SKU-1008', N'MAMMOD', 183, 183, N'CS', N'NEW', 30, 5490, 1390.8, 2.379, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9025', N'00001', N'SO-99200025', N'1', N'SKU-1002', N'MAMMOD', 275, 275, N'CS', N'NEW', 26, 7150, 2365.0, 4.125, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9025', N'00002', N'SO-99200025', N'2', N'SKU-1006', N'MAMMOD', 161, 161, N'CS', N'NEW', 43, 6923, 1738.8, 2.898, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00001', N'SO-99200026', N'1', N'SKU-1008', N'MAMMOD', 224, 224, N'CS', N'NEW', 30, 6720, 1702.4, 2.912, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00002', N'SO-99200026', N'2', N'SKU-1005', N'MAMMOD', 23, 23, N'CS', N'NEW', 18, 414, 55.2, 0.483, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00003', N'SO-99200026', N'3', N'SKU-1004', N'MAMMOD', 262, 262, N'CS', N'NEW', 41, 10742, 2986.8, 3.668, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00004', N'SO-99200026', N'4', N'SKU-1006', N'MAMMOD', 20, 20, N'CS', N'NEW', 43, 860, 216.0, 0.36, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9027', N'00001', N'SO-99200027', N'1', N'SKU-1007', N'MAMMOD', 231, 231, N'PK', N'NEW', 52, 12012, 438.9, 10.395, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9028', N'00001', N'SO-99200028', N'1', N'SKU-1001', N'MAMMOD', 247, 247, N'CS', N'NEW', 50, 12350, 1778.4, 2.964, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9028', N'00002', N'SO-99200028', N'2', N'SKU-1008', N'MAMMOD', 59, 59, N'CS', N'NEW', 30, 1770, 448.4, 0.767, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9028', N'00003', N'SO-99200028', N'3', N'SKU-1001', N'MAMMOD', 189, 189, N'CS', N'NEW', 50, 9450, 1360.8, 2.268, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9029', N'00001', N'SO-99200029', N'1', N'SKU-1007', N'MAMMOD', 288, 288, N'PK', N'NEW', 52, 14976, 547.2, 12.96, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9030', N'00001', N'SO-99200030', N'1', N'SKU-1007', N'MAMMOD', 84, 84, N'PK', N'NEW', 52, 4368, 159.6, 3.78, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9030', N'00002', N'SO-99200030', N'2', N'SKU-1006', N'MAMMOD', 167, 167, N'CS', N'NEW', 43, 7181, 1803.6, 3.006, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9030', N'00003', N'SO-99200030', N'3', N'SKU-1003', N'MAMMOD', 179, 179, N'BG', N'NEW', 30, 5370, 895.0, 1.253, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9031', N'00001', N'SO-99200031', N'1', N'SKU-1007', N'MAMMOD', 254, 254, N'PK', N'NEW', 52, 13208, 482.6, 11.43, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9031', N'00002', N'SO-99200031', N'2', N'SKU-1002', N'MAMMOD', 209, 209, N'CS', N'NEW', 26, 5434, 1797.4, 3.135, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9031', N'00003', N'SO-99200031', N'3', N'SKU-1004', N'MAMMOD', 220, 220, N'CS', N'NEW', 41, 9020, 2508.0, 3.08, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9031', N'00004', N'SO-99200031', N'4', N'SKU-1002', N'MAMMOD', 91, 91, N'CS', N'NEW', 26, 2366, 782.6, 1.365, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9032', N'00001', N'SO-99200032', N'1', N'SKU-1002', N'MAMMOD', 206, 206, N'CS', N'NEW', 26, 5356, 1771.6, 3.09, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9032', N'00002', N'SO-99200032', N'2', N'SKU-1002', N'MAMMOD', 161, 161, N'CS', N'NEW', 26, 4186, 1384.6, 2.415, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9033', N'00001', N'SO-99200033', N'1', N'SKU-1007', N'MAMMOD', 79, 79, N'PK', N'NEW', 52, 4108, 150.1, 3.555, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9033', N'00002', N'SO-99200033', N'2', N'SKU-1006', N'MAMMOD', 52, 52, N'CS', N'NEW', 43, 2236, 561.6, 0.936, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9033', N'00003', N'SO-99200033', N'3', N'SKU-1001', N'MAMMOD', 16, 16, N'CS', N'NEW', 50, 800, 115.2, 0.192, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9034', N'00001', N'SO-99200034', N'1', N'SKU-1008', N'MAMMOD', 211, 211, N'CS', N'NEW', 30, 6330, 1603.6, 2.743, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9034', N'00002', N'SO-99200034', N'2', N'SKU-1002', N'MAMMOD', 135, 135, N'CS', N'NEW', 26, 3510, 1161.0, 2.025, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9035', N'00001', N'SO-99200035', N'1', N'SKU-1008', N'MAMMOD', 239, 239, N'CS', N'NEW', 30, 7170, 1816.4, 3.107, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9036', N'00001', N'SO-99200036', N'1', N'SKU-1002', N'MAMMOD', 131, 131, N'CS', N'NEW', 26, 3406, 1126.6, 1.965, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9037', N'00001', N'SO-99200037', N'1', N'SKU-1002', N'MAMMOD', 42, 42, N'CS', N'NEW', 26, 1092, 361.2, 0.63, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9037', N'00002', N'SO-99200037', N'2', N'SKU-1001', N'MAMMOD', 244, 244, N'CS', N'NEW', 50, 12200, 1756.8, 2.928, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9037', N'00003', N'SO-99200037', N'3', N'SKU-1007', N'MAMMOD', 95, 95, N'PK', N'NEW', 52, 4940, 180.5, 4.275, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9037', N'00004', N'SO-99200037', N'4', N'SKU-1008', N'MAMMOD', 235, 235, N'CS', N'NEW', 30, 7050, 1786.0, 3.055, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9038', N'00001', N'SO-99200038', N'1', N'SKU-1006', N'MAMMOD', 78, 78, N'CS', N'NEW', 43, 3354, 842.4, 1.404, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9038', N'00002', N'SO-99200038', N'2', N'SKU-1004', N'MAMMOD', 147, 147, N'CS', N'NEW', 41, 6027, 1675.8, 2.058, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00001', N'SO-99200039', N'1', N'SKU-1003', N'MAMMOD', 286, 286, N'BG', N'NEW', 30, 8580, 1430.0, 2.002, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00002', N'SO-99200039', N'2', N'SKU-1007', N'MAMMOD', 152, 152, N'PK', N'NEW', 52, 7904, 288.8, 6.84, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00003', N'SO-99200039', N'3', N'SKU-1004', N'MAMMOD', 21, 21, N'CS', N'NEW', 41, 861, 239.4, 0.294, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9040', N'00001', N'SO-99200040', N'1', N'SKU-1004', N'MAMMOD', 152, 152, N'CS', N'NEW', 41, 6232, 1732.8, 2.128, '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_TRANSPORT_PLAN';
INSERT INTO dbo.DOC_TRANSPORT_PLAN
    ([WHSEID], [PLANKEY], [PLANDATE], [DELIVERYDATE], [ZONE], [ROUTE], [TOTALORDER], [STATUS], [NOTES], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'PL-202608-0001', '2026-08-05T09:00:00', '2026-08-07', N'TH-001', N'RT-NORTH-01', 0, N'DRAFT', N'รอบเช้า สายเหนือ', '2026-08-05T09:00:00', N'seed');
GO

-- DOC_TRANSPORT_PLAN_LINE: ไม่มีแถว

PRINT '  DOC_SHIPMENT_HDR';
INSERT INTO dbo.DOC_SHIPMENT_HDR
    ([WHSEID], [SHIPMENTKEY], [SHIPMENTDATE], [DELIVERYDATE], [ROUTE], [ZONE], [TRANSPORTERKEY], [VEHICLEKEY], [DRIVERKEY], [SEALNO], [DOOR], [TOTALSTOP], [ESTIMATEDCOST], [ACTUALCOST], [STATUS], [STATUSMESSAGE], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MN-202608-0043', '2026-08-05T09:00:00', '2026-08-06', N'RT-NORTH-01', N'TH-001', N'CR-001', N'VH-002', N'DRV-001', NULL, N'Dock 3', 2, 0, 0, N'DRAFT', NULL, '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', '2026-08-04T09:00:00', '2026-08-05', N'RT-WEST-02', N'TH-009', N'CR-002', N'VH-005', N'DRV-005', N'SL-9988431', N'Dock 1', 2, 7200, 7200, N'CONFIRMED', NULL, '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', '2026-08-03T09:00:00', '2026-08-04', N'RT-EAST-01', N'TH-007', N'CR-001', N'VH-001', N'DRV-002', N'SL-9988420', N'Dock 2', 2, 0, 0, N'SENT', NULL, '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', '2026-08-02T09:00:00', '2026-08-03', N'RT-WEST-02', N'TH-009', N'CR-002', N'VH-003', N'DRV-004', N'SL-9988418', N'Dock 1', 2, 8500, 8500, N'COMPLETED', N'OMS ยืนยันการจัดส่งครบถ้วน', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', '2026-08-01T09:00:00', '2026-08-02', N'RT-EAST-01', N'TH-007', N'CR-003', N'VH-004', N'DRV-003', N'SL-9988409', N'Dock 2', 2, 6400, 6400, N'ERROR', N'WMS ตีกลับ — จำนวนกล่องไม่ตรงกับใบสั่งส่ง DO-2026-0786', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SHIPMENT_STOP';
INSERT INTO dbo.DOC_SHIPMENT_STOP
    ([WHSEID], [SHIPMENTKEY], [SHIPMENTSTOPID], [STOPSEQ], [CUSTOMERKEY], [SHIPTONAME], [ADDRESS1], [DISTRICT], [PROVINCE], [POSTALCODE], [LATITUDE], [LONGITUDE], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MN-202608-0043', 1, 1, N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'125/7 ถนนสวรรค์วิถี', N'อำเภอเมืองนครสวรรค์', N'นครสวรรค์', N'60000', 15.7047, 100.1372, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 2, N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'302 ถนนพิชัยสงคราม', N'อำเภอเมืองพิษณุโลก', N'พิษณุโลก', N'65000', 16.8211, 100.2659, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 1, N'CUS-0009', N'นครปฐมค้าส่ง', N'12 ถนนเพชรเกษม', N'อำเภอเมืองนครปฐม', N'นครปฐม', N'73000', 13.8199, 100.0621, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 2, N'CUS-0010', N'ราชบุรีมาร์ท', N'410 ถนนศรีสุริยวงศ์', N'อำเภอเมืองราชบุรี', N'ราชบุรี', N'70000', 13.5282, 99.8134, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 1, N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'199 ถนนสุขุมวิท', N'อำเภอศรีราชา', N'ชลบุรี', N'20110', 13.1731, 100.931, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 2, N'CUS-0008', N'ระยองฟู้ดส์', N'56 ถนนสุขุมวิท', N'อำเภอเมืองระยอง', N'ระยอง', N'21000', 12.6814, 101.2816, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 1, N'CUS-0009', N'นครปฐมค้าส่ง', N'12 ถนนเพชรเกษม', N'อำเภอเมืองนครปฐม', N'นครปฐม', N'73000', 13.8199, 100.0621, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 2, N'CUS-0010', N'ราชบุรีมาร์ท', N'410 ถนนศรีสุริยวงศ์', N'อำเภอเมืองราชบุรี', N'ราชบุรี', N'70000', 13.5282, 99.8134, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 1, N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'199 ถนนสุขุมวิท', N'อำเภอศรีราชา', N'ชลบุรี', N'20110', 13.1731, 100.931, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 2, N'CUS-0008', N'ระยองฟู้ดส์', N'56 ถนนสุขุมวิท', N'อำเภอเมืองระยอง', N'ระยอง', N'21000', 12.6814, 101.2816, N'NEW', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SHIPMENT_DETAIL';
INSERT INTO dbo.DOC_SHIPMENT_DETAIL
    ([WHSEID], [SHIPMENTKEY], [SHIPMENTDETAILID], [SHIPMENTSTOPID], [ORDERKEY], [EXTERNORDERKEY], [OWNERKEY], [ROUTE], [ZONE], [REQUIREDDELIVERYDATE], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MN-202608-0043', 1, 1, N'DO-2026-0701', N'SO-9910701', N'MAMMOD', N'RT-NORTH-01', N'TH-001', '2026-08-06', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 2, N'DO-2026-0702', N'SO-9910702', N'MAMMOD', N'RT-NORTH-01', N'TH-003', '2026-08-06', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 1, N'DO-2026-0703', N'SO-9910703', N'MAMMOD', N'RT-WEST-02', N'TH-009', '2026-08-05', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 2, N'DO-2026-0704', N'SO-9910704', N'MAMMOD', N'RT-WEST-02', N'TH-010', '2026-08-05', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 1, N'DO-2026-0705', N'SO-9910705', N'MAMMOD', N'RT-EAST-01', N'TH-007', '2026-08-04', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 2, N'DO-2026-0706', N'SO-9910706', N'MAMMOD', N'RT-EAST-01', N'TH-008', '2026-08-04', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 1, N'DO-2026-0707', N'SO-9910707', N'MAMMOD', N'RT-WEST-02', N'TH-009', '2026-08-03', N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 2, N'DO-2026-0708', N'SO-9910708', N'MAMMOD', N'RT-WEST-02', N'TH-010', '2026-08-03', N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 1, N'DO-2026-0709', N'SO-9910709', N'MAMMOD', N'RT-EAST-01', N'TH-007', '2026-08-02', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 2, N'DO-2026-0710', N'SO-9910710', N'MAMMOD', N'RT-EAST-01', N'TH-008', '2026-08-02', N'NEW', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SHIPMENT_DETAIL_LINE';
INSERT INTO dbo.DOC_SHIPMENT_DETAIL_LINE
    ([WHSEID], [SHIPMENTKEY], [SHIPMENTDETAILID], [SHIPMENTLINENO], [ORDERKEY], [ORDERLINENO], [SKU], [UOM], [ORDERQTY], [SHIPMENTQTY], [PICKEDQTY], [LOADEDQTY], [DELIVEREDQTY], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MN-202608-0043', 1, 1, N'DO-2026-0701', N'1', N'SKU-1004', N'CS', 152, 152, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 1, 2, N'DO-2026-0701', N'2', N'SKU-1004', N'CS', 23, 23, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 1, N'DO-2026-0702', N'1', N'SKU-1008', N'CS', 93, 93, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 2, N'DO-2026-0702', N'2', N'SKU-1001', N'CS', 147, 147, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 1, N'DO-2026-0703', N'1', N'SKU-1003', N'BG', 147, 147, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 2, N'DO-2026-0703', N'2', N'SKU-1002', N'CS', 164, 164, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 1, N'DO-2026-0704', N'1', N'SKU-1001', N'CS', 65, 65, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 2, N'DO-2026-0704', N'2', N'SKU-1004', N'CS', 121, 121, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 1, N'DO-2026-0705', N'1', N'SKU-1006', N'CS', 86, 86, 86, 86, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 2, N'DO-2026-0705', N'2', N'SKU-1004', N'CS', 58, 58, 58, 58, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 1, N'DO-2026-0706', N'1', N'SKU-1004', N'CS', 172, 172, 172, 172, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 2, N'DO-2026-0706', N'2', N'SKU-1001', N'CS', 42, 42, 42, 42, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 1, N'DO-2026-0707', N'1', N'SKU-1005', N'CS', 192, 192, 192, 192, 192, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 2, N'DO-2026-0707', N'2', N'SKU-1008', N'CS', 159, 159, 159, 159, 159, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 1, N'DO-2026-0708', N'1', N'SKU-1008', N'CS', 76, 76, 76, 76, 76, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 2, N'DO-2026-0708', N'2', N'SKU-1005', N'CS', 114, 114, 114, 114, 114, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 1, N'DO-2026-0709', N'1', N'SKU-1008', N'CS', 72, 72, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 2, N'DO-2026-0709', N'2', N'SKU-1001', N'CS', 29, 29, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 1, N'DO-2026-0710', N'1', N'SKU-1006', N'CS', 124, 124, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 2, N'DO-2026-0710', N'2', N'SKU-1002', N'CS', 128, 128, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SHIPMENT_STATUS_LOG';
INSERT INTO dbo.DOC_SHIPMENT_STATUS_LOG
    ([WHSEID], [SHIPMENTKEY], [FROMSTATUS], [TOSTATUS], [SOURCESYSTEM], [MESSAGE], [CHANGEDATE], [CHANGEWHO])
VALUES
    (N'WSK', N'MN-202608-0043', NULL, N'DRAFT', N'TMS', NULL, '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', NULL, N'DRAFT', N'TMS', NULL, '2026-08-04T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', N'DRAFT', N'CONFIRMED', N'TMS', NULL, '2026-08-04T09:25:00', N'seed'),
    (N'WSK', N'MN-202608-0041', NULL, N'DRAFT', N'TMS', NULL, '2026-08-03T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', N'DRAFT', N'CONFIRMED', N'TMS', NULL, '2026-08-03T09:25:00', N'seed'),
    (N'WSK', N'MN-202608-0041', N'CONFIRMED', N'SENT', N'TMS', NULL, '2026-08-03T09:50:00', N'seed'),
    (N'WPD', N'MN-202608-0040', NULL, N'DRAFT', N'TMS', NULL, '2026-08-02T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', N'DRAFT', N'CONFIRMED', N'TMS', NULL, '2026-08-02T09:25:00', N'seed'),
    (N'WPD', N'MN-202608-0040', N'CONFIRMED', N'SENT', N'TMS', NULL, '2026-08-02T09:50:00', N'seed'),
    (N'WPD', N'MN-202608-0040', N'SENT', N'COMPLETED', N'OMS', N'OMS ยืนยันการจัดส่งครบถ้วน', '2026-08-02T10:15:00', N'seed'),
    (N'WWP', N'MN-202608-0039', NULL, N'DRAFT', N'TMS', NULL, '2026-08-01T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', N'DRAFT', N'CONFIRMED', N'TMS', NULL, '2026-08-01T09:25:00', N'seed'),
    (N'WWP', N'MN-202608-0039', N'CONFIRMED', N'SENT', N'TMS', NULL, '2026-08-01T09:50:00', N'seed'),
    (N'WWP', N'MN-202608-0039', N'SENT', N'ERROR', N'OMS', N'WMS ตีกลับ — จำนวนกล่องไม่ตรงกับใบสั่งส่ง DO-2026-0786', '2026-08-01T10:15:00', N'seed');
GO


COMMIT TRANSACTION;
GO

PRINT '';
PRINT 'rows now in the database';
SELECT  t.name AS [table], SUM(p.rows) AS [rows]
FROM    sys.tables t
JOIN    sys.partitions p ON p.object_id = t.object_id AND p.index_id IN (0, 1)
GROUP BY t.name
HAVING  SUM(p.rows) > 0
ORDER BY t.name;
GO
