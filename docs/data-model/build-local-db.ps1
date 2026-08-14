<#
.SYNOPSIS
    สร้างฐาน MMDEV ในเครื่องขึ้นใหม่ทั้งใบ จากสคริปต์ในโฟลเดอร์นี้

.DESCRIPTION
    รันสี่ไฟล์ตามลำดับ แต่ละไฟล์ต้องผ่านก่อนถึงจะไปต่อ:

      1. 00-user-defined-types.sql   UDT ที่ script ของฐานอ้างถึงแต่ไม่ได้แนบมา
      2. <schema>                    DDL ของฐานจริง (ไม่ได้อยู่ใน repo ดู -SchemaFile)
      3. 01-new-tables.sql           ตารางที่ยังไม่มีในฐาน
      4. 02-alter-existing.sql       PK/ชนิดข้อมูล/FK/ดัชนีที่ต้องแก้
      5. 03-seed-demo-data.sql       ข้อมูลตัวอย่าง — เฉพาะเมื่อใส่ -Seed

.PARAMETER Seed
    ใส่ข้อมูลตัวอย่างต่อท้ายด้วย ไฟล์ 03 สร้างจาก tests/generate_sql_data.py
    ถ้ายังไม่มีไฟล์ สคริปต์จะบอกวิธีสร้างแล้วจบแบบปกติ ไม่ล้ม

    **ลบฐานเดิมทิ้งทุกครั้ง** ตั้งใจให้เป็นแบบนั้น เพราะฐานนี้มีไว้ทดสอบว่า
    สคริปต์รันผ่านบนของเปล่า ไม่ใช่ที่เก็บข้อมูลที่ต้องรักษา — อย่าชี้ไปฐานที่มี
    ข้อมูลจริง สคริปต์จะถามยืนยันถ้าฐานปลายทางมีข้อมูลอยู่

.PARAMETER SchemaFile
    พาธของ DDL ฐานจริง (`*_TABLE2_R03.sql`) ซึ่ง **ไม่ได้อยู่ใน repo**
    เพราะเป็นโครงสร้างฐาน production ของลูกค้า ถ้าไม่ระบุ จะมองหาไฟล์
    `*TABLE2*.sql` ในโฟลเดอร์ docs/data-model/vendor/ ซึ่ง gitignore ไว้แล้ว

.EXAMPLE
    .\build-local-db.ps1
    .\build-local-db.ps1 -Server ".\SQLEXPRESS" -Database MMDEV -SchemaFile "$HOME\Downloads\MAMMOD_TABLE2_R03.sql"
#>
[CmdletBinding()]
param(
    [string] $Server     = '.\SQLEXPRESS',
    [string] $Database   = 'MMDEV',
    [string] $SchemaFile = '',
    [switch] $Force,
    [switch] $Seed
)

$ErrorActionPreference = 'Stop'

function Invoke-SqlFile {
    param([string] $Path, [string] $Db)

    $name = Split-Path $Path -Leaf
    Write-Host "  -> $name" -ForegroundColor DarkGray

    # -b ให้ sqlcmd คืน exit code ที่ไม่ใช่ 0 เมื่อเจอ error ระดับ 11 ขึ้นไป
    # ถ้าไม่ใส่ สคริปต์จะเดินต่อเงียบ ๆ ทั้งที่ครึ่งไฟล์ล้ม
    $out = & sqlcmd -S $Server -E -C -d $Db -b -i $Path 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "     ล้มที่ $name" -ForegroundColor Red
        $out | Select-String -Pattern '^Msg |^Cannot |^Column ' | Select-Object -First 20 |
            ForEach-Object { Write-Host "     $_" -ForegroundColor Red }
        throw "$name ล้ม — ดู error ด้านบน"
    }
}

if (-not (Get-Command sqlcmd -ErrorAction SilentlyContinue)) {
    throw 'ไม่พบ sqlcmd — ติดตั้ง "SQL Server Command Line Utilities" หรือ SQL Server Management Studio ก่อน'
}

# ไฟล์ DDL ถูกส่งมาหลายชื่อแล้วแต่รอบที่ export ออกจากฐาน (และเอกสารก็เรียกชื่อ
# ไม่ตรงกับที่อยู่บนดิสก์อยู่พักหนึ่ง) จึงรับทุก *_TABLE2_*.sql ในโฟลเดอร์ vendor
# แทนที่จะยึดชื่อเดียว — ถ้าเจอมากกว่าหนึ่งไฟล์ให้เลือกเอง อย่าให้สคริปต์เดา
if (-not $SchemaFile) {
    $found = @(Get-ChildItem "$PSScriptRoot\vendor" -Filter '*TABLE2*.sql' -ErrorAction SilentlyContinue |
               Sort-Object Name -Descending)
    if ($found.Count -eq 1) {
        $SchemaFile = $found[0].FullName
    }
    elseif ($found.Count -gt 1) {
        $SchemaFile = $found[0].FullName
        Write-Host "พบ DDL หลายไฟล์ ใช้ตัวใหม่สุด: $($found[0].Name)" -ForegroundColor Yellow
        Write-Host "  (ระบุเองด้วย -SchemaFile ถ้าต้องการไฟล์อื่น: $($found.Name -join ', '))" -ForegroundColor DarkGray
    }
    else {
        $SchemaFile = "$PSScriptRoot\vendor\PROJECT_TABLE2_R03.sql"   # ให้ข้อความ error ข้างล่างมีชื่อไฟล์ที่คาดหวัง
    }
}

if (-not (Test-Path $SchemaFile)) {
    throw @"
ไม่พบไฟล์ DDL ของฐานจริงที่ $SchemaFile

ไฟล์นี้ไม่ได้อยู่ใน repo โดยตั้งใจ — เป็นโครงสร้างฐาน production ของลูกค้า
ขอจากทีมที่ดูแลฐาน แล้ววางไว้ที่ docs/data-model/vendor/ (โฟลเดอร์นั้น gitignore แล้ว)
หรือชี้ตรง ๆ ด้วย -SchemaFile
"@
}

# ฐานที่มีข้อมูลอยู่ = อาจไม่ใช่ฐานทดสอบ ถามก่อนลบ
$rows = & sqlcmd -S $Server -E -C -h -1 -W -Q @"
SET NOCOUNT ON;
IF DB_ID('$Database') IS NULL SELECT -1
ELSE EXEC('USE [$Database]; SELECT ISNULL(SUM(p.rows), 0) FROM sys.partitions p JOIN sys.tables t ON t.object_id = p.object_id WHERE p.index_id IN (0,1)');
"@ 2>&1 | Select-Object -First 1

if ($rows -match '^\d+$' -and [int]$rows -gt 0 -and -not $Force) {
    Write-Host "ฐาน [$Database] บน $Server มีข้อมูลอยู่ $rows แถว" -ForegroundColor Yellow
    $ans = Read-Host 'สคริปต์นี้จะลบทั้งฐานทิ้ง พิมพ์ชื่อฐานเพื่อยืนยัน'
    if ($ans -ne $Database) { throw 'ยกเลิก — ไม่ได้ยืนยันชื่อฐาน' }
}

Write-Host "สร้าง [$Database] บน $Server ใหม่" -ForegroundColor Cyan
& sqlcmd -S $Server -E -C -b -Q @"
IF DB_ID('$Database') IS NOT NULL
BEGIN
    ALTER DATABASE [$Database] SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE [$Database];
END
CREATE DATABASE [$Database];
"@ | Out-Null
if ($LASTEXITCODE -ne 0) { throw "สร้างฐานไม่สำเร็จ" }

Invoke-SqlFile "$PSScriptRoot\00-user-defined-types.sql" $Database
Invoke-SqlFile $SchemaFile                               $Database
Invoke-SqlFile "$PSScriptRoot\01-new-tables.sql"         $Database
Invoke-SqlFile "$PSScriptRoot\02-alter-existing.sql"     $Database

# ข้อมูลตัวอย่างเป็นทางเลือก ไม่ใช่ค่าเริ่มต้น — ฐานเปล่ากับฐานที่มีข้อมูลตอบ
# คำถามคนละข้อ ("สคริปต์รันผ่านไหม" กับ "จอมีอะไรแสดงไหม") ปนกันแล้วเวลาอะไรพัง
# จะแยกไม่ออกว่าพังเพราะโครงสร้างหรือเพราะข้อมูล
if ($Seed) {
    $seedFile = "$PSScriptRoot\03-seed-demo-data.sql"
    if (Test-Path $seedFile) {
        Invoke-SqlFile $seedFile $Database
    }
    else {
        Write-Host "  ยังไม่มี 03-seed-demo-data.sql — สร้างด้วย" -ForegroundColor Yellow
        Write-Host "    py -3 tests\generate_sql_data.py" -ForegroundColor Yellow
    }
}

Write-Host "`nเสร็จแล้ว" -ForegroundColor Green
& sqlcmd -S $Server -E -C -d $Database -h -1 -W -Q @"
-- ป้ายกำกับตรงนี้เป็นอังกฤษเพราะ console ของ sqlcmd ใช้ codepage เดิมของ Windows
-- ภาษาไทยจะออกมาเป็น ????? ส่วนคอมเมนต์กับข้อความอื่นในสคริปต์ผ่าน Write-Host
-- ซึ่งแสดงไทยได้ปกติ
SET NOCOUNT ON;
SELECT 'tables       ' + CAST(COUNT(*) AS varchar) FROM sys.tables;
SELECT 'primary keys ' + CAST(COUNT(*) AS varchar) FROM sys.key_constraints WHERE type = 'PK';
SELECT 'foreign keys ' + CAST(COUNT(*) AS varchar) FROM sys.foreign_keys;
-- ต้อง join sys.tables ไม่งั้นนับ index ของ system table ติดมาด้วย ซึ่งมีไม่เท่ากัน
-- ในแต่ละรุ่นของ SQL Server แล้วตัวเลขจะเปลี่ยนไปเรื่อยโดยที่ฐานเราไม่ได้ต่างอะไร
SELECT 'indexes      ' + CAST(COUNT(*) AS varchar)
FROM   sys.indexes i JOIN sys.tables t ON t.object_id = i.object_id
WHERE  i.is_primary_key = 0 AND i.type > 0;
SELECT 'tables without a primary key: ' + ISNULL(STRING_AGG(name, ', '), 'none')
FROM   sys.tables t
WHERE  NOT EXISTS (SELECT 1 FROM sys.key_constraints k
                   WHERE k.parent_object_id = t.object_id AND k.type = 'PK');
"@
