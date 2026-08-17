#!/usr/bin/env python3
"""Generate development data straight into the SQL Server database.

The sibling script ``generate_data.py`` POSTs rows at a running API, so its rows
live only as long as the process does. This one writes into ``MMDEV``, the local
database built by ``docs/data-model/build-local-db.ps1``, so the rows survive a
restart and can be inspected in VS Code alongside the API.

It emits a ``.sql`` file rather than talking to the server itself. Neither
``pyodbc`` nor ``pymssql`` ships with Python, and asking a training project to
install a native ODBC driver to see demo rows is a poor trade -- ``sqlcmd`` is
already required to build the database at all. The generated file is also worth
having on its own: it can be read before it is run, checked into a branch, or
handed to somebody with database access but no Python.

Examples:

    python tests/generate_sql_data.py                     # write the .sql, show a summary
    python tests/generate_sql_data.py --apply             # write it and run it
    python tests/generate_sql_data.py --orders 200 --apply
    python tests/generate_sql_data.py --server ".\\SQLEXPRESS" --apply

The baseline rows mirror ``Data/Seed.cs`` -- same warehouse codes, zones, routes,
carriers, vehicles, drivers and the five manifests parked at each lifecycle step
-- so a screen shows the same thing whether it reads the in-memory store or the
database. ``--orders`` adds generated delivery orders on top of that baseline for
anything that needs volume rather than a known fixture.

Re-running is safe. The script deletes the rows it owns, in reverse foreign-key
order, before inserting; it never touches a table it does not write to.
"""

from __future__ import annotations

import argparse
import random
import subprocess
import sys
from datetime import date, datetime, timedelta
from pathlib import Path
from typing import Any, Iterable, Sequence

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT = REPO_ROOT / "docs" / "data-model" / "03-seed-demo-data.sql"

WHSE = "WSK"          # the warehouse the master rows hang off
OWNER = "MAMMOD"      # OWNERKEY on WMS tables (nvarchar(15))
OWNER20 = "MAMMOD"    # same value where the column is nvarchar(20) -- see README 2.10

# The fixtures are dated so "overdue" and "due soon" are both visible on screen.
TODAY = date(2026, 8, 5)


# ─────────────────────────────────────────────────────────────────────────────
# SQL literals
#
# Everything here is generated from values in this file, not from user input.
# The quoting below is still exact rather than approximate: a Thai name with an
# apostrophe would otherwise produce a file that fails halfway through, and
# debugging that is worse than writing eight lines of escaping.
# ─────────────────────────────────────────────────────────────────────────────

def lit(value: Any) -> str:
    if value is None:
        return "NULL"
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)):
        return repr(value)
    if isinstance(value, datetime):
        return f"'{value:%Y-%m-%dT%H:%M:%S}'"
    if isinstance(value, date):
        return f"'{value:%Y-%m-%d}'"
    return "N'" + str(value).replace("'", "''") + "'"


def insert(table: str, columns: Sequence[str], rows: Iterable[Sequence[Any]]) -> str:
    rows = list(rows)
    if not rows:
        return f"-- {table}: ไม่มีแถว\n"

    out = [f"PRINT '  {table}';", f"INSERT INTO dbo.{table}"]
    out.append("    (" + ", ".join(f"[{c}]" for c in columns) + ")")
    out.append("VALUES")

    # 1000 is the hard limit on rows per VALUES clause in SQL Server.
    chunks = [rows[i:i + 900] for i in range(0, len(rows), 900)]
    body = []
    for chunk_index, chunk in enumerate(chunks):
        if chunk_index:
            body.append("INSERT INTO dbo.{} ({}) VALUES".format(
                table, ", ".join(f"[{c}]" for c in columns)))
        body.append(",\n".join(
            "    (" + ", ".join(lit(v) for v in row) + ")" for row in chunk) + ";")
    out.extend(body)
    return "\n".join(out) + "\nGO\n"


# ─────────────────────────────────────────────────────────────────────────────
# Master data -- mirrors Data/Seed.cs
# ─────────────────────────────────────────────────────────────────────────────

WAREHOUSES = [
    # code, name, province, district, subdistrict, zip, lat, lng
    ("WSK", "คลังสีคิ้ว", "นครราชสีมา", "สีคิ้ว", "ลาดบัวขาว", "30140", 14.8869, 101.7264),
    ("WPD", "คลังปทุมธานี", "ปทุมธานี", "เมืองปทุมธานี", "บางกะดี", "12000", 14.0208, 100.5250),
    ("WWP", "คลังวังน้อย", "พระนครศรีอยุธยา", "วังน้อย", "ลำตาเสา", "13170", 14.2167, 100.7167),
    ("WNB", "DC นนทบุรี", "นนทบุรี", "เมืองนนทบุรี", "บางกระสอ", "11000", 13.8591, 100.5217),
    ("WBN", "DC บางนา", "สมุทรปราการ", "บางพลี", "บางแก้ว", "10540", 13.6683, 100.6045),
]

# zone key, name, province, districts, max vehicle weight (kg)
ZONES = [
    ("TH-001", "โซนนครสวรรค์", "นครสวรรค์", ["อำเภอเมืองนครสวรรค์", "อำเภอพยุหะคีรี", "อำเภอโกรกพระ", "อำเภอชุมแสง", "อำเภอท่าตะโก"], 12500),
    ("TH-002", "โซนพิจิตร", "พิจิตร", ["อำเภอเมืองพิจิตร", "อำเภอตะพานหิน", "อำเภอบางมูลนาก", "อำเภอสามง่าม"], 9800),
    ("TH-003", "โซนพิษณุโลก", "พิษณุโลก", ["อำเภอเมืองพิษณุโลก", "อำเภอวังทอง", "อำเภอบางระกำ", "อำเภอพรหมพิราม"], 15400),
    ("TH-004", "โซนพระนครศรีอยุธยา", "พระนครศรีอยุธยา", ["อำเภอพระนครศรีอยุธยา", "อำเภอบางปะอิน", "อำเภอวังน้อย", "อำเภอนครหลวง", "อำเภออุทัย"], 18200),
    ("TH-005", "โซนลพบุรี", "ลพบุรี", ["อำเภอเมืองลพบุรี", "อำเภอบ้านหมี่", "อำเภอโคกสำโรง", "อำเภอท่าวุ้ง"], 11200),
    ("TH-006", "โซนสระบุรี", "สระบุรี", ["อำเภอเมืองสระบุรี", "อำเภอแก่งคอย", "อำเภอหนองแค", "อำเภอวิหารแดง"], 13600),
    ("TH-007", "โซนชลบุรี", "ชลบุรี", ["อำเภอเมืองชลบุรี", "อำเภอศรีราชา", "อำเภอบางละมุง", "อำเภอพานทอง", "อำเภอสัตหีบ"], 24000),
    ("TH-008", "โซนระยอง", "ระยอง", ["อำเภอเมืองระยอง", "อำเภอบ้านฉาง", "อำเภอปลวกแดง", "อำเภอนิคมพัฒนา", "อำเภอแกลง"], 16800),
    ("TH-009", "โซนนครปฐม", "นครปฐม", ["อำเภอเมืองนครปฐม", "อำเภอสามพราน", "อำเภอนครชัยศรี", "อำเภอกำแพงแสน", "อำเภอบางเลน"], 21500),
    ("TH-010", "โซนราชบุรี", "ราชบุรี", ["อำเภอเมืองราชบุรี", "อำเภอบ้านโป่ง", "อำเภอโพธาราม", "อำเภอดำเนินสะดวก", "อำเภอบางแพ"], 14300),
]

# route, name, origin warehouse, zones in running order, primary zone, colour, active
#
# The primary zone is the one the route exists for, which is not always the first
# it passes through: the northern run is set up for Phitsanulok at the far end,
# and calls at Nakhon Sawan and Phichit on the way. That distinction is the whole
# point of storing it — "which zone is this route" cannot be answered by taking
# the first stop.
ROUTES = [
    ("RT-NORTH-01", "สายเหนือ (นครสวรรค์ - พิษณุโลก)", "WNB", ["TH-001", "TH-002", "TH-003"], "TH-003", "#2563eb", "ACTIVE"),
    ("RT-EAST-01", "สายตะวันออก (ชลบุรี - ระยอง)", "WBN", ["TH-007", "TH-008"], "TH-008", "#16a34a", "ACTIVE"),
    ("RT-WEST-02", "สายตะวันตก (นครปฐม - ราชบุรี)", "WNB", ["TH-009", "TH-010"], "TH-010", "#ea580c", "ACTIVE"),
    ("RT-SOUTH-01", "สายใต้ (เพชรบุรี - ประจวบฯ)", "WBN", [], None, "#9333ea", "INACTIVE"),
]

# key, name, type, contact, phone, email, tax id, status
TRANSPORTERS = [
    ("CR-001", "Fleet อินเฮาส์ (คลังบางบัวทอง)", "INHOUSE", "ฝ่ายขนส่ง คลังบางบัวทอง", "02-123-4567", "fleet@example.test", "0105542000111", "ACTIVE"),
    ("CR-002", "ไทยขนส่งด่วน", "SUBCONTRACT", "คุณสมหมาย ธนกิจ", "081-999-1122", "ops@example.test", "0105551002233", "ACTIVE"),
    ("CR-003", "สยามโลจิสติกส์ พาร์ทเนอร์", "SUBCONTRACT", "คุณวราภรณ์ สุขใจ", "089-444-7788", "dispatch@example.test", "0105560004455", "ACTIVE"),
    ("CR-004", "บูรพาทรานสปอร์ต", "SUBCONTRACT", "คุณอนันต์ บูรพา", "086-222-3344", None, "0205549006677", "INACTIVE"),
]

# key, name, max weight kg, max cube, max pallet
# VEHICLETYPENAME เป็นอังกฤษไม่มีเว้นวรรค และสะกดตรงกับค่าที่ client ใช้เป็นคีย์
# เลือกรูปรถ (`4-wheel` / `6-wheel` / `10-wheel`) — ค่าที่เก็บกับค่าที่หน้าจอต้องการ
# จึงเป็นตัวเดียวกัน อ่านจากฐานแล้วเทียบกับโค้ดได้ทันทีโดยไม่ต้องแปลในหัว
#
# ป้ายภาษาไทยที่ผู้ใช้เห็น ("รถ 6 ล้อ") อยู่ที่ VEHICLE_LABEL ฝั่ง client
# ไม่ได้หายไปไหน — สิ่งที่เปลี่ยนคือ *ค่าที่เก็บ* ไม่ใช่ *คำที่แสดง*
VEHICLE_TYPES = [
    ("4W", "4-wheel", 3500, 12, 4),
    ("6W", "6-wheel", 8000, 22, 8),
    ("10W", "10-wheel", 15000, 35, 14),
]

# key, transporter, type, plate head, plate trailer, status
VEHICLES = [
    ("VH-001", "CR-001", "10W", "70-1234 นนทบุรี", "71-5678 นนทบุรี", "ACTIVE"),
    ("VH-002", "CR-001", "10W", "70-9012 นนทบุรี", "71-3344 นนทบุรี", "ACTIVE"),
    ("VH-003", "CR-002", "6W", "82-4455 กรุงเทพมหานคร", None, "ACTIVE"),
    ("VH-004", "CR-003", "6W", "82-7788 กรุงเทพมหานคร", None, "ACTIVE"),
    ("VH-005", "CR-002", "4W", "1กต 2414", None, "ACTIVE"),
    ("VH-006", "CR-003", "4W", "1กก 8899", None, "INACTIVE"),
]

# key, transporter, name, phone, licence no, licence type, default vehicle, status
DRIVERS = [
    ("DRV-001", "CR-001", "สมศักดิ์ ขยันส่ง", "081-234-5678", "6401234567", "ท.3", "VH-002", "ACTIVE"),
    ("DRV-002", "CR-001", "สมชาย ใจดี", "081-111-2222", "6402345678", "ท.2", "VH-001", "ACTIVE"),
    ("DRV-003", "CR-002", "ประเสริฐ ศรีสุข", "086-555-7777", "6403456789", "ท.2", "VH-004", "ACTIVE"),
    ("DRV-004", "CR-002", "วิชัย พงษ์ทอง", "089-876-5432", "6404567890", "ท.2", "VH-003", "ACTIVE"),
    ("DRV-005", "CR-003", "อนุชา ทองดี", "087-321-9900", "6405678901", "ท.1", "VH-005", "ACTIVE"),
    ("DRV-006", "CR-003", "ธนพล แสนดี", "092-448-1100", "6406789012", "ท.2", None, "INACTIVE"),
]

# customer key, name, address, subdistrict, district, province, zip, zone, route, lat, lng, cod
CUSTOMERS = [
    ("CUS-0001", "บจก. นครสวรรค์การค้า", "125/7 ถนนสวรรค์วิถี", "ปากน้ำโพ", "อำเภอเมืองนครสวรรค์", "นครสวรรค์", "60000", "TH-001", "RT-NORTH-01", 15.7047, 100.1372, 0),
    ("CUS-0002", "หจก. พิจิตรซัพพลาย", "88 ถนนบุษบา", "ในเมือง", "อำเภอเมืองพิจิตร", "พิจิตร", "66000", "TH-002", "RT-NORTH-01", 16.4429, 100.3487, 1),
    ("CUS-0003", "ร้านพิษณุโลกมาร์ท", "302 ถนนพิชัยสงคราม", "ในเมือง", "อำเภอเมืองพิษณุโลก", "พิษณุโลก", "65000", "TH-003", "RT-NORTH-01", 16.8211, 100.2659, 0),
    ("CUS-0004", "บจก. อยุธยาเทรดดิ้ง", "45 หมู่ 3 ถนนโรจนะ", "ไผ่ลิง", "อำเภอพระนครศรีอยุธยา", "พระนครศรีอยุธยา", "13000", "TH-004", None, 14.3532, 100.5689, 1),
    ("CUS-0005", "สหกรณ์ลพบุรี", "9 ถนนนารายณ์มหาราช", "ทะเลชุบศร", "อำเภอเมืองลพบุรี", "ลพบุรี", "15000", "TH-005", None, 14.7995, 100.6534, 0),
    ("CUS-0006", "บจก. สระบุรีวัสดุ", "77/1 ถนนพหลโยธิน", "ปากเพรียว", "อำเภอเมืองสระบุรี", "สระบุรี", "18000", "TH-006", None, 14.5289, 100.9101, 1),
    ("CUS-0007", "ชลบุรี ซูเปอร์มาร์เก็ต", "199 ถนนสุขุมวิท", "ศรีราชา", "อำเภอศรีราชา", "ชลบุรี", "20110", "TH-007", "RT-EAST-01", 13.1731, 100.9310, 0),
    ("CUS-0008", "ระยองฟู้ดส์", "56 ถนนสุขุมวิท", "เนินพระ", "อำเภอเมืองระยอง", "ระยอง", "21000", "TH-008", "RT-EAST-01", 12.6814, 101.2816, 1),
    ("CUS-0009", "นครปฐมค้าส่ง", "12 ถนนเพชรเกษม", "พระปฐมเจดีย์", "อำเภอเมืองนครปฐม", "นครปฐม", "73000", "TH-009", "RT-WEST-02", 13.8199, 100.0621, 0),
    ("CUS-0010", "ราชบุรีมาร์ท", "410 ถนนศรีสุริยวงศ์", "หน้าเมือง", "อำเภอเมืองราชบุรี", "ราชบุรี", "70000", "TH-010", "RT-WEST-02", 13.5282, 99.8134, 1),
]

# The demo accounts AuthController already answers for, so a login that works
# against the in-memory store also finds a row here once auth reads the database.
# PASSWORDHASH is a placeholder, not a hash of anything: nothing verifies
# passwords yet, and putting a real bcrypt digest here would suggest otherwise.
NO_PASSWORD = "!! NOT A HASH — login does not verify passwords yet !!"
USERS = [
    ("admin", "admin", "admin@example.test", "ผู้ดูแลระบบ", "ADMIN", None),
    ("manager", "manager", "manager@example.test", "ผู้จัดการ", "MANAGER", None),
    ("operator", "operator", "operator@example.test", "ผู้ปฏิบัติงาน", "OPERATOR", None),
    ("viewer", "viewer", "viewer@example.test", "ผู้ดูข้อมูล", "VIEWER", None),
    ("tms", "tms", "tms@example.test", "ฝ่ายขนส่ง (TMS)", "OPERATOR", ["/logistics"]),
    ("inbound", "inbound", "inbound@example.test", "ฝ่ายรับสินค้า", "OPERATOR", ["/inbound"]),
    ("outbound", "outbound", "outbound@example.test", "ฝ่ายจัดส่งออก", "OPERATOR", ["/outbound"]),
    ("warehouse", "warehouse", "warehouse@example.test", "ฝ่ายคลังสินค้า", "OPERATOR", ["/warehouse"]),
    ("inventory", "inventory", "inventory@example.test", "ฝ่ายสต็อก", "OPERATOR", ["/inventory"]),
    ("reports", "reports", "reports@example.test", "ฝ่ายรายงาน", "VIEWER", ["/reports"]),
    ("wms", "wms", "wms@example.test", "ฝ่ายคลัง (WMS)", "OPERATOR", ["/inbound", "/outbound", "/warehouse", "/inventory"]),
]

# sku, description, weight kg per unit, cube per unit, uom
SKUS = [
    ("SKU-1001", "น้ำดื่ม 600ml แพ็ค 12", 7.2, 0.012, "CS"),
    ("SKU-1002", "น้ำอัดลม 325ml แพ็ค 24", 8.6, 0.015, "CS"),
    ("SKU-1003", "ข้าวสารหอมมะลิ 5 กก.", 5.0, 0.007, "BG"),
    ("SKU-1004", "น้ำมันพืช 1 ลิตร แพ็ค 12", 11.4, 0.014, "CS"),
    ("SKU-1005", "บะหมี่กึ่งสำเร็จรูป ลัง 30", 2.4, 0.021, "CS"),
    ("SKU-1006", "ผงซักฟอก 900 กรัม แพ็ค 12", 10.8, 0.018, "CS"),
    ("SKU-1007", "กระดาษชำระ 12 ม้วน", 1.9, 0.045, "PK"),
    ("SKU-1008", "นมยูเอชที 200ml แพ็ค 36", 7.6, 0.013, "CS"),
]

# The five manifests, one parked at each step of ติดตามสถานะ.
#   key, status, warehouse, route, transporter, vehicle, driver, delivery date,
#   seal, dock, freight cost, status message, customers on board
MANIFESTS = [
    ("MN-202608-0043", "DRAFT", "WSK", "RT-NORTH-01", "CR-001", "VH-002", "DRV-001",
     date(2026, 8, 6), None, "Dock 3", 0, None, ["CUS-0001", "CUS-0003"]),
    ("MN-202608-0042", "CONFIRMED", "WPD", "RT-WEST-02", "CR-002", "VH-005", "DRV-005",
     date(2026, 8, 5), "SL-9988431", "Dock 1", 7200, None, ["CUS-0009", "CUS-0010"]),
    ("MN-202608-0041", "SENT", "WSK", "RT-EAST-01", "CR-001", "VH-001", "DRV-002",
     date(2026, 8, 4), "SL-9988420", "Dock 2", 0, None, ["CUS-0007", "CUS-0008"]),
    ("MN-202608-0040", "COMPLETED", "WPD", "RT-WEST-02", "CR-002", "VH-003", "DRV-004",
     date(2026, 8, 3), "SL-9988418", "Dock 1", 8500, "OMS ยืนยันการจัดส่งครบถ้วน",
     ["CUS-0009", "CUS-0010"]),
    ("MN-202608-0039", "ERROR", "WWP", "RT-EAST-01", "CR-003", "VH-004", "DRV-003",
     date(2026, 8, 2), "SL-9988409", "Dock 2", 6400,
     "WMS ตีกลับ — จำนวนกล่องไม่ตรงกับใบสั่งส่ง DO-2026-0786", ["CUS-0007", "CUS-0008"]),
]

# Which status log entries each manifest status implies. Anything past DRAFT has
# been through the steps before it, so the timeline reads as a history rather
# than a single current value.
STATUS_STEPS = ["DRAFT", "CONFIRMED", "SENT", "COMPLETED"]


def zone_of(customer_key: str) -> str:
    return next(c[7] for c in CUSTOMERS if c[0] == customer_key)


def customer_row(customer_key: str) -> tuple:
    return next(c for c in CUSTOMERS if c[0] == customer_key)


# ─────────────────────────────────────────────────────────────────────────────
# Column defaults for the wide legacy tables
#
# MST_OWNER, MST_SKU and DOC_DO_DETAIL declare 40-70 NOT NULL columns each with
# no defaults -- the WMS they came from wrote every one on every insert. Listing
# them here keeps the row builders below readable, and keeps the "what does this
# column mean" question in one place instead of scattered through the file.
# ─────────────────────────────────────────────────────────────────────────────

OWNER_DEFAULTS: dict[str, Any] = {
    "TYPE": "OWNER", "SOURCEVERSION": "1", "CARTONGROUP": "STD", "PICKCODE": "STD",
    "CREATEPATASKONRFRECEIPT": "N", "CALCULATEPUTAWAYLOCATION": "N", "ROLLRECEIPT": "N",
    "RECEIPTVALIDATIONTEMPLATE": "STD", "ALLOWAUTOCLOSEFORPO": "N",
    "ALLOWAUTOCLOSEFORASN": "N", "ALLOWAUTOCLOSEFORPS": "N",
    "ALLOWSYSTEMGENERATEDLPN": "Y", "ALLOWDUPLICATELICENSEPLATES": "N",
    "ALLOWCOMMINGLEDLPN": "N", "ALLOWSINGLESCANRECEIVING": "N", "LPNLENGTH": 20,
    "APPLICATIONID": "00", "SSCC1STDIGIT": 0, "UCCVENDORNUMBER": "000000000",
    "AUTOPRINTLABELLPN": "N", "AUTOPRINTLABELPUTAWAY": "N", "LPNSTARTNUMBER": "1",
    "NEXTLPNNUMBER": "1", "LPNROLLBACKNUMBER": "1", "AUTOCLOSEASN": "N",
    "AUTOCLOSEPO": "N", "DEFAULTRETURNSLOC": "RETURNS", "DEFAULTQCLOC": "QC",
    "PISKUXLOC": "N", "CCSKUXLOC": "N", "CCDISCREPANCYRULE": "STD", "CCADJBYRF": "N",
    "ORDERBREAKDEFAULT": "N", "SKUSETUPREQUIRED": "Y", "DEFAULTQCLOCOUT": "QCOUT",
    "KSHIP_CARRIER": 0, "REQREASONSHORTSHIP": 0, "CONTAINEREXCHANGEFLAG": 0,
    "CARTONIZEFTDFLT": "N", "DEFFTLABELPRINT": "N", "DEFFTTASKCONTROL": "N",
    "PLANDAYS": 7, "ARCHIVEPLANNINGDAYS": 30, "ARCHIVEREPORTINGDATA": 90,
    "PLANENABLED": 0, "DEFAULTHOURLYRATE": 0, "SAVESTANDARDSAUDIT": 0,
    "TEMPFORASN": "N", "MIXEDLPNPUTSTRATEGY": "STD", "RFAUTOFILLRCVLPN": "N",
    "INBOUNDLPNLENGTH": 20, "USEPARTNERLPNCONTROL": "N",
    "AUTOFINALIZEPRODORDER": "N", "CREATEMOVESFROMPROD": "N", "PRODCOUNTLOC": "PROD",
    "QUARANTINEINDICATOR": "N",
}

SKU_DEFAULTS: dict[str, Any] = {
    "ITEMREFERENCE": "STD", "PACKKEY": "STD", "TARE": 0, "CLASS": "A",
    "ACTIVE": "Y", "SKUGROUP": "GEN", "PICKCODE": "STD", "CARTONGROUP": "STD",
    "PUTCODE": "STD", "PUTAWAYLOC": "STAGE", "INNERPACK": 1,
    "SHELFLIFECODETYPE": "N", "SHELFLIFEONRECEIVING": 0,
    "LOTTABLEVALIDATIONKEY": "STD", "RETURNSLOC": "RETURNS", "QCLOC": "QC",
    "SKUTYPE": "S", "StackLimit": 5, "MaxPalletsPerZone": 20,
    "CATCHGROSSWGT": 0, "CATCHNETWGT": 0, "CATCHTAREWGT": 0,
    "TAREWGT1": 0, "STDNETWGT1": 0, "STDGROSSWGT1": 0,
}

DO_DETAIL_DEFAULTS: dict[str, Any] = {
    "MANUFACTURERSKU": "", "RETAILSKU": "", "ALTSKU": "", "SHIPPEDQTY": 0,
    "ADJUSTEDQTY": 0, "QTYPREALLOCATED": 0, "QTYALLOCATED": 0, "QTYPICKED": 0,
    "PACKKEY": "STD", "CARTONGROUP": "STD", "LOT": "", "ID": "", "FACILITY": WHSE,
    "TAX01": 0, "TAX02": 0, "UPDATESOURCE": "SEED",
    "LOTTABLE01": "", "LOTTABLE02": "", "LOTTABLE03": "", "LOTTABLE06": "",
    "LOTTABLE07": "", "LOTTABLE08": "", "LOTTABLE09": "", "LOTTABLE10": "",
}


def with_defaults(defaults: dict[str, Any], **overrides: Any) -> dict[str, Any]:
    row = dict(defaults)
    row.update(overrides)
    return row


def rows_from_dicts(dicts: list[dict[str, Any]]) -> tuple[list[str], list[list[Any]]]:
    """Column order comes from the first row; every row must carry the same keys."""
    columns = list(dicts[0].keys())
    rows = []
    for d in dicts:
        missing = set(columns) ^ set(d.keys())
        if missing:
            raise RuntimeError(f"row shape differs by {sorted(missing)}")
        rows.append([d[c] for c in columns])
    return columns, rows


# ─────────────────────────────────────────────────────────────────────────────
# Generated volume
# ─────────────────────────────────────────────────────────────────────────────

class Counter:
    """Document numbers, issued in one place so no two documents collide."""

    def __init__(self) -> None:
        self.extern = 0
        self.do = 0

    def next_extern(self) -> str:
        self.extern += 1
        return f"OMS-99{200000 + self.extern}"

    def next_do(self) -> str:
        self.do += 1
        return f"DO-2026-{9000 + self.do}"


def upstream_order(counter: Counter, customer: tuple, whse: str, rng: random.Random,
                   order_day: date, requested: date) -> dict[str, Any]:
    """What the customer asked for, as it arrives from SAP through OMS.

    Exists only inside this generator. TMS does not store it — the document
    lives in another system and reaches the database as a reference string in
    `DOC_DO_HDR.EXTERNORDERKEY`. It is modelled here so the delivery orders come
    out related to each other the way real ones are: several of them can trace
    back to the same upstream document, each carrying part of it.
    """
    lines = []
    for line_no, (sku, _descr, weight, cube, uom) in enumerate(
            rng.sample(SKUS, rng.randint(1, 4)), start=1):
        qty = rng.randint(20, 400)
        price = round(18 + (hash(sku) % 40), 2)
        lines.append({
            "line": f"{line_no:05d}", "sku": sku, "uom": uom, "qty": qty,
            "price": price, "weight": weight, "cube": cube, "shipped": 0,
        })
    return {
        "externkey": counter.next_extern(),
        "whse": whse,
        "customer": customer[0],
        "shipto": customer[0],
        "orderdate": datetime.combine(order_day, datetime.min.time())
                     + timedelta(hours=rng.randint(6, 18)),
        "requested": requested,
        "lines": lines,
        "dos": [],
    }


def delivery_orders_for(so: dict[str, Any], counter: Counter, rng: random.Random,
                        splits: int, due: date, status: str,
                        raise_only: int | None = None) -> list[dict[str, Any]]:
    """Raise delivery orders against one upstream document.

    A delivery order is one lorry-load leaving a warehouse. One customer order
    shipped in two runs is ordinary — stock ran short, the customer asked for it
    in parts, or it comes from two warehouses — so this is deliberately not
    one-to-one, and several delivery orders can carry the same EXTERNORDERKEY.

    `raise_only` stops early, leaving part of the order unshipped, so the pool
    is not made entirely of documents where everything already went out.
    """
    customer = customer_row(so["customer"])
    dos = []
    for split in range(splits):
        if raise_only is not None and split >= raise_only:
            break
        lines = []
        for line in so["lines"]:
            remaining = line["qty"] - line["shipped"]
            if remaining <= 0:
                continue
            # The last split takes everything left, so nothing is stranded.
            qty = remaining if split == splits - 1 else max(1, remaining // (splits - split))
            line["shipped"] += qty
            lines.append({**line, "qty": qty})
        if not lines:
            continue
        dos.append({
            "orderkey": counter.next_do(),
            "externkey": so["externkey"],
            "whse": so["whse"],
            "customer": so["customer"],
            "zone": customer[7],
            "route": customer[8],
            "orderdate": so["orderdate"],
            "duedate": due,
            "lines": lines,
            "status": status,
        })
    so["dos"].extend(d["orderkey"] for d in dos)
    return dos




def generated_documents(count: int, rng: random.Random,
                        counter: Counter) -> tuple[list[dict], list[dict]]:
    """The pending pool: delivery orders waiting to be planned onto a run.

    Due dates are spread either side of the fixture date on purpose — a pool
    where everything is due the same day cannot show whether the "how late is
    this" column works. Some upstream documents are left with no delivery order
    raised yet and some only half raised, so the pool is not made entirely of
    orders that already went out in one clean piece.
    """
    sources, dos = [], []
    for _ in range(count):
        customer = rng.choice(CUSTOMERS)
        whse = rng.choice(["WSK", "WPD", "WWP"])
        order_day = TODAY - timedelta(days=rng.randint(1, 20))
        due = TODAY + timedelta(days=rng.choice(
            [-12, -8, -5, -3, -2, -1, 0, 1, 2, 3, 4, 5, 6, 7]))
        src = upstream_order(counter, customer, whse, rng, order_day, due)

        roll = rng.random()
        if roll < 0.15:
            pass                                     # ยังไม่ออกใบสั่งส่งเลย
        elif roll < 0.40:
            dos.extend(delivery_orders_for(          # ออกไปครึ่งเดียว
                src, counter, rng, 2, due, "NEW", raise_only=1))
        else:
            splits = 1 if rng.random() < 0.7 else 2  # ออกครบแล้ว
            dos.extend(delivery_orders_for(src, counter, rng, splits, due, "NEW"))
        sources.append(src)
    return sources, dos


# ─────────────────────────────────────────────────────────────────────────────
# Script assembly
# ─────────────────────────────────────────────────────────────────────────────

# Reverse foreign-key order. Deleting in this order never orphans a child row,
# so re-running does not need constraints disabled.
DELETE_ORDER = [
    "DOC_SHIPMENT_STATUS_LOG", "DOC_SHIPMENT_DETAIL_LINE", "DOC_SHIPMENT_DETAIL",
    "DOC_SHIPMENT_STOP", "DOC_SHIPMENT_HDR",
    "DOC_TRANSPORT_PLAN_LINE", "DOC_TRANSPORT_PLAN",
    "DOC_DO_DETAIL", "DOC_DO_HDR",
    "MST_USER_MODULE", "MST_USER",
    "MST_CUSTOMER", "MST_SKU",
    "MST_ROUTE_ZONE", "MST_ZONE_COVERAGE", "MST_TRANSPORTATIONZONE",
    "MST_DRIVER", "MST_VEHICLE", "MST_VEHICLETYPE", "MST_TRANSPORTER",
    "MST_ROUTE", "MST_OWNER", "MST_WHSE",
]


def build_sql(orders: int, rng: random.Random) -> str:
    now = datetime(2026, 8, 5, 9, 0, 0)
    parts: list[str] = []
    counts: dict[str, int] = {}

    def emit(table: str, columns: Sequence[str], rows: list) -> None:
        counts[table] = len(rows)
        parts.append(insert(table, columns, rows))

    parts.append(f"""/* =============================================================================
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
""")

    for table in DELETE_ORDER:
        parts.append(f"DELETE FROM dbo.{table};")
    parts.append("GO\n\nPRINT 'inserting demo rows';\n")

    # ── MST_WHSE ────────────────────────────────────────────────────────────
    # type ต้องเป็น 'E' หรือ 'S' เท่านั้น — CK_site_type บังคับไว้ในฐานเดิม
    # ไม่มีตารางรหัสบอกว่าสองตัวนี้แปลว่าอะไร (S = site น่าจะใช่ ส่วน E ยังไม่รู้)
    # เป็นตัวอย่างของ "ค่า STATUS/รหัสที่เดาไม่ได้" ใน README หัวข้อ 5 ข้อ 2
    emit("MST_WHSE",
         ["WHSEID", "description", "WHSENAME", "type", "lang_code", "time_zone",
          "ADDRESS1", "SUBDISTRICT", "DISTRICT", "PROVINCE", "POSTALCODE",
          "LATITUDE", "LONGITUDE", "IS_DC", "STATUS", "ADDDATE", "ADDWHO"],
         [(code, name, name, "S", "th-TH", "Asia/Bangkok",
           "", sub, dist, prov, zipcode, lat, lng, True, "ACTIVE", now, "seed")
          for code, name, prov, dist, sub, zipcode, lat, lng in WAREHOUSES])

    # ── MST_OWNER ───────────────────────────────────────────────────────────
    owner = with_defaults(OWNER_DEFAULTS, OWNERKEY=OWNER, WHSEID=WHSE, ADDDATE=now, ADDWHO="seed")
    cols, rows = rows_from_dicts([owner])
    emit("MST_OWNER", cols, rows)

    # ── MST_ROUTE ───────────────────────────────────────────────────────────
    emit("MST_ROUTE",
         ["ROUTE", "WHSEID", "ROUTENAME", "ORIGIN_WHSEID", "COLOURHEX", "TRANSIT_DAY",
          "STATUS", "ADDDATE", "ADDWHO"],
         [(route, WHSE, name, origin, colour, 1 + i % 2, status, now, "seed")
          for i, (route, name, origin, _zones, _primary, colour, status) in enumerate(ROUTES)])

    # ── MST_TRANSPORTATIONZONE ──────────────────────────────────────────────
    # DEFAULTROUTE is the zone's main run; MST_ROUTE_ZONE below carries the rest.
    default_route = {z: r for r, _n, _o, zones, _p, _c, _s in ROUTES for z in zones}
    emit("MST_TRANSPORTATIONZONE",
         ["WHSEID", "OWNERKEY", "TRANSPORTZONEKEY", "TRANSPORTZONENAME", "COUNTRY",
          "PROVINCE", "DELIVERYLEADDAY", "DEFAULTROUTE", "PRIORITY",
          "MAX_VEHICLE_WEIGHT", "WEIGHT_UOM", "STATUS", "ADDDATE", "ADDWHO"],
         [(WHSE, OWNER20, key, name, "TH", province, 1 + i % 3,
           default_route.get(key), i + 1, weight, "kg", "ACTIVE", now, "seed")
          for i, (key, name, province, _districts, weight) in enumerate(ZONES)])

    # ── MST_ZONE_COVERAGE ───────────────────────────────────────────────────
    emit("MST_ZONE_COVERAGE",
         ["WHSEID", "OWNERKEY", "TRANSPORTZONEKEY", "PROVINCE", "DISTRICT",
          "STATUS", "ADDDATE", "ADDWHO"],
         [(WHSE, OWNER20, key, province, district, "ACTIVE", now, "seed")
          for key, _name, province, districts, _w in ZONES
          for district in districts])

    # ── MST_ROUTE_ZONE ──────────────────────────────────────────────────────
    emit("MST_ROUTE_ZONE",
         ["ROUTE", "WHSEID", "OWNERKEY", "TRANSPORTZONEKEY", "SEQUENCE",
          "IS_PRIMARY", "STATUS", "ADDDATE", "ADDWHO"],
         [(route, WHSE, OWNER20, zone, seq, zone == primary, "ACTIVE", now, "seed")
          for route, _n, _o, zones, primary, _c, _s in ROUTES
          for seq, zone in enumerate(zones, start=1)])

    # ── MST_TRANSPORTER ─────────────────────────────────────────────────────
    emit("MST_TRANSPORTER",
         ["TRANSPORTERKEY", "TRANSPORTERNAME", "TRANSPORTERTYPE", "CONTACTNAME",
          "PHONE", "EMAIL", "TAXID", "STATUS", "ADDDATE", "ADDWHO"],
         [(key, name, kind, contact, phone, email, tax, status, now, "seed")
          for key, name, kind, contact, phone, email, tax, status in TRANSPORTERS])

    # ── MST_VEHICLETYPE ─────────────────────────────────────────────────────
    emit("MST_VEHICLETYPE",
         ["VEHICLETYPEKEY", "VEHICLETYPENAME", "MAXWEIGHT", "MAXCUBE", "MAXPALLET",
          "STATUS", "ADDDATE", "ADDWHO"],
         [(key, name, w, c, p, "ACTIVE", now, "seed")
          for key, name, w, c, p in VEHICLE_TYPES])

    # ── MST_VEHICLE ─────────────────────────────────────────────────────────
    emit("MST_VEHICLE",
         ["VEHICLEKEY", "TRANSPORTERKEY", "VEHICLETYPEKEY", "LICENSEPLATE",
          "PLATE_TRAILER", "STATUS", "ADDDATE", "ADDWHO"],
         [(key, transporter, kind, head, trailer, status, now, "seed")
          for key, transporter, kind, head, trailer, status in VEHICLES])

    # ── MST_DRIVER ──────────────────────────────────────────────────────────
    emit("MST_DRIVER",
         ["DRIVERKEY", "TRANSPORTERKEY", "DRIVERNAME", "MOBILE", "LICENSE_NO",
          "LICENSE_TYPE", "DEFAULT_VEHICLEKEY", "STATUS", "ADDDATE", "ADDWHO"],
         [(key, transporter, name, phone, lic, lic_type, vehicle, status, now, "seed")
          for key, transporter, name, phone, lic, lic_type, vehicle, status in DRIVERS])

    # ── MST_CUSTOMER ────────────────────────────────────────────────────────
    emit("MST_CUSTOMER",
         ["WHSEID", "OWNERKEY", "CUSTOMERKEY", "CUSTOMERNAME", "ADDRESS1",
          "SUBDISTRICT", "DISTRICT", "PROVINCE", "POSTALCODE", "COUNTRY",
          "LATITUDE", "LONGITUDE", "TRANSPORTZONEKEY", "ROUTE", "COD_FLAG",
          "STATUS", "ADDDATE", "ADDWHO"],
         [(WHSE, OWNER, key, name, addr, sub, dist, prov, zipcode, "TH",
           lat, lng, zone, route, cod, "ACTIVE", now, "seed")
          for key, name, addr, sub, dist, prov, zipcode, zone, route, lat, lng, cod
          in CUSTOMERS])

    # ── MST_SKU ─────────────────────────────────────────────────────────────
    sku_rows = [with_defaults(
        SKU_DEFAULTS, site_ref=WHSE, OWNERKEY=OWNER, SKU=sku, DESCR=descr,
        STDGROSSWGT=weight, STDNETWGT=weight, STDCUBE=cube,
        CUBE=cube, GROSSWGT=weight, NETWGT=weight, PICKUOM=uom,
        ADDDATE=now, ADDWHO="seed")
        for sku, descr, weight, cube, uom in SKUS]
    cols, rows = rows_from_dicts(sku_rows)
    emit("MST_SKU", cols, rows)

    # ── MST_USER / MST_USER_MODULE ──────────────────────────────────────────
    emit("MST_USER",
         ["USERKEY", "USERNAME", "EMAIL", "DISPLAYNAME", "PASSWORDHASH", "ROLECODE",
          "DEFAULT_WHSEID", "STATUS", "ADDDATE", "ADDWHO"],
         [(key, username, email, display, NO_PASSWORD, role, WHSE, "ACTIVE", now, "seed")
          for key, username, email, display, role, _modules in USERS])

    emit("MST_USER_MODULE",
         ["USERKEY", "MODULEPATH", "ADDDATE", "ADDWHO"],
         [(key, module, now, "seed")
          for key, _u, _e, _d, _r, modules in USERS
          for module in (modules or [])])

    # ── DOC_DO_HDR / DOC_DO_DETAIL ──────────────────────────────────────────
    #
    # ใบสั่งส่ง (DO) คือของหนึ่งเที่ยวรถที่ออกจากคลัง เอกสารต้นทางที่ทำให้เกิดมัน
    # อยู่ในระบบอื่น (SAP ส่งผ่าน OMS) จึงเก็บเป็น *เลขอ้างอิง* ใน EXTERNORDERKEY
    # ไม่ใช่ตารางในฐานนี้ — เอกสารต้นทางใบเดียวออก DO ได้หลายใบ ตัวแปร
    # `upstream_order` ข้างล่างจึงมีอยู่เพื่อสร้างความสัมพันธ์นั้นให้สมจริง
    # ไม่ได้แปลว่ามันจะถูกเขียนลงตารางที่ไหน
    #
    # ⚠ **SO ในโปรเจคนี้ไม่ใช่ Sales Order** แต่คือ *Shipment Order* = ใบปิดบรรทุก
    #   ซึ่งมีตารางของตัวเองอยู่แล้วคือ DOC_SHIPMENT_HDR ข้างล่าง
    #   เลขอ้างอิงต้นทางจึงตั้งขึ้นต้นว่า OMS- ไม่ใช่ SO- เพื่อไม่ให้อ่านแล้วสับสน
    #
    # ใบที่อยู่บนใบปิดบรรทุกถูกสร้างก่อน เพื่อให้ทุกจุดส่งชี้ไปที่ DO ที่มีอยู่จริง
    # ในตาราง แทนที่จะเป็นเลขที่แต่งขึ้นลอย ๆ
    counter = Counter()
    manifest_dos: dict[tuple[str, str], dict[str, Any]] = {}

    for key, status, whse, _r, _t, _v, _d, delivery, *_rest, customers in MANIFESTS:
        for customer_key in customers:
            order_day = delivery - timedelta(days=rng.randint(2, 6))
            src = upstream_order(counter, customer_row(customer_key), whse, rng,
                                 order_day, delivery)
            # A document already on a lorry has shipped in full — a split here
            # would leave a remainder with nowhere to be.
            do_status = "SHIPPED" if status in ("SENT", "COMPLETED") else "PICKED"
            dos = delivery_orders_for(src, counter, rng, 1, delivery, do_status)
            manifest_dos[(key, customer_key)] = dos[0]

    _pool_sources, pool_dos = generated_documents(orders, rng, counter)
    all_dos = list(manifest_dos.values()) + pool_dos

    emit("DOC_DO_HDR",
         ["WHSEID", "ORDERKEY", "OWNERKEY", "EXTERNORDERKEY", "ORDERDATE",
          "DELIVERYDATE", "PRIORITY", "SHIPTO", "C_COMPANY", "DOOR", "BATCHFLAG",
          "STATUS", "TYPE", "ORDERGROUP", "ROUTE", "ZONE", "ADDDATE", "ADDWHO"],
         [(o["whse"], o["orderkey"], OWNER, o["externkey"], o["orderdate"],
           o["duedate"], "5", o["customer"], customer_row(o["customer"])[1],
           "D01", "N", o["status"], "SO", "GEN", o["route"], o["zone"], now, "seed")
          for o in all_dos])

    detail_rows = []
    for o in all_dos:
        for line in o["lines"]:
            qty = line["qty"]
            detail_rows.append(with_defaults(
                DO_DETAIL_DEFAULTS,
                WHSEID=o["whse"], ORDERKEY=o["orderkey"],
                ORDERLINENUMBER=line["line"], EXTERNORDERKEY=o["externkey"],
                # Points back at the sales-order line, not just the sales order,
                # so a partial shipment can be traced to the line it came from.
                EXTERNLINENO=line["line"], SKU=line["sku"], OWNERKEY=OWNER,
                ORIGINALQTY=qty, OPENQTY=0 if o["status"] != "NEW" else qty,
                SHIPPEDQTY=qty if o["status"] == "SHIPPED" else 0,
                UOM=line["uom"], STATUS=o["status"],
                UNITPRICE=line["price"], EXTENDEDPRICE=round(line["price"] * qty, 2),
                PRODUCT_WEIGHT=round(line["weight"] * qty, 3),
                PRODUCT_CUBE=round(line["cube"] * qty, 4),
                FACILITY=o["whse"], ADDDATE=now, ADDWHO="seed"))
    cols, rows = rows_from_dicts(detail_rows)
    emit("DOC_DO_DETAIL", cols, rows)

    # ── DOC_TRANSPORT_PLAN ──────────────────────────────────────────────────
    # One draft plan holding nothing, matching Data/Seed.cs: pulling orders into
    # it at seed time would make them vanish from the pending pool before anyone
    # had planned anything.
    emit("DOC_TRANSPORT_PLAN",
         ["WHSEID", "PLANKEY", "PLANDATE", "DELIVERYDATE", "ZONE", "ROUTE",
          "TOTALORDER", "STATUS", "NOTES", "ADDDATE", "ADDWHO"],
         [(WHSE, "PL-202608-0001", now, date(2026, 8, 7), "TH-001", "RT-NORTH-01",
           0, "DRAFT", "รอบเช้า สายเหนือ", now, "seed")])
    emit("DOC_TRANSPORT_PLAN_LINE", ["WHSEID", "PLANKEY", "ORDERKEY", "STATUS",
                                     "ADDDATE", "ADDWHO"], [])

    # ── DOC_SHIPMENT_* ──────────────────────────────────────────────────────
    hdr, stops, details, lines, logs = [], [], [], [], []

    for key, status, whse, route, transporter, vehicle, driver, \
            delivery, seal, dock, cost, message, customers in MANIFESTS:
        closed = datetime.combine(delivery - timedelta(days=1), datetime.min.time()) + timedelta(hours=9)
        hdr.append((whse, key, closed, delivery, route, zone_of(customers[0]),
                    transporter, vehicle, driver, seal, dock, len(customers),
                    cost, cost, status, message, now, "seed"))

        for stop_seq, customer_key in enumerate(customers, start=1):
            c = customer_row(customer_key)
            stop_id = stop_seq
            stops.append((whse, key, stop_id, stop_seq, customer_key, c[1],
                          c[2], c[4], c[5], c[6], c[9], c[10],
                          "DELIVERED" if status == "COMPLETED" else "NEW", now, "seed"))

            # The delivery order raised for this stop above — a real row in
            # DOC_DO_HDR, carrying the sales order it came from.
            do = manifest_dos[(key, customer_key)]
            detail_id = stop_seq
            details.append((whse, key, detail_id, stop_id, do["orderkey"],
                            do["externkey"], OWNER20, route,
                            zone_of(customer_key), delivery,
                            "DELIVERED" if status == "COMPLETED" else "NEW", now, "seed"))

            # Lines are the delivery order's own, not fresh random ones: the
            # quantity on the lorry has to be the quantity the document says.
            for line_no, line in enumerate(do["lines"], start=1):
                qty = line["qty"]
                shipped = qty if status in ("SENT", "COMPLETED") else 0
                delivered = qty if status == "COMPLETED" else 0
                lines.append((whse, key, detail_id, line_no, do["orderkey"],
                              line["line"], line["sku"], line["uom"],
                              qty, qty, shipped, shipped, delivered,
                              "DELIVERED" if status == "COMPLETED" else "NEW", now, "seed"))

        # Every step the document has already passed, then its current one.
        history = STATUS_STEPS[:STATUS_STEPS.index(status) + 1] if status in STATUS_STEPS \
            else STATUS_STEPS[:3] + ["ERROR"]
        for step_index, step in enumerate(history):
            logs.append((whse, key,
                         history[step_index - 1] if step_index else None, step,
                         "OMS" if step in ("COMPLETED", "ERROR") else "TMS",
                         message if step == history[-1] else None,
                         closed + timedelta(minutes=25 * step_index), "seed"))

    emit("DOC_SHIPMENT_HDR",
         ["WHSEID", "SHIPMENTKEY", "SHIPMENTDATE", "DELIVERYDATE", "ROUTE", "ZONE",
          "TRANSPORTERKEY", "VEHICLEKEY", "DRIVERKEY", "SEALNO", "DOOR",
          "TOTALSTOP", "ESTIMATEDCOST", "ACTUALCOST", "STATUS", "STATUSMESSAGE",
          "ADDDATE", "ADDWHO"], hdr)

    emit("DOC_SHIPMENT_STOP",
         ["WHSEID", "SHIPMENTKEY", "SHIPMENTSTOPID", "STOPSEQ", "CUSTOMERKEY",
          "SHIPTONAME", "ADDRESS1", "DISTRICT", "PROVINCE", "POSTALCODE",
          "LATITUDE", "LONGITUDE", "STATUS", "ADDDATE", "ADDWHO"], stops)

    emit("DOC_SHIPMENT_DETAIL",
         ["WHSEID", "SHIPMENTKEY", "SHIPMENTDETAILID", "SHIPMENTSTOPID", "ORDERKEY",
          "EXTERNORDERKEY", "OWNERKEY", "ROUTE", "ZONE", "REQUIREDDELIVERYDATE",
          "STATUS", "ADDDATE", "ADDWHO"], details)

    emit("DOC_SHIPMENT_DETAIL_LINE",
         ["WHSEID", "SHIPMENTKEY", "SHIPMENTDETAILID", "SHIPMENTLINENO", "ORDERKEY",
          "ORDERLINENO", "SKU", "UOM", "ORDERQTY", "SHIPMENTQTY", "PICKEDQTY",
          "LOADEDQTY", "DELIVEREDQTY", "STATUS", "ADDDATE", "ADDWHO"], lines)

    emit("DOC_SHIPMENT_STATUS_LOG",
         ["WHSEID", "SHIPMENTKEY", "FROMSTATUS", "TOSTATUS", "SOURCESYSTEM",
          "MESSAGE", "CHANGEDATE", "CHANGEWHO"], logs)

    parts.append("""
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
""")

    return "\n".join(parts), counts


def apply_sql(path: Path, server: str, database: str) -> int:
    print(f"\nรันเข้า {database} บน {server}")
    result = subprocess.run(
        ["sqlcmd", "-S", server, "-E", "-C", "-d", database, "-b", "-i", str(path)],
        capture_output=True, text=True)
    if result.returncode != 0:
        print(result.stdout)
        print(result.stderr, file=sys.stderr)
        print("\nรันไม่สำเร็จ — ไม่มีอะไรถูกเขียนลงฐาน (XACT_ABORT rollback ให้แล้ว)",
              file=sys.stderr)
        return result.returncode
    print(result.stdout)
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Generate SQL Server development data for the MMDEV database.")
    parser.add_argument("--orders", type=int, default=40,
                        help="generated delivery orders on top of the fixed fixtures")
    parser.add_argument("--seed", type=int, default=20260814,
                        help="RNG seed; the same seed always produces the same file")
    parser.add_argument("--out", type=Path, default=DEFAULT_OUT)
    parser.add_argument("--apply", action="store_true",
                        help="run the generated file with sqlcmd")
    parser.add_argument("--server", default="(localdb)\\MSSQLLocalDB")
    parser.add_argument("--database", default="MMDEV")
    args = parser.parse_args()

    if args.orders < 0:
        raise SystemExit("--orders ต้องไม่ติดลบ")

    sql, counts = build_sql(args.orders, random.Random(args.seed))
    args.out.parent.mkdir(parents=True, exist_ok=True)

    # utf-8-sig, ไม่ใช่ utf-8 เฉย ๆ — sqlcmd อ่านไฟล์ที่ไม่มี BOM เป็น codepage
    # ของ Windows ทำให้ทุกตัวอักษรไทยกลายเป็นหลายไบต์ที่แปลไม่ออก แล้วล้มด้วย
    # Msg 2628 "String or binary data would be truncated" ซึ่งชี้ไปผิดที่สนิท:
    # ทะเบียนรถ 21 ตัวอักษรลงคอลัมน์ nvarchar(30) ได้สบาย ปัญหาอยู่ที่การอ่านไฟล์
    # ไม่ใช่ความยาวข้อมูล · BOM สามไบต์แก้ได้ทั้งหมด
    args.out.write_text(sql, encoding="utf-8-sig")

    print(f"เขียน {args.out.relative_to(REPO_ROOT)}  ({len(sql):,} ตัวอักษร)\n")
    for table, n in counts.items():
        print(f"  {table:<28} {n:>6,}")
    print(f"  {'รวม':<28} {sum(counts.values()):>6,}")

    if args.apply:
        return apply_sql(args.out, args.server, args.database)

    print("\nยังไม่ได้เขียนลงฐาน — เติม --apply ถ้าต้องการรันจริง")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
