/* =========================================================================
   002 — who issued or cancelled a plan, and when
   =========================================================================
   DOC_TRANSPORT_PLAN records ADDWHO/ADDDATE and EDITWHO/EDITDATE, which say
   who touched the row last but not what they did to it. A plan has two
   transitions worth naming — it was issued, or it was cancelled — and neither
   is recoverable from an edit timestamp.

   CANCELREASON already exists; the who and the when did not.

   All four columns are nullable and stay NULL for existing rows. The one plan
   in the database is DRAFT, so it has neither been issued nor cancelled and
   there is nothing to backfill. Where history has no answer, a NULL is the
   honest one — inventing an actor would put a name against an action nobody
   took.
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

/* --- preflight ---------------------------------------------------------- */

IF OBJECT_ID('dbo.DOC_TRANSPORT_PLAN', 'U') IS NULL
    THROW 50000, 'STOP: DOC_TRANSPORT_PLAN does not exist.', 1;

/* A column of the right name but the wrong type would be someone else's, and
   writing our values into it is not this migration's business. */
DECLARE @wrongType nvarchar(400) = (
    SELECT STRING_AGG(c.name + ' is ' + t.name, ', ')
    FROM sys.columns c
    JOIN sys.types t ON t.user_type_id = c.user_type_id
    WHERE c.object_id = OBJECT_ID('dbo.DOC_TRANSPORT_PLAN')
      AND ((c.name IN ('ISSUEDBY', 'CANCELLEDBY') AND t.name <> 'nvarchar')
        OR (c.name IN ('ISSUEDDATE', 'CANCELLEDDATE') AND t.name NOT IN ('datetime', 'datetime2')))
);

IF @wrongType IS NOT NULL
    THROW 50002, 'STOP: a lifecycle column already exists on DOC_TRANSPORT_PLAN with an unexpected type. Inspect before continuing.', 1;
GO

/* --- apply -------------------------------------------------------------- */

IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'ISSUEDBY') IS NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN ADD ISSUEDBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'ISSUEDDATE') IS NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN ADD ISSUEDDATE datetime NULL;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'CANCELLEDBY') IS NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN ADD CANCELLEDBY nvarchar(100) NULL;
GO
IF COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', 'CANCELLEDDATE') IS NULL
    ALTER TABLE dbo.DOC_TRANSPORT_PLAN ADD CANCELLEDDATE datetime NULL;
GO

/* --- verify ------------------------------------------------------------- */

DECLARE @missing nvarchar(400) = (
    SELECT STRING_AGG(needed.col, ', ')
    FROM (VALUES ('ISSUEDBY'), ('ISSUEDDATE'), ('CANCELLEDBY'), ('CANCELLEDDATE')) AS needed(col)
    WHERE COL_LENGTH('dbo.DOC_TRANSPORT_PLAN', needed.col) IS NULL
);

IF @missing IS NOT NULL
    THROW 50003, '002 verification failed: columns missing after apply.', 1;

/* Nothing was rewritten: every existing plan should still be untouched. */
IF EXISTS (SELECT 1 FROM dbo.DOC_TRANSPORT_PLAN
           WHERE ISSUEDBY IS NOT NULL OR ISSUEDDATE IS NOT NULL
              OR CANCELLEDBY IS NOT NULL OR CANCELLEDDATE IS NOT NULL)
    THROW 50003, '002 verification failed: a new lifecycle column already holds data. This migration backfills nothing.', 1;

PRINT '002: verified — 4 columns added, no data written.';
GO

COMMIT TRANSACTION;
GO
