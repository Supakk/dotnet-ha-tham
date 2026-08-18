using Mammod.Data;
using Microsoft.EntityFrameworkCore;

namespace Mammod.Database.Documents;

/// <summary>
/// Hands out the next MN-YYYYMM-NNNN or PL-YYYYMM-NNNN.
///
/// One statement, and the choice of statement is the whole design:
///
/// <code>
/// UPDATE dbo.TMS_DOCUMENT_NUMBER
/// SET    LASTNUMBER = LASTNUMBER + 1
/// OUTPUT INSERTED.LASTNUMBER
/// WHERE  PREFIX = @prefix AND PERIOD = @period
/// </code>
///
/// The UPDATE takes an exclusive lock on the counter row and holds it until the
/// caller's transaction ends. A second caller arriving mid-flight blocks on that
/// lock rather than reading the same value, so two concurrent requests get 44 and
/// 45 and never 44 twice. <c>OUTPUT</c> returns the incremented value in the same
/// round trip, so there is no window between deciding the number and taking it.
///
/// This is the strategy migration 006 prescribes, and it exists specifically to
/// replace the obvious alternative: <c>SELECT MAX(...) + 1</c>, or a read
/// followed by a write, both of which hand two simultaneous callers the same
/// number. Neither appears here and neither should be reintroduced.
///
/// <b>No transaction of its own.</b> It runs on the caller's connection and joins
/// whatever transaction the caller has open. That is not an implementation detail
/// — it is the contract. A number consumed inside a Create that then rolls back
/// must roll back with it, and an allocator that committed privately would burn a
/// number every time a document failed to be created.
///
/// <b>Global, not per warehouse.</b> There is no WHSEID here because there is
/// none on the table; see <see cref="DocumentNumberRow"/>.
/// </summary>
public sealed class DocumentNumberAllocator(
    AppDbContext db, IActorContext actor) : IDocumentNumberAllocator
{
    /// <summary>NNNN — the width the existing numbers are written to.</summary>
    private const int SequenceWidth = 4;

    public async Task<string> AllocateAsync(
        string prefix, DateOnly on, CancellationToken ct = default)
    {
        var key = (prefix ?? "").Trim().ToUpperInvariant();
        if (key.Length == 0)
            throw new DomainException("ต้องระบุ prefix ของเลขเอกสาร (MN หรือ PL)");

        var period = on.ToString("yyyyMM");

        // Parameterised through SqlQueryRaw's positional placeholders, not
        // interpolated: the values reach SQL Server as parameters.
        //
        // The column alias must be `Value` — that is the name EF Core binds a
        // scalar SqlQueryRaw result from.
        var allocated = await db.Database
            .SqlQueryRaw<int>(
                """
                UPDATE dbo.TMS_DOCUMENT_NUMBER
                SET    LASTNUMBER = LASTNUMBER + 1,
                       EDITDATE   = GETDATE(),
                       EDITWHO    = {2}
                OUTPUT INSERTED.LASTNUMBER AS Value
                WHERE  PREFIX = {0}
                  AND  PERIOD = {1}
                """,
                key, period, Actor())
            .ToListAsync(ct);

        // No row matched. The counter is seeded per (prefix, period) by migration
        // 006 from the documents that already existed, so this means either a
        // prefix that is not MN or PL, or a period nobody has opened a counter
        // for. Deliberately NOT auto-created here: inventing a counter row would
        // start a second series at 1 alongside whatever numbers already exist,
        // and the only safe starting value is one somebody has decided on.
        if (allocated.Count == 0)
        {
            throw new DomainException(
                $"ยังไม่มีตัวนับเลขเอกสารของ {key}-{period} — " +
                "ต้องเปิดแถวใน TMS_DOCUMENT_NUMBER ก่อนจึงจะออกเลขงวดนี้ได้");
        }

        // More than one row cannot happen: (PREFIX, PERIOD) is the primary key.
        // Checked anyway, because a duplicate would mean two numbers were taken
        // and only one returned, and a silently burnt number is the kind of
        // thing that is discovered a month later from a gap in the paperwork.
        if (allocated.Count > 1)
        {
            throw new InvalidOperationException(
                $"ตัวนับเลขเอกสาร {key}-{period} คืนค่ามามากกว่าหนึ่งแถว — " +
                "PK_TMS_DOCUMENT_NUMBER น่าจะหายไป");
        }

        return $"{key}-{period}-{allocated[0].ToString($"D{SequenceWidth}")}";
    }

    /// <summary>
    /// Stamped into EDITWHO so the counter says who last took from it. Falls back
    /// rather than throwing: failing an allocation over a blank audit column
    /// would refuse a document for a reason nobody could act on.
    /// </summary>
    private string Actor() =>
        string.IsNullOrWhiteSpace(actor.CurrentUser) ? "api" : actor.CurrentUser;
}
