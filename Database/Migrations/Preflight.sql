/* =========================================================================
   PREFLIGHT — run before any migration, changes nothing
   =========================================================================
   Answers the questions that decide whether 000–007 can be applied safely.
   Read-only throughout: no INSERT, UPDATE, DELETE or DDL anywhere in this
   file.

   Every SAFETY line must read PASS. A FAIL is a data question, not a schema
   one, and the migration that depends on it will refuse to run anyway.

       sqlcmd -S "(localdb)\MSSQLLocalDB" -d MMDEV -i Preflight.sql
   ========================================================================= */

SET NOCOUNT ON;

PRINT '===== ENVIRONMENT =====';
SELECT [Database] = DB_NAME(),
       [Server]   = @@SERVERNAME,
       [Edition]  = CAST(SERVERPROPERTY('Edition') AS varchar(80)),
       [Version]  = CAST(SERVERPROPERTY('ProductVersion') AS varchar(20)),
       [Collation]= CAST(DATABASEPROPERTYEX(DB_NAME(), 'Collation') AS varchar(80));

PRINT '===== MIGRATION STATE =====';
IF OBJECT_ID('dbo.TMS_SCHEMA_MIGRATION', 'U') IS NULL
    SELECT [State] = 'no tracking table — migration 000 has not run';
ELSE
    SELECT VERSION, NAME, APPLIEDAT, APPLIEDBY, DURATIONMS
    FROM dbo.TMS_SCHEMA_MIGRATION ORDER BY VERSION;

PRINT '===== DOCUMENTS BY WAREHOUSE =====';
SELECT [Warehouse] = w.WHSEID COLLATE DATABASE_DEFAULT,
       [Plans]     = (SELECT COUNT(*) FROM dbo.DOC_TRANSPORT_PLAN p WHERE p.WHSEID = w.WHSEID COLLATE DATABASE_DEFAULT),
       [Shipments] = (SELECT COUNT(*) FROM dbo.DOC_SHIPMENT_HDR s WHERE s.WHSEID = w.WHSEID COLLATE DATABASE_DEFAULT),
       [Orders]    = (SELECT COUNT(*) FROM dbo.DOC_DO_HDR o WHERE o.WHSEID = w.WHSEID COLLATE DATABASE_DEFAULT)
FROM dbo.MST_WHSE w
ORDER BY w.WHSEID;

PRINT '===== PENDING POOL BY WAREHOUSE =====';
/* The same NOT EXISTS the application uses. Counted per warehouse because
   that is how it is ever queried — an API request is scoped to one. */
SELECT [Warehouse] = o.WHSEID, [Available] = COUNT(*)
FROM dbo.DOC_DO_HDR o
WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_SHIPMENT_DETAIL d
                  WHERE d.WHSEID = o.WHSEID AND d.ORDERKEY = o.ORDERKEY AND d.STATUS <> 'CANCELLED')
  AND NOT EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN_LINE l
                  WHERE l.WHSEID = o.WHSEID AND l.ORDERKEY = o.ORDERKEY AND l.STATUS <> 'CANCELLED')
GROUP BY o.WHSEID
ORDER BY o.WHSEID;

PRINT '===== STATUS VALUES IN USE =====';
SELECT [Table] = 'DOC_SHIPMENT_HDR', STATUS, [Rows] = COUNT(*) FROM dbo.DOC_SHIPMENT_HDR GROUP BY STATUS
UNION ALL
SELECT 'DOC_TRANSPORT_PLAN', STATUS, COUNT(*) FROM dbo.DOC_TRANSPORT_PLAN GROUP BY STATUS
UNION ALL
SELECT 'DOC_SHIPMENT_DETAIL', STATUS, COUNT(*) FROM dbo.DOC_SHIPMENT_DETAIL GROUP BY STATUS
UNION ALL
SELECT 'DOC_SHIPMENT_STOP', STATUS, COUNT(*) FROM dbo.DOC_SHIPMENT_STOP GROUP BY STATUS
ORDER BY 1, 2;

PRINT '===== DOCUMENT NUMBERS =====';
SELECT [Prefix] = 'MN', [Period] = SUBSTRING(SHIPMENTKEY, 4, 6),
       [HighestUsed] = MAX(CAST(RIGHT(SHIPMENTKEY, 4) AS int)), [Documents] = COUNT(*)
FROM dbo.DOC_SHIPMENT_HDR
WHERE SHIPMENTKEY LIKE 'MN-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
GROUP BY SUBSTRING(SHIPMENTKEY, 4, 6)
UNION ALL
SELECT 'PL', SUBSTRING(PLANKEY, 4, 6), MAX(CAST(RIGHT(PLANKEY, 4) AS int)), COUNT(*)
FROM dbo.DOC_TRANSPORT_PLAN
WHERE PLANKEY LIKE 'PL-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
GROUP BY SUBSTRING(PLANKEY, 4, 6);

PRINT '===== SAFETY CHECKS — every line must read PASS =====';

SELECT [Check] = '001 duplicate (WHSEID, ORDERKEY)',
       [Found] = COUNT(*),
       [Result] = IIF(COUNT(*) = 0, 'PASS', 'FAIL — 001 will refuse')
FROM (SELECT WHSEID, ORDERKEY FROM dbo.DOC_DO_HDR GROUP BY WHSEID, ORDERKEY HAVING COUNT(*) > 1) d
UNION ALL
SELECT '001 orphan shipment detail', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — 001 will refuse')
FROM dbo.DOC_SHIPMENT_DETAIL d
WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o WHERE o.WHSEID = d.WHSEID AND o.ORDERKEY = d.ORDERKEY)
UNION ALL
SELECT '001 orphan plan line', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — 001 will refuse')
FROM dbo.DOC_TRANSPORT_PLAN_LINE l
WHERE NOT EXISTS (SELECT 1 FROM dbo.DOC_DO_HDR o WHERE o.WHSEID = l.WHSEID AND o.ORDERKEY = l.ORDERKEY)
UNION ALL
SELECT '007 duplicate SHIPMENTKEY across warehouses', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — 007 will refuse')
FROM (SELECT SHIPMENTKEY FROM dbo.DOC_SHIPMENT_HDR GROUP BY SHIPMENTKEY HAVING COUNT(*) > 1) s
UNION ALL
SELECT '007 duplicate PLANKEY across warehouses', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — 007 will refuse')
FROM (SELECT PLANKEY FROM dbo.DOC_TRANSPORT_PLAN GROUP BY PLANKEY HAVING COUNT(*) > 1) p
UNION ALL
SELECT '007 shipment status outside the target set', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — 007 will refuse')
FROM dbo.DOC_SHIPMENT_HDR
WHERE STATUS NOT IN ('DRAFT','CONFIRMED','SENT','ERROR','COMPLETED','CANCELLED','DELETED')
UNION ALL
SELECT '006 document number format', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'WARN — these will not seed a counter')
FROM dbo.DOC_SHIPMENT_HDR
WHERE SHIPMENTKEY NOT LIKE 'MN-[0-9][0-9][0-9][0-9][0-9][0-9]-[0-9][0-9][0-9][0-9]'
UNION ALL
SELECT 'name clashes for objects these migrations create', COUNT(*), IIF(COUNT(*) = 0, 'PASS', 'FAIL — inspect the existing object')
FROM (
    SELECT name FROM sys.objects
    WHERE name IN ('TMS_SCHEMA_MIGRATION','TMS_SHIPMENT_SEND_ATTEMPT','TMS_DOCUMENT_AUDIT','TMS_DOCUMENT_NUMBER',
                   'FK_DOC_SHIPMENT_DETAIL_DO','FK_DOC_TRANSPORT_PLAN_LINE_DO',
                   'CK_SHIPMENT_HDR_STATUS','CK_SHIPMENT_HDR_RELATIONTYPE')
    UNION ALL
    SELECT name FROM sys.indexes
    WHERE name IN ('UQ_DOC_DO_HDR_ORDER','UQ_DOC_SHIPMENT_HDR_KEY','UQ_DOC_TRANSPORT_PLAN_KEY')
) c;

PRINT '===== END PREFLIGHT — nothing was modified =====';
