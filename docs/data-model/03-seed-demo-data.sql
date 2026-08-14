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
DELETE FROM dbo.DOC_SO_DETAIL;
DELETE FROM dbo.DOC_SO_HDR;
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

PRINT '  DOC_SO_HDR';
INSERT INTO dbo.DOC_SO_HDR
    ([WHSEID], [SOKEY], [OWNERKEY], [CUSTOMERKEY], [SHIPTO], [ORDERDATE], [REQUESTEDDATE], [SOURCESYSTEM], [CURRENCY], [TOTALAMOUNT], [TOTALLINE], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'SO-99200001', N'MAMMOD', N'CUS-0001', N'CUS-0001', '2026-08-02T18:00:00', '2026-08-06', N'OMS', N'THB', 10323, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200002', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-07-31T14:00:00', '2026-08-06', N'OMS', N'THB', 7896, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200003', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-08-03T06:00:00', '2026-08-05', N'OMS', N'THB', 5776, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200004', N'MAMMOD', N'CUS-0010', N'CUS-0010', '2026-08-02T17:00:00', '2026-08-05', N'OMS', N'THB', 12958, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200005', N'MAMMOD', N'CUS-0007', N'CUS-0007', '2026-07-29T15:00:00', '2026-08-04', N'OMS', N'THB', 18602, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200006', N'MAMMOD', N'CUS-0008', N'CUS-0008', '2026-08-02T18:00:00', '2026-08-04', N'OMS', N'THB', 14002, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200007', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-08-01T07:00:00', '2026-08-03', N'OMS', N'THB', 10521, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200008', N'MAMMOD', N'CUS-0010', N'CUS-0010', '2026-08-01T11:00:00', '2026-08-03', N'OMS', N'THB', 5124, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200009', N'MAMMOD', N'CUS-0007', N'CUS-0007', '2026-07-29T13:00:00', '2026-08-02', N'OMS', N'THB', 33788, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200010', N'MAMMOD', N'CUS-0008', N'CUS-0008', '2026-07-30T07:00:00', '2026-08-02', N'OMS', N'THB', 10472, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200011', N'MAMMOD', N'CUS-0001', N'CUS-0001', '2026-07-21T09:00:00', '2026-08-05', N'OMS', N'THB', 20420, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200012', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-07-30T06:00:00', '2026-08-10', N'OMS', N'THB', 17190, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200013', N'MAMMOD', N'CUS-0004', N'CUS-0004', '2026-07-29T08:00:00', '2026-08-08', N'OMS', N'THB', 7791, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200014', N'MAMMOD', N'CUS-0005', N'CUS-0005', '2026-07-31T13:00:00', '2026-08-09', N'OMS', N'THB', 18194, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200015', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-08-01T08:00:00', '2026-08-06', N'OMS', N'THB', 30165, 4, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200016', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-07-28T06:00:00', '2026-08-04', N'OMS', N'THB', 35922, 3, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200017', N'MAMMOD', N'CUS-0007', N'CUS-0007', '2026-07-30T18:00:00', '2026-08-05', N'OMS', N'THB', 14722, 3, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200018', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-08-04T07:00:00', '2026-08-07', N'OMS', N'THB', 21971, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200019', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-07-23T08:00:00', '2026-08-03', N'OMS', N'THB', 8696, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200020', N'MAMMOD', N'CUS-0008', N'CUS-0008', '2026-07-17T16:00:00', '2026-08-07', N'OMS', N'THB', 15202, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200021', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-07-29T16:00:00', '2026-07-28', N'OMS', N'THB', 19760, 1, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200022', N'MAMMOD', N'CUS-0002', N'CUS-0002', '2026-07-25T16:00:00', '2026-08-10', N'OMS', N'THB', 1320, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200023', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-08-02T10:00:00', '2026-08-04', N'OMS', N'THB', 31128, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200024', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-08-04T08:00:00', '2026-08-10', N'OMS', N'THB', 14724, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200025', N'MAMMOD', N'CUS-0002', N'CUS-0002', '2026-07-24T14:00:00', '2026-08-07', N'OMS', N'THB', 21448, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200026', N'MAMMOD', N'CUS-0010', N'CUS-0010', '2026-07-22T11:00:00', '2026-08-11', N'OMS', N'THB', 26661, 3, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200027', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-08-03T08:00:00', '2026-08-08', N'OMS', N'THB', 5166, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200028', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-07-16T07:00:00', '2026-08-07', N'OMS', N'THB', 6006, 1, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200029', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-07-25T11:00:00', '2026-07-31', N'OMS', N'THB', 19770, 2, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200030', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-07-27T16:00:00', '2026-08-11', N'OMS', N'THB', 21650, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200031', N'MAMMOD', N'CUS-0007', N'CUS-0007', '2026-07-20T17:00:00', '2026-08-10', N'OMS', N'THB', 8022, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200032', N'MAMMOD', N'CUS-0007', N'CUS-0007', '2026-07-30T14:00:00', '2026-08-10', N'OMS', N'THB', 5481, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200033', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-08-01T15:00:00', '2026-08-05', N'OMS', N'THB', 8060, 1, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200034', N'MAMMOD', N'CUS-0005', N'CUS-0005', '2026-07-16T16:00:00', '2026-08-11', N'OMS', N'THB', 3593, 3, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200035', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-07-25T18:00:00', '2026-07-31', N'OMS', N'THB', 38408, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200036', N'MAMMOD', N'CUS-0008', N'CUS-0008', '2026-07-26T09:00:00', '2026-08-02', N'OMS', N'THB', 5464, 2, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200037', N'MAMMOD', N'CUS-0005', N'CUS-0005', '2026-08-04T13:00:00', '2026-08-09', N'OMS', N'THB', 23463, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200038', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-07-16T17:00:00', '2026-08-02', N'OMS', N'THB', 15856, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200039', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-07-16T07:00:00', '2026-07-31', N'OMS', N'THB', 28274, 4, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200040', N'MAMMOD', N'CUS-0004', N'CUS-0004', '2026-07-28T17:00:00', '2026-08-10', N'OMS', N'THB', 16552, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200041', N'MAMMOD', N'CUS-0003', N'CUS-0003', '2026-07-19T09:00:00', '2026-08-07', N'OMS', N'THB', 3330, 1, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200042', N'MAMMOD', N'CUS-0005', N'CUS-0005', '2026-07-31T10:00:00', '2026-08-12', N'OMS', N'THB', 17354, 2, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200043', N'MAMMOD', N'CUS-0009', N'CUS-0009', '2026-07-19T06:00:00', '2026-08-09', N'OMS', N'THB', 25801, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200044', N'MAMMOD', N'CUS-0002', N'CUS-0002', '2026-07-30T06:00:00', '2026-08-07', N'OMS', N'THB', 18199, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200045', N'MAMMOD', N'CUS-0006', N'CUS-0006', '2026-08-01T15:00:00', '2026-08-04', N'OMS', N'THB', 23258, 4, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200046', N'MAMMOD', N'CUS-0002', N'CUS-0002', '2026-07-30T06:00:00', '2026-08-10', N'OMS', N'THB', 35492, 3, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200047', N'MAMMOD', N'CUS-0002', N'CUS-0002', '2026-07-30T18:00:00', '2026-07-28', N'OMS', N'THB', 9352, 1, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200048', N'MAMMOD', N'CUS-0010', N'CUS-0010', '2026-07-24T12:00:00', '2026-08-07', N'OMS', N'THB', 29200, 3, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200049', N'MAMMOD', N'CUS-0005', N'CUS-0005', '2026-07-20T08:00:00', '2026-07-28', N'OMS', N'THB', 18076, 3, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200050', N'MAMMOD', N'CUS-0008', N'CUS-0008', '2026-07-30T11:00:00', '2026-08-11', N'OMS', N'THB', 17160, 1, N'CLOSED', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SO_DETAIL';
INSERT INTO dbo.DOC_SO_DETAIL
    ([WHSEID], [SOKEY], [SOLINENUMBER], [OWNERKEY], [SKU], [UOM], [ORDERQTY], [SHIPPEDQTY], [UNITPRICE], [EXTENDEDPRICE], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'SO-99200001', N'00001', N'MAMMOD', N'SKU-1006', N'CS', 279, 279, 37, 10323, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200002', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 376, 376, 21, 7896, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200003', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 152, 152, 38, 5776, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200004', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 109, 109, 30, 3270, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200004', N'00002', N'MAMMOD', N'SKU-1002', N'CS', 346, 346, 28, 9688, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200005', N'00001', N'MAMMOD', N'SKU-1008', N'CS', 331, 331, 22, 7282, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200005', N'00002', N'MAMMOD', N'SKU-1004', N'CS', 283, 283, 40, 11320, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200006', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 55, 55, 52, 2860, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200006', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 201, 201, 22, 4422, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200006', N'00003', N'MAMMOD', N'SKU-1002', N'CS', 240, 240, 28, 6720, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200007', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 78, 78, 30, 2340, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200007', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 306, 306, 22, 6732, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200007', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 69, 69, 21, 1449, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200008', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 244, 244, 21, 5124, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200009', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 323, 323, 52, 16796, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200009', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 334, 334, 30, 10020, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200009', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 332, 332, 21, 6972, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200010', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 374, 374, 28, 10472, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200011', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 180, 180, 28, 5040, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200011', N'00002', N'MAMMOD', N'SKU-1003', N'BG', 31, 31, 38, 1178, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200011', N'00003', N'MAMMOD', N'SKU-1008', N'CS', 351, 351, 22, 7722, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200011', N'00004', N'MAMMOD', N'SKU-1004', N'CS', 162, 162, 40, 6480, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200012', N'00001', N'MAMMOD', N'SKU-1004', N'CS', 136, 136, 40, 5440, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200012', N'00002', N'MAMMOD', N'SKU-1007', N'PK', 200, 200, 21, 4200, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200012', N'00003', N'MAMMOD', N'SKU-1001', N'CS', 127, 127, 30, 3810, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200012', N'00004', N'MAMMOD', N'SKU-1008', N'CS', 170, 170, 22, 3740, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200013', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 371, 371, 21, 7791, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200014', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 150, 75, 28, 4200, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200014', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 69, 34, 52, 3588, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200014', N'00003', N'MAMMOD', N'SKU-1008', N'CS', 158, 79, 22, 3476, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200014', N'00004', N'MAMMOD', N'SKU-1001', N'CS', 231, 115, 30, 6930, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200015', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 294, 0, 38, 11172, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200015', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 236, 0, 30, 7080, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200015', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 337, 0, 21, 7077, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200015', N'00004', N'MAMMOD', N'SKU-1005', N'CS', 93, 0, 52, 4836, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200016', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 307, 0, 38, 11666, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200016', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 285, 0, 52, 14820, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200016', N'00003', N'MAMMOD', N'SKU-1002', N'CS', 337, 0, 28, 9436, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200017', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 127, 63, 52, 6604, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200017', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 117, 58, 22, 2574, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200017', N'00003', N'MAMMOD', N'SKU-1002', N'CS', 198, 99, 28, 5544, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200018', N'00001', N'MAMMOD', N'SKU-1006', N'CS', 323, 323, 37, 11951, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200018', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 334, 334, 30, 10020, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200019', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 250, 250, 30, 7500, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200019', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 23, 23, 52, 1196, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200020', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 298, 298, 28, 8344, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200020', N'00002', N'MAMMOD', N'SKU-1003', N'BG', 96, 96, 38, 3648, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200020', N'00003', N'MAMMOD', N'SKU-1001', N'CS', 107, 107, 30, 3210, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200021', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 380, 190, 52, 19760, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200022', N'00001', N'MAMMOD', N'SKU-1008', N'CS', 60, 60, 22, 1320, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200023', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 111, 55, 38, 4218, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200023', N'00002', N'MAMMOD', N'SKU-1006', N'CS', 288, 144, 37, 10656, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200023', N'00003', N'MAMMOD', N'SKU-1008', N'CS', 231, 115, 22, 5082, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200023', N'00004', N'MAMMOD', N'SKU-1002', N'CS', 399, 199, 28, 11172, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200024', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 118, 59, 30, 3540, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200024', N'00002', N'MAMMOD', N'SKU-1002', N'CS', 109, 54, 28, 3052, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200024', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 48, 24, 21, 1008, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200024', N'00004', N'MAMMOD', N'SKU-1005', N'CS', 137, 68, 52, 7124, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200025', N'00001', N'MAMMOD', N'SKU-1004', N'CS', 176, 176, 40, 7040, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200025', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 88, 88, 30, 2640, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200025', N'00003', N'MAMMOD', N'SKU-1005', N'CS', 105, 105, 52, 5460, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200025', N'00004', N'MAMMOD', N'SKU-1003', N'BG', 166, 166, 38, 6308, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200026', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 346, 0, 30, 10380, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200026', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 116, 0, 52, 6032, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200026', N'00003', N'MAMMOD', N'SKU-1006', N'CS', 277, 0, 37, 10249, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200027', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 246, 246, 21, 5166, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200028', N'00001', N'MAMMOD', N'SKU-1008', N'CS', 273, 0, 22, 6006, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200029', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 303, 151, 30, 9090, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200029', N'00002', N'MAMMOD', N'SKU-1004', N'CS', 267, 133, 40, 10680, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200030', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 194, 194, 38, 7372, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200030', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 89, 89, 22, 1958, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200030', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 200, 200, 21, 4200, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200030', N'00004', N'MAMMOD', N'SKU-1002', N'CS', 290, 290, 28, 8120, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200031', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 382, 382, 21, 8022, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200032', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 261, 261, 21, 5481, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200033', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 155, 77, 52, 8060, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200034', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 67, 33, 21, 1407, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200034', N'00002', N'MAMMOD', N'SKU-1002', N'CS', 36, 18, 28, 1008, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200034', N'00003', N'MAMMOD', N'SKU-1003', N'BG', 31, 15, 38, 1178, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200035', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 342, 342, 21, 7182, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200035', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 287, 287, 30, 8610, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200035', N'00003', N'MAMMOD', N'SKU-1003', N'BG', 212, 212, 38, 8056, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200035', N'00004', N'MAMMOD', N'SKU-1005', N'CS', 280, 280, 52, 14560, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200036', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 52, 26, 52, 2704, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200036', N'00002', N'MAMMOD', N'SKU-1004', N'CS', 69, 34, 40, 2760, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200037', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 259, 129, 28, 7252, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200037', N'00002', N'MAMMOD', N'SKU-1001', N'CS', 222, 111, 30, 6660, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200037', N'00003', N'MAMMOD', N'SKU-1006', N'CS', 110, 55, 37, 4070, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200037', N'00004', N'MAMMOD', N'SKU-1007', N'PK', 261, 130, 21, 5481, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200038', N'00001', N'MAMMOD', N'SKU-1003', N'BG', 225, 225, 38, 8550, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200038', N'00002', N'MAMMOD', N'SKU-1002', N'CS', 81, 81, 28, 2268, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200038', N'00003', N'MAMMOD', N'SKU-1008', N'CS', 229, 229, 22, 5038, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200039', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 194, 194, 52, 10088, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200039', N'00002', N'MAMMOD', N'SKU-1006', N'CS', 220, 220, 37, 8140, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200039', N'00003', N'MAMMOD', N'SKU-1002', N'CS', 152, 152, 28, 4256, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200039', N'00004', N'MAMMOD', N'SKU-1001', N'CS', 193, 193, 30, 5790, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200040', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 264, 264, 30, 7920, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200040', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 166, 166, 52, 8632, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200041', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 111, 55, 30, 3330, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200042', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 291, 291, 30, 8730, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200042', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 392, 392, 22, 8624, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200043', N'00001', N'MAMMOD', N'SKU-1004', N'CS', 125, 62, 40, 5000, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200043', N'00002', N'MAMMOD', N'SKU-1003', N'BG', 375, 187, 38, 14250, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200043', N'00003', N'MAMMOD', N'SKU-1007', N'PK', 291, 145, 21, 6111, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200043', N'00004', N'MAMMOD', N'SKU-1008', N'CS', 20, 10, 22, 440, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200044', N'00001', N'MAMMOD', N'SKU-1007', N'PK', 337, 337, 21, 7077, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200044', N'00002', N'MAMMOD', N'SKU-1008', N'CS', 229, 229, 22, 5038, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200044', N'00003', N'MAMMOD', N'SKU-1005', N'CS', 117, 117, 52, 6084, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200045', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 80, 40, 30, 2400, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200045', N'00002', N'MAMMOD', N'SKU-1003', N'BG', 324, 162, 38, 12312, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200045', N'00003', N'MAMMOD', N'SKU-1006', N'CS', 162, 81, 37, 5994, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'SO-99200045', N'00004', N'MAMMOD', N'SKU-1008', N'CS', 116, 58, 22, 2552, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200046', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 293, 146, 52, 15236, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200046', N'00002', N'MAMMOD', N'SKU-1004', N'CS', 210, 105, 40, 8400, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200046', N'00003', N'MAMMOD', N'SKU-1003', N'BG', 312, 156, 38, 11856, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'SO-99200047', N'00001', N'MAMMOD', N'SKU-1002', N'CS', 334, 167, 28, 9352, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200048', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 398, 199, 30, 11940, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200048', N'00002', N'MAMMOD', N'SKU-1004', N'CS', 283, 141, 40, 11320, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200048', N'00003', N'MAMMOD', N'SKU-1008', N'CS', 270, 135, 22, 5940, N'PARTIAL', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200049', N'00001', N'MAMMOD', N'SKU-1001', N'CS', 64, 64, 30, 1920, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200049', N'00002', N'MAMMOD', N'SKU-1005', N'CS', 109, 109, 52, 5668, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200049', N'00003', N'MAMMOD', N'SKU-1003', N'BG', 276, 276, 38, 10488, N'CLOSED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'SO-99200050', N'00001', N'MAMMOD', N'SKU-1005', N'CS', 330, 330, 52, 17160, N'CLOSED', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_DO_HDR';
INSERT INTO dbo.DOC_DO_HDR
    ([WHSEID], [ORDERKEY], [OWNERKEY], [EXTERNORDERKEY], [ORDERDATE], [DELIVERYDATE], [PRIORITY], [SHIPTO], [C_COMPANY], [DOOR], [BATCHFLAG], [STATUS], [TYPE], [ORDERGROUP], [ROUTE], [ZONE], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'DO-2026-9001', N'MAMMOD', N'SO-99200001', '2026-08-02T18:00:00', '2026-08-06', N'5', N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-NORTH-01', N'TH-001', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9002', N'MAMMOD', N'SO-99200002', '2026-07-31T14:00:00', '2026-08-06', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9003', N'MAMMOD', N'SO-99200003', '2026-08-03T06:00:00', '2026-08-05', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9004', N'MAMMOD', N'SO-99200004', '2026-08-02T17:00:00', '2026-08-05', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9005', N'MAMMOD', N'SO-99200005', '2026-07-29T15:00:00', '2026-08-04', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'SHIPPED', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9006', N'MAMMOD', N'SO-99200006', '2026-08-02T18:00:00', '2026-08-04', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'SHIPPED', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9007', N'MAMMOD', N'SO-99200007', '2026-08-01T07:00:00', '2026-08-03', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'SHIPPED', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9008', N'MAMMOD', N'SO-99200008', '2026-08-01T11:00:00', '2026-08-03', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'SHIPPED', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9009', N'MAMMOD', N'SO-99200009', '2026-07-29T13:00:00', '2026-08-02', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9010', N'MAMMOD', N'SO-99200010', '2026-07-30T07:00:00', '2026-08-02', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'PICKED', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9011', N'MAMMOD', N'SO-99200011', '2026-07-21T09:00:00', '2026-08-05', N'5', N'CUS-0001', N'บจก. นครสวรรค์การค้า', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-001', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9012', N'MAMMOD', N'SO-99200012', '2026-07-30T06:00:00', '2026-08-10', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9013', N'MAMMOD', N'SO-99200013', '2026-07-29T08:00:00', '2026-08-08', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9014', N'MAMMOD', N'SO-99200013', '2026-07-29T08:00:00', '2026-08-08', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9015', N'MAMMOD', N'SO-99200014', '2026-07-31T13:00:00', '2026-08-09', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9016', N'MAMMOD', N'SO-99200017', '2026-07-30T18:00:00', '2026-08-05', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9017', N'MAMMOD', N'SO-99200018', '2026-08-04T07:00:00', '2026-08-07', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9018', N'MAMMOD', N'SO-99200019', '2026-07-23T08:00:00', '2026-08-03', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9019', N'MAMMOD', N'SO-99200019', '2026-07-23T08:00:00', '2026-08-03', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9020', N'MAMMOD', N'SO-99200020', '2026-07-17T16:00:00', '2026-08-07', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9021', N'MAMMOD', N'SO-99200021', '2026-07-29T16:00:00', '2026-07-28', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9022', N'MAMMOD', N'SO-99200022', '2026-07-25T16:00:00', '2026-08-10', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9023', N'MAMMOD', N'SO-99200023', '2026-08-02T10:00:00', '2026-08-04', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9024', N'MAMMOD', N'SO-99200024', '2026-08-04T08:00:00', '2026-08-10', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9025', N'MAMMOD', N'SO-99200025', '2026-07-24T14:00:00', '2026-08-07', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9026', N'MAMMOD', N'SO-99200025', '2026-07-24T14:00:00', '2026-08-07', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9027', N'MAMMOD', N'SO-99200027', '2026-08-03T08:00:00', '2026-08-08', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9028', N'MAMMOD', N'SO-99200029', '2026-07-25T11:00:00', '2026-07-31', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9029', N'MAMMOD', N'SO-99200030', '2026-07-27T16:00:00', '2026-08-11', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9030', N'MAMMOD', N'SO-99200031', '2026-07-20T17:00:00', '2026-08-10', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9031', N'MAMMOD', N'SO-99200031', '2026-07-20T17:00:00', '2026-08-10', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9032', N'MAMMOD', N'SO-99200032', '2026-07-30T14:00:00', '2026-08-10', N'5', N'CUS-0007', N'ชลบุรี ซูเปอร์มาร์เก็ต', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-007', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9033', N'MAMMOD', N'SO-99200033', '2026-08-01T15:00:00', '2026-08-05', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9034', N'MAMMOD', N'SO-99200034', '2026-07-16T16:00:00', '2026-08-11', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9035', N'MAMMOD', N'SO-99200035', '2026-07-25T18:00:00', '2026-07-31', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9036', N'MAMMOD', N'SO-99200036', '2026-07-26T09:00:00', '2026-08-02', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9037', N'MAMMOD', N'SO-99200037', '2026-08-04T13:00:00', '2026-08-09', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9038', N'MAMMOD', N'SO-99200038', '2026-07-16T17:00:00', '2026-08-02', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9039', N'MAMMOD', N'SO-99200038', '2026-07-16T17:00:00', '2026-08-02', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9040', N'MAMMOD', N'SO-99200039', '2026-07-16T07:00:00', '2026-07-31', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9041', N'MAMMOD', N'SO-99200040', '2026-07-28T17:00:00', '2026-08-10', N'5', N'CUS-0004', N'บจก. อยุธยาเทรดดิ้ง', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-004', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9042', N'MAMMOD', N'SO-99200041', '2026-07-19T09:00:00', '2026-08-07', N'5', N'CUS-0003', N'ร้านพิษณุโลกมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-003', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9043', N'MAMMOD', N'SO-99200042', '2026-07-31T10:00:00', '2026-08-12', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9044', N'MAMMOD', N'SO-99200042', '2026-07-31T10:00:00', '2026-08-12', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9045', N'MAMMOD', N'SO-99200043', '2026-07-19T06:00:00', '2026-08-09', N'5', N'CUS-0009', N'นครปฐมค้าส่ง', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-009', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9046', N'MAMMOD', N'SO-99200044', '2026-07-30T06:00:00', '2026-08-07', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'DO-2026-9047', N'MAMMOD', N'SO-99200045', '2026-08-01T15:00:00', '2026-08-04', N'5', N'CUS-0006', N'บจก. สระบุรีวัสดุ', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-006', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9048', N'MAMMOD', N'SO-99200046', '2026-07-30T06:00:00', '2026-08-10', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'DO-2026-9049', N'MAMMOD', N'SO-99200047', '2026-07-30T18:00:00', '2026-07-28', N'5', N'CUS-0002', N'หจก. พิจิตรซัพพลาย', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-NORTH-01', N'TH-002', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9050', N'MAMMOD', N'SO-99200048', '2026-07-24T12:00:00', '2026-08-07', N'5', N'CUS-0010', N'ราชบุรีมาร์ท', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-WEST-02', N'TH-010', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9051', N'MAMMOD', N'SO-99200049', '2026-07-20T08:00:00', '2026-07-28', N'5', N'CUS-0005', N'สหกรณ์ลพบุรี', N'D01', N'N', N'NEW', N'SO', N'GEN', NULL, N'TH-005', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'DO-2026-9052', N'MAMMOD', N'SO-99200050', '2026-07-30T11:00:00', '2026-08-11', N'5', N'CUS-0008', N'ระยองฟู้ดส์', N'D01', N'N', N'NEW', N'SO', N'GEN', N'RT-EAST-01', N'TH-008', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_DO_DETAIL';
INSERT INTO dbo.DOC_DO_DETAIL
    ([MANUFACTURERSKU], [RETAILSKU], [ALTSKU], [SHIPPEDQTY], [ADJUSTEDQTY], [QTYPREALLOCATED], [QTYALLOCATED], [QTYPICKED], [PACKKEY], [CARTONGROUP], [LOT], [ID], [FACILITY], [TAX01], [TAX02], [UPDATESOURCE], [LOTTABLE01], [LOTTABLE02], [LOTTABLE03], [LOTTABLE06], [LOTTABLE07], [LOTTABLE08], [LOTTABLE09], [LOTTABLE10], [WHSEID], [ORDERKEY], [ORDERLINENUMBER], [EXTERNORDERKEY], [EXTERNLINENO], [SKU], [OWNERKEY], [ORIGINALQTY], [OPENQTY], [UOM], [STATUS], [UNITPRICE], [EXTENDEDPRICE], [PRODUCT_WEIGHT], [PRODUCT_CUBE], [ADDDATE], [ADDWHO])
VALUES
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9001', N'00001', N'SO-99200001', N'00001', N'SKU-1006', N'MAMMOD', 279, 0, N'CS', N'PICKED', 37, 10323, 3013.2, 5.022, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9002', N'00001', N'SO-99200002', N'00001', N'SKU-1007', N'MAMMOD', 376, 0, N'PK', N'PICKED', 21, 7896, 714.4, 16.92, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9003', N'00001', N'SO-99200003', N'00001', N'SKU-1003', N'MAMMOD', 152, 0, N'BG', N'PICKED', 38, 5776, 760.0, 1.064, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9004', N'00001', N'SO-99200004', N'00001', N'SKU-1001', N'MAMMOD', 109, 0, N'CS', N'PICKED', 30, 3270, 784.8, 1.308, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9004', N'00002', N'SO-99200004', N'00002', N'SKU-1002', N'MAMMOD', 346, 0, N'CS', N'PICKED', 28, 9688, 2975.6, 5.19, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 331, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9005', N'00001', N'SO-99200005', N'00001', N'SKU-1008', N'MAMMOD', 331, 0, N'CS', N'SHIPPED', 22, 7282, 2515.6, 4.303, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 283, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9005', N'00002', N'SO-99200005', N'00002', N'SKU-1004', N'MAMMOD', 283, 0, N'CS', N'SHIPPED', 40, 11320, 3226.2, 3.962, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 55, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9006', N'00001', N'SO-99200006', N'00001', N'SKU-1005', N'MAMMOD', 55, 0, N'CS', N'SHIPPED', 52, 2860, 132.0, 1.155, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 201, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9006', N'00002', N'SO-99200006', N'00002', N'SKU-1008', N'MAMMOD', 201, 0, N'CS', N'SHIPPED', 22, 4422, 1527.6, 2.613, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 240, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9006', N'00003', N'SO-99200006', N'00003', N'SKU-1002', N'MAMMOD', 240, 0, N'CS', N'SHIPPED', 28, 6720, 2064.0, 3.6, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 78, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00001', N'SO-99200007', N'00001', N'SKU-1001', N'MAMMOD', 78, 0, N'CS', N'SHIPPED', 30, 2340, 561.6, 0.936, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 306, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00002', N'SO-99200007', N'00002', N'SKU-1008', N'MAMMOD', 306, 0, N'CS', N'SHIPPED', 22, 6732, 2325.6, 3.978, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 69, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9007', N'00003', N'SO-99200007', N'00003', N'SKU-1007', N'MAMMOD', 69, 0, N'PK', N'SHIPPED', 21, 1449, 131.1, 3.105, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 244, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9008', N'00001', N'SO-99200008', N'00001', N'SKU-1007', N'MAMMOD', 244, 0, N'PK', N'SHIPPED', 21, 5124, 463.6, 10.98, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9009', N'00001', N'SO-99200009', N'00001', N'SKU-1005', N'MAMMOD', 323, 0, N'CS', N'PICKED', 52, 16796, 775.2, 6.783, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9009', N'00002', N'SO-99200009', N'00002', N'SKU-1001', N'MAMMOD', 334, 0, N'CS', N'PICKED', 30, 10020, 2404.8, 4.008, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9009', N'00003', N'SO-99200009', N'00003', N'SKU-1007', N'MAMMOD', 332, 0, N'PK', N'PICKED', 21, 6972, 630.8, 14.94, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9010', N'00001', N'SO-99200010', N'00001', N'SKU-1002', N'MAMMOD', 374, 0, N'CS', N'PICKED', 28, 10472, 3216.4, 5.61, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9011', N'00001', N'SO-99200011', N'00001', N'SKU-1002', N'MAMMOD', 180, 180, N'CS', N'NEW', 28, 5040, 1548.0, 2.7, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9011', N'00002', N'SO-99200011', N'00002', N'SKU-1003', N'MAMMOD', 31, 31, N'BG', N'NEW', 38, 1178, 155.0, 0.217, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9011', N'00003', N'SO-99200011', N'00003', N'SKU-1008', N'MAMMOD', 351, 351, N'CS', N'NEW', 22, 7722, 2667.6, 4.563, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9011', N'00004', N'SO-99200011', N'00004', N'SKU-1004', N'MAMMOD', 162, 162, N'CS', N'NEW', 40, 6480, 1846.8, 2.268, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9012', N'00001', N'SO-99200012', N'00001', N'SKU-1004', N'MAMMOD', 136, 136, N'CS', N'NEW', 40, 5440, 1550.4, 1.904, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9012', N'00002', N'SO-99200012', N'00002', N'SKU-1007', N'MAMMOD', 200, 200, N'PK', N'NEW', 21, 4200, 380.0, 9.0, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9012', N'00003', N'SO-99200012', N'00003', N'SKU-1001', N'MAMMOD', 127, 127, N'CS', N'NEW', 30, 3810, 914.4, 1.524, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9012', N'00004', N'SO-99200012', N'00004', N'SKU-1008', N'MAMMOD', 170, 170, N'CS', N'NEW', 22, 3740, 1292.0, 2.21, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9013', N'00001', N'SO-99200013', N'00001', N'SKU-1007', N'MAMMOD', 185, 185, N'PK', N'NEW', 21, 3885, 351.5, 8.325, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9014', N'00001', N'SO-99200013', N'00001', N'SKU-1007', N'MAMMOD', 186, 186, N'PK', N'NEW', 21, 3906, 353.4, 8.37, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9015', N'00001', N'SO-99200014', N'00001', N'SKU-1002', N'MAMMOD', 75, 75, N'CS', N'NEW', 28, 2100, 645.0, 1.125, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9015', N'00002', N'SO-99200014', N'00002', N'SKU-1005', N'MAMMOD', 34, 34, N'CS', N'NEW', 52, 1768, 81.6, 0.714, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9015', N'00003', N'SO-99200014', N'00003', N'SKU-1008', N'MAMMOD', 79, 79, N'CS', N'NEW', 22, 1738, 600.4, 1.027, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9015', N'00004', N'SO-99200014', N'00004', N'SKU-1001', N'MAMMOD', 115, 115, N'CS', N'NEW', 30, 3450, 828.0, 1.38, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9016', N'00001', N'SO-99200017', N'00001', N'SKU-1005', N'MAMMOD', 63, 63, N'CS', N'NEW', 52, 3276, 151.2, 1.323, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9016', N'00002', N'SO-99200017', N'00002', N'SKU-1008', N'MAMMOD', 58, 58, N'CS', N'NEW', 22, 1276, 440.8, 0.754, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9016', N'00003', N'SO-99200017', N'00003', N'SKU-1002', N'MAMMOD', 99, 99, N'CS', N'NEW', 28, 2772, 851.4, 1.485, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9017', N'00001', N'SO-99200018', N'00001', N'SKU-1006', N'MAMMOD', 323, 323, N'CS', N'NEW', 37, 11951, 3488.4, 5.814, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9017', N'00002', N'SO-99200018', N'00002', N'SKU-1001', N'MAMMOD', 334, 334, N'CS', N'NEW', 30, 10020, 2404.8, 4.008, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9018', N'00001', N'SO-99200019', N'00001', N'SKU-1001', N'MAMMOD', 125, 125, N'CS', N'NEW', 30, 3750, 900.0, 1.5, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9018', N'00002', N'SO-99200019', N'00002', N'SKU-1005', N'MAMMOD', 11, 11, N'CS', N'NEW', 52, 572, 26.4, 0.231, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9019', N'00001', N'SO-99200019', N'00001', N'SKU-1001', N'MAMMOD', 125, 125, N'CS', N'NEW', 30, 3750, 900.0, 1.5, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9019', N'00002', N'SO-99200019', N'00002', N'SKU-1005', N'MAMMOD', 12, 12, N'CS', N'NEW', 52, 624, 28.8, 0.252, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9020', N'00001', N'SO-99200020', N'00001', N'SKU-1002', N'MAMMOD', 298, 298, N'CS', N'NEW', 28, 8344, 2562.8, 4.47, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9020', N'00002', N'SO-99200020', N'00002', N'SKU-1003', N'MAMMOD', 96, 96, N'BG', N'NEW', 38, 3648, 480.0, 0.672, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9020', N'00003', N'SO-99200020', N'00003', N'SKU-1001', N'MAMMOD', 107, 107, N'CS', N'NEW', 30, 3210, 770.4, 1.284, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9021', N'00001', N'SO-99200021', N'00001', N'SKU-1005', N'MAMMOD', 190, 190, N'CS', N'NEW', 52, 9880, 456.0, 3.99, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9022', N'00001', N'SO-99200022', N'00001', N'SKU-1008', N'MAMMOD', 60, 60, N'CS', N'NEW', 22, 1320, 456.0, 0.78, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9023', N'00001', N'SO-99200023', N'00001', N'SKU-1003', N'MAMMOD', 55, 55, N'BG', N'NEW', 38, 2090, 275.0, 0.385, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9023', N'00002', N'SO-99200023', N'00002', N'SKU-1006', N'MAMMOD', 144, 144, N'CS', N'NEW', 37, 5328, 1555.2, 2.592, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9023', N'00003', N'SO-99200023', N'00003', N'SKU-1008', N'MAMMOD', 115, 115, N'CS', N'NEW', 22, 2530, 874.0, 1.495, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9023', N'00004', N'SO-99200023', N'00004', N'SKU-1002', N'MAMMOD', 199, 199, N'CS', N'NEW', 28, 5572, 1711.4, 2.985, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00001', N'SO-99200024', N'00001', N'SKU-1001', N'MAMMOD', 59, 59, N'CS', N'NEW', 30, 1770, 424.8, 0.708, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00002', N'SO-99200024', N'00002', N'SKU-1002', N'MAMMOD', 54, 54, N'CS', N'NEW', 28, 1512, 464.4, 0.81, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00003', N'SO-99200024', N'00003', N'SKU-1007', N'MAMMOD', 24, 24, N'PK', N'NEW', 21, 504, 45.6, 1.08, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9024', N'00004', N'SO-99200024', N'00004', N'SKU-1005', N'MAMMOD', 68, 68, N'CS', N'NEW', 52, 3536, 163.2, 1.428, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9025', N'00001', N'SO-99200025', N'00001', N'SKU-1004', N'MAMMOD', 88, 88, N'CS', N'NEW', 40, 3520, 1003.2, 1.232, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9025', N'00002', N'SO-99200025', N'00002', N'SKU-1001', N'MAMMOD', 44, 44, N'CS', N'NEW', 30, 1320, 316.8, 0.528, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9025', N'00003', N'SO-99200025', N'00003', N'SKU-1005', N'MAMMOD', 52, 52, N'CS', N'NEW', 52, 2704, 124.8, 1.092, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9025', N'00004', N'SO-99200025', N'00004', N'SKU-1003', N'MAMMOD', 83, 83, N'BG', N'NEW', 38, 3154, 415.0, 0.581, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00001', N'SO-99200025', N'00001', N'SKU-1004', N'MAMMOD', 88, 88, N'CS', N'NEW', 40, 3520, 1003.2, 1.232, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00002', N'SO-99200025', N'00002', N'SKU-1001', N'MAMMOD', 44, 44, N'CS', N'NEW', 30, 1320, 316.8, 0.528, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00003', N'SO-99200025', N'00003', N'SKU-1005', N'MAMMOD', 53, 53, N'CS', N'NEW', 52, 2756, 127.2, 1.113, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9026', N'00004', N'SO-99200025', N'00004', N'SKU-1003', N'MAMMOD', 83, 83, N'BG', N'NEW', 38, 3154, 415.0, 0.581, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9027', N'00001', N'SO-99200027', N'00001', N'SKU-1007', N'MAMMOD', 246, 246, N'PK', N'NEW', 21, 5166, 467.4, 11.07, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9028', N'00001', N'SO-99200029', N'00001', N'SKU-1001', N'MAMMOD', 151, 151, N'CS', N'NEW', 30, 4530, 1087.2, 1.812, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9028', N'00002', N'SO-99200029', N'00002', N'SKU-1004', N'MAMMOD', 133, 133, N'CS', N'NEW', 40, 5320, 1516.2, 1.862, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9029', N'00001', N'SO-99200030', N'00001', N'SKU-1003', N'MAMMOD', 194, 194, N'BG', N'NEW', 38, 7372, 970.0, 1.358, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9029', N'00002', N'SO-99200030', N'00002', N'SKU-1008', N'MAMMOD', 89, 89, N'CS', N'NEW', 22, 1958, 676.4, 1.157, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9029', N'00003', N'SO-99200030', N'00003', N'SKU-1007', N'MAMMOD', 200, 200, N'PK', N'NEW', 21, 4200, 380.0, 9.0, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9029', N'00004', N'SO-99200030', N'00004', N'SKU-1002', N'MAMMOD', 290, 290, N'CS', N'NEW', 28, 8120, 2494.0, 4.35, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9030', N'00001', N'SO-99200031', N'00001', N'SKU-1007', N'MAMMOD', 191, 191, N'PK', N'NEW', 21, 4011, 362.9, 8.595, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9031', N'00001', N'SO-99200031', N'00001', N'SKU-1007', N'MAMMOD', 191, 191, N'PK', N'NEW', 21, 4011, 362.9, 8.595, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9032', N'00001', N'SO-99200032', N'00001', N'SKU-1007', N'MAMMOD', 261, 261, N'PK', N'NEW', 21, 5481, 495.9, 11.745, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9033', N'00001', N'SO-99200033', N'00001', N'SKU-1005', N'MAMMOD', 77, 77, N'CS', N'NEW', 52, 4004, 184.8, 1.617, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9034', N'00001', N'SO-99200034', N'00001', N'SKU-1007', N'MAMMOD', 33, 33, N'PK', N'NEW', 21, 693, 62.7, 1.485, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9034', N'00002', N'SO-99200034', N'00002', N'SKU-1002', N'MAMMOD', 18, 18, N'CS', N'NEW', 28, 504, 154.8, 0.27, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9034', N'00003', N'SO-99200034', N'00003', N'SKU-1003', N'MAMMOD', 15, 15, N'BG', N'NEW', 38, 570, 75.0, 0.105, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9035', N'00001', N'SO-99200035', N'00001', N'SKU-1007', N'MAMMOD', 342, 342, N'PK', N'NEW', 21, 7182, 649.8, 15.39, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9035', N'00002', N'SO-99200035', N'00002', N'SKU-1001', N'MAMMOD', 287, 287, N'CS', N'NEW', 30, 8610, 2066.4, 3.444, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9035', N'00003', N'SO-99200035', N'00003', N'SKU-1003', N'MAMMOD', 212, 212, N'BG', N'NEW', 38, 8056, 1060.0, 1.484, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9035', N'00004', N'SO-99200035', N'00004', N'SKU-1005', N'MAMMOD', 280, 280, N'CS', N'NEW', 52, 14560, 672.0, 5.88, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9036', N'00001', N'SO-99200036', N'00001', N'SKU-1005', N'MAMMOD', 26, 26, N'CS', N'NEW', 52, 1352, 62.4, 0.546, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9036', N'00002', N'SO-99200036', N'00002', N'SKU-1004', N'MAMMOD', 34, 34, N'CS', N'NEW', 40, 1360, 387.6, 0.476, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9037', N'00001', N'SO-99200037', N'00001', N'SKU-1002', N'MAMMOD', 129, 129, N'CS', N'NEW', 28, 3612, 1109.4, 1.935, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9037', N'00002', N'SO-99200037', N'00002', N'SKU-1001', N'MAMMOD', 111, 111, N'CS', N'NEW', 30, 3330, 799.2, 1.332, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9037', N'00003', N'SO-99200037', N'00003', N'SKU-1006', N'MAMMOD', 55, 55, N'CS', N'NEW', 37, 2035, 594.0, 0.99, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9037', N'00004', N'SO-99200037', N'00004', N'SKU-1007', N'MAMMOD', 130, 130, N'PK', N'NEW', 21, 2730, 247.0, 5.85, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9038', N'00001', N'SO-99200038', N'00001', N'SKU-1003', N'MAMMOD', 112, 112, N'BG', N'NEW', 38, 4256, 560.0, 0.784, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9038', N'00002', N'SO-99200038', N'00002', N'SKU-1002', N'MAMMOD', 40, 40, N'CS', N'NEW', 28, 1120, 344.0, 0.6, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9038', N'00003', N'SO-99200038', N'00003', N'SKU-1008', N'MAMMOD', 114, 114, N'CS', N'NEW', 22, 2508, 866.4, 1.482, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00001', N'SO-99200038', N'00001', N'SKU-1003', N'MAMMOD', 113, 113, N'BG', N'NEW', 38, 4294, 565.0, 0.791, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00002', N'SO-99200038', N'00002', N'SKU-1002', N'MAMMOD', 41, 41, N'CS', N'NEW', 28, 1148, 352.6, 0.615, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9039', N'00003', N'SO-99200038', N'00003', N'SKU-1008', N'MAMMOD', 115, 115, N'CS', N'NEW', 22, 2530, 874.0, 1.495, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9040', N'00001', N'SO-99200039', N'00001', N'SKU-1005', N'MAMMOD', 194, 194, N'CS', N'NEW', 52, 10088, 465.6, 4.074, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9040', N'00002', N'SO-99200039', N'00002', N'SKU-1006', N'MAMMOD', 220, 220, N'CS', N'NEW', 37, 8140, 2376.0, 3.96, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9040', N'00003', N'SO-99200039', N'00003', N'SKU-1002', N'MAMMOD', 152, 152, N'CS', N'NEW', 28, 4256, 1307.2, 2.28, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9040', N'00004', N'SO-99200039', N'00004', N'SKU-1001', N'MAMMOD', 193, 193, N'CS', N'NEW', 30, 5790, 1389.6, 2.316, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9041', N'00001', N'SO-99200040', N'00001', N'SKU-1001', N'MAMMOD', 264, 264, N'CS', N'NEW', 30, 7920, 1900.8, 3.168, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9041', N'00002', N'SO-99200040', N'00002', N'SKU-1005', N'MAMMOD', 166, 166, N'CS', N'NEW', 52, 8632, 398.4, 3.486, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9042', N'00001', N'SO-99200041', N'00001', N'SKU-1001', N'MAMMOD', 55, 55, N'CS', N'NEW', 30, 1650, 396.0, 0.66, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9043', N'00001', N'SO-99200042', N'00001', N'SKU-1001', N'MAMMOD', 145, 145, N'CS', N'NEW', 30, 4350, 1044.0, 1.74, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9043', N'00002', N'SO-99200042', N'00002', N'SKU-1008', N'MAMMOD', 196, 196, N'CS', N'NEW', 22, 4312, 1489.6, 2.548, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9044', N'00001', N'SO-99200042', N'00001', N'SKU-1001', N'MAMMOD', 146, 146, N'CS', N'NEW', 30, 4380, 1051.2, 1.752, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9044', N'00002', N'SO-99200042', N'00002', N'SKU-1008', N'MAMMOD', 196, 196, N'CS', N'NEW', 22, 4312, 1489.6, 2.548, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9045', N'00001', N'SO-99200043', N'00001', N'SKU-1004', N'MAMMOD', 62, 62, N'CS', N'NEW', 40, 2480, 706.8, 0.868, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9045', N'00002', N'SO-99200043', N'00002', N'SKU-1003', N'MAMMOD', 187, 187, N'BG', N'NEW', 38, 7106, 935.0, 1.309, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9045', N'00003', N'SO-99200043', N'00003', N'SKU-1007', N'MAMMOD', 145, 145, N'PK', N'NEW', 21, 3045, 275.5, 6.525, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9045', N'00004', N'SO-99200043', N'00004', N'SKU-1008', N'MAMMOD', 10, 10, N'CS', N'NEW', 22, 220, 76.0, 0.13, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9046', N'00001', N'SO-99200044', N'00001', N'SKU-1007', N'MAMMOD', 337, 337, N'PK', N'NEW', 21, 7077, 640.3, 15.165, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9046', N'00002', N'SO-99200044', N'00002', N'SKU-1008', N'MAMMOD', 229, 229, N'CS', N'NEW', 22, 5038, 1740.4, 2.977, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9046', N'00003', N'SO-99200044', N'00003', N'SKU-1005', N'MAMMOD', 117, 117, N'CS', N'NEW', 52, 6084, 280.8, 2.457, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9047', N'00001', N'SO-99200045', N'00001', N'SKU-1001', N'MAMMOD', 40, 40, N'CS', N'NEW', 30, 1200, 288.0, 0.48, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9047', N'00002', N'SO-99200045', N'00002', N'SKU-1003', N'MAMMOD', 162, 162, N'BG', N'NEW', 38, 6156, 810.0, 1.134, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9047', N'00003', N'SO-99200045', N'00003', N'SKU-1006', N'MAMMOD', 81, 81, N'CS', N'NEW', 37, 2997, 874.8, 1.458, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WSK', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WSK', N'DO-2026-9047', N'00004', N'SO-99200045', N'00004', N'SKU-1008', N'MAMMOD', 58, 58, N'CS', N'NEW', 22, 1276, 440.8, 0.754, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9048', N'00001', N'SO-99200046', N'00001', N'SKU-1005', N'MAMMOD', 146, 146, N'CS', N'NEW', 52, 7592, 350.4, 3.066, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9048', N'00002', N'SO-99200046', N'00002', N'SKU-1004', N'MAMMOD', 105, 105, N'CS', N'NEW', 40, 4200, 1197.0, 1.47, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9048', N'00003', N'SO-99200046', N'00003', N'SKU-1003', N'MAMMOD', 156, 156, N'BG', N'NEW', 38, 5928, 780.0, 1.092, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WPD', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WPD', N'DO-2026-9049', N'00001', N'SO-99200047', N'00001', N'SKU-1002', N'MAMMOD', 167, 167, N'CS', N'NEW', 28, 4676, 1436.2, 2.505, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9050', N'00001', N'SO-99200048', N'00001', N'SKU-1001', N'MAMMOD', 199, 199, N'CS', N'NEW', 30, 5970, 1432.8, 2.388, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9050', N'00002', N'SO-99200048', N'00002', N'SKU-1004', N'MAMMOD', 141, 141, N'CS', N'NEW', 40, 5640, 1607.4, 1.974, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9050', N'00003', N'SO-99200048', N'00003', N'SKU-1008', N'MAMMOD', 135, 135, N'CS', N'NEW', 22, 2970, 1026.0, 1.755, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9051', N'00001', N'SO-99200049', N'00001', N'SKU-1001', N'MAMMOD', 64, 64, N'CS', N'NEW', 30, 1920, 460.8, 0.768, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9051', N'00002', N'SO-99200049', N'00002', N'SKU-1005', N'MAMMOD', 109, 109, N'CS', N'NEW', 52, 5668, 261.6, 2.289, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9051', N'00003', N'SO-99200049', N'00003', N'SKU-1003', N'MAMMOD', 276, 276, N'BG', N'NEW', 38, 10488, 1380.0, 1.932, '2026-08-05T09:00:00', N'seed'),
    (N'', N'', N'', 0, 0, 0, 0, 0, N'STD', N'STD', N'', N'', N'WWP', 0, 0, N'SEED', N'', N'', N'', N'', N'', N'', N'', N'', N'WWP', N'DO-2026-9052', N'00001', N'SO-99200050', N'00001', N'SKU-1005', N'MAMMOD', 330, 330, N'CS', N'NEW', 52, 17160, 792.0, 6.93, '2026-08-05T09:00:00', N'seed');
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
    (N'WSK', N'MN-202608-0043', 1, 1, N'DO-2026-9001', N'SO-99200001', N'MAMMOD', N'RT-NORTH-01', N'TH-001', '2026-08-06', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 2, N'DO-2026-9002', N'SO-99200002', N'MAMMOD', N'RT-NORTH-01', N'TH-003', '2026-08-06', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 1, N'DO-2026-9003', N'SO-99200003', N'MAMMOD', N'RT-WEST-02', N'TH-009', '2026-08-05', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 2, N'DO-2026-9004', N'SO-99200004', N'MAMMOD', N'RT-WEST-02', N'TH-010', '2026-08-05', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 1, N'DO-2026-9005', N'SO-99200005', N'MAMMOD', N'RT-EAST-01', N'TH-007', '2026-08-04', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 2, N'DO-2026-9006', N'SO-99200006', N'MAMMOD', N'RT-EAST-01', N'TH-008', '2026-08-04', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 1, N'DO-2026-9007', N'SO-99200007', N'MAMMOD', N'RT-WEST-02', N'TH-009', '2026-08-03', N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 2, N'DO-2026-9008', N'SO-99200008', N'MAMMOD', N'RT-WEST-02', N'TH-010', '2026-08-03', N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 1, N'DO-2026-9009', N'SO-99200009', N'MAMMOD', N'RT-EAST-01', N'TH-007', '2026-08-02', N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 2, N'DO-2026-9010', N'SO-99200010', N'MAMMOD', N'RT-EAST-01', N'TH-008', '2026-08-02', N'NEW', '2026-08-05T09:00:00', N'seed');
GO

PRINT '  DOC_SHIPMENT_DETAIL_LINE';
INSERT INTO dbo.DOC_SHIPMENT_DETAIL_LINE
    ([WHSEID], [SHIPMENTKEY], [SHIPMENTDETAILID], [SHIPMENTLINENO], [ORDERKEY], [ORDERLINENO], [SKU], [UOM], [ORDERQTY], [SHIPMENTQTY], [PICKEDQTY], [LOADEDQTY], [DELIVEREDQTY], [STATUS], [ADDDATE], [ADDWHO])
VALUES
    (N'WSK', N'MN-202608-0043', 1, 1, N'DO-2026-9001', N'00001', N'SKU-1006', N'CS', 279, 279, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0043', 2, 1, N'DO-2026-9002', N'00001', N'SKU-1007', N'PK', 376, 376, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 1, 1, N'DO-2026-9003', N'00001', N'SKU-1003', N'BG', 152, 152, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 1, N'DO-2026-9004', N'00001', N'SKU-1001', N'CS', 109, 109, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0042', 2, 2, N'DO-2026-9004', N'00002', N'SKU-1002', N'CS', 346, 346, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 1, N'DO-2026-9005', N'00001', N'SKU-1008', N'CS', 331, 331, 331, 331, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 1, 2, N'DO-2026-9005', N'00002', N'SKU-1004', N'CS', 283, 283, 283, 283, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 1, N'DO-2026-9006', N'00001', N'SKU-1005', N'CS', 55, 55, 55, 55, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 2, N'DO-2026-9006', N'00002', N'SKU-1008', N'CS', 201, 201, 201, 201, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WSK', N'MN-202608-0041', 2, 3, N'DO-2026-9006', N'00003', N'SKU-1002', N'CS', 240, 240, 240, 240, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 1, N'DO-2026-9007', N'00001', N'SKU-1001', N'CS', 78, 78, 78, 78, 78, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 2, N'DO-2026-9007', N'00002', N'SKU-1008', N'CS', 306, 306, 306, 306, 306, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 1, 3, N'DO-2026-9007', N'00003', N'SKU-1007', N'PK', 69, 69, 69, 69, 69, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WPD', N'MN-202608-0040', 2, 1, N'DO-2026-9008', N'00001', N'SKU-1007', N'PK', 244, 244, 244, 244, 244, N'DELIVERED', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 1, N'DO-2026-9009', N'00001', N'SKU-1005', N'CS', 323, 323, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 2, N'DO-2026-9009', N'00002', N'SKU-1001', N'CS', 334, 334, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 1, 3, N'DO-2026-9009', N'00003', N'SKU-1007', N'PK', 332, 332, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed'),
    (N'WWP', N'MN-202608-0039', 2, 1, N'DO-2026-9010', N'00001', N'SKU-1002', N'CS', 374, 374, 0, 0, 0, N'NEW', '2026-08-05T09:00:00', N'seed');
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
