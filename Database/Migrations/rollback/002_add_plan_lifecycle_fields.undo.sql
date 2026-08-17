/* =========================================================================
   ROLLBACK 002 — plan lifecycle fields
   =========================================================================
   Drops the four columns 002 added.

   Same rule as 003: refuses while any of them holds data unless -Force is
   passed, because who issued a plan and when is not recoverable from
   anywhere else. ADDWHO/EDITWHO record who touched the row, not what they
   did to it.

   CANCELREASON is NOT dropped — it came with the original table.
   ========================================================================= */

SET NOCOUNT ON;
SET XACT_ABORT ON;
/* sqlcmd connects with QUOTED_IDENTIFIER OFF, which makes it impossible to
   create a filtered index. Set both explicitly so this file behaves the same
   however it is run - from sqlcmd, from SSMS, or from the runner. */
SET QUOTED_IDENTIFIER ON;
SET ANSI_NULLS ON;
GO

BEGIN TRANSACTION;
GO

IF EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN
           WHERE ISSUEDBY IS NOT NULL OR ISSUEDDATE IS NOT NULL
              OR CANCELLEDBY IS NOT NULL OR CANCELLEDDATE IS NOT NULL)
   AND ISNULL(CAST(SESSION_CONTEXT(N'AllowAuditLoss') AS bit), 0) = 0
    THROW 50004, 'STOP: rolling back 002 would discard plan lifecycle history. Re-run with -Force if intended.', 1;
GO

IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'CANCELLEDDATE') IS NOT NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN DROP COLUMN CANCELLEDDATE;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'CANCELLEDBY') IS NOT NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN DROP COLUMN CANCELLEDBY;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'ISSUEDDATE') IS NOT NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN DROP COLUMN ISSUEDDATE;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'ISSUEDBY') IS NOT NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN DROP COLUMN ISSUEDBY;
GO

IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'CANCELREASON') IS NULL
    THROW 50004, 'rollback 002 verification failed: CANCELREASON was dropped. It predates 002 and must survive.', 1;

PRINT 'rollback 002: 4 columns removed.';
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '002';
GO

COMMIT TRANSACTION;
GO
