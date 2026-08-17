/* =========================================================================
   ROLLBACK 005 — TMS_DOCUMENT_AUDIT
   =========================================================================
   Drops the audit table.

   This one destroys history, which no other rollback here does. The rows are
   the record of who cancelled what and why, and nothing else holds them —
   DOC_SHIPMENT_STATUS_LOG covers shipment status changes only, not plans, not
   reasons, not actors.

   So it refuses if the table has rows unless -Force is passed to the runner,
   which sets @AllowAuditLoss. Rolling a schema back is a technical decision;
   discarding the audit trail is not, and the two should not happen by
   accident because they share a command.

   DOC_SHIPMENT_STATUS_LOG is untouched — 005 never wrote to it.
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

IF OBJECT_ID('dbo.TMS_DOCUMENT_AUDIT', 'U') IS NOT NULL
BEGIN
    DECLARE @rows int = (SELECT COUNT(*) FROM dbo.TMS_DOCUMENT_AUDIT);

    IF @rows > 0 AND ISNULL(CAST(SESSION_CONTEXT(N'AllowAuditLoss') AS bit), 0) = 0
    BEGIN
        PRINT 'TMS_DOCUMENT_AUDIT holds ' + CAST(@rows AS varchar(12)) + ' rows.';
        THROW 50004, 'STOP: rolling back 005 would destroy the audit trail. Re-run with -Force if that is genuinely intended.', 1;
    END

    DROP TABLE dbo.TMS_DOCUMENT_AUDIT;
    PRINT 'rollback 005: dropped dbo.TMS_DOCUMENT_AUDIT (' + CAST(@rows AS varchar(12)) + ' rows discarded).';
END
ELSE
    PRINT 'rollback 005: TMS_DOCUMENT_AUDIT already absent.';
GO

/* Proof that the legacy history was not collateral damage. */
IF OBJECT_ID('dbo.DOC_SHIPMENT_STATUS_LOG', 'U') IS NULL
    THROW 50004, 'rollback 005 verification failed: DOC_SHIPMENT_STATUS_LOG is gone. It must survive this rollback.', 1;
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '005';
GO

COMMIT TRANSACTION;
GO
