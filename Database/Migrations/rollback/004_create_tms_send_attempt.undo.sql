/* =========================================================================
   ROLLBACK 004 — TMS_SHIPMENT_SEND_ATTEMPT
   =========================================================================
   Drops the send-attempt table, and with it the record of every hand-off to
   MMX: which attempts were acknowledged, which timed out, which idempotency
   keys have been used.

   That last one matters more than it looks. If an attempt is outstanding —
   requested or acknowledged but not settled — MMX may still be holding work
   that this database no longer knows it sent. Dropping the table means the
   next send starts from attempt 1 with a fresh key, and MMX has no way to
   recognise it as the same document. That is how one load goes out twice.

   So it refuses while any attempt is unsettled, whatever -Force says: a
   duplicate delivery is not a recoverable mistake. Settled history can be
   discarded with -Force.
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

IF OBJECT_ID('dbo.TMS_SHIPMENT_SEND_ATTEMPT', 'U') IS NOT NULL
BEGIN
    DECLARE @outstanding int = (
        SELECT COUNT(*) FROM dbo.TMS_SHIPMENT_SEND_ATTEMPT
        WHERE STATUS IN ('SEND_REQUESTED', 'SENDING', 'ACKED', 'TIMEOUT'));

    IF @outstanding > 0
    BEGIN
        SELECT SHIPMENTKEY, ATTEMPTNO, STATUS, REQUESTEDAT
        FROM dbo.TMS_SHIPMENT_SEND_ATTEMPT
        WHERE STATUS IN ('SEND_REQUESTED', 'SENDING', 'ACKED', 'TIMEOUT')
        ORDER BY REQUESTEDAT;

        THROW 50004, 'STOP: send attempts are still outstanding. Dropping them would lose the idempotency keys MMX has already seen, and the next send could duplicate a load that is already out. Settle or reconcile these first — this refusal is not overridable.', 1;
    END

    DECLARE @rows int = (SELECT COUNT(*) FROM dbo.TMS_SHIPMENT_SEND_ATTEMPT);

    IF @rows > 0 AND ISNULL(CAST(SESSION_CONTEXT(N'AllowAuditLoss') AS bit), 0) = 0
    BEGIN
        PRINT 'TMS_SHIPMENT_SEND_ATTEMPT holds ' + CAST(@rows AS varchar(12)) + ' settled attempts.';
        THROW 50004, 'STOP: rolling back 004 would discard the integration history. Re-run with -Force if intended.', 1;
    END

    DROP TABLE dbo.TMS_SHIPMENT_SEND_ATTEMPT;
    PRINT 'rollback 004: dropped dbo.TMS_SHIPMENT_SEND_ATTEMPT (' + CAST(@rows AS varchar(12)) + ' rows discarded).';
END
ELSE
    PRINT 'rollback 004: TMS_SHIPMENT_SEND_ATTEMPT already absent.';
GO

DELETE FROM dbo.TMS_SCHEMA_MIGRATION WHERE VERSION = '004';
GO

COMMIT TRANSACTION;
GO
