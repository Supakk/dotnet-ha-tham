#!/usr/bin/env python3
"""Verification for the global document-number counter.

    py -3 tests/document_number_test.py

The allocator has no HTTP surface of its own — it is a component Create and
Issue call inside their own transaction — so this file verifies the thing that
actually has to be right: the SQL statement, its locking, and its behaviour under
rollback. It runs the same statement DocumentNumberAllocator issues.

WHY THIS IS NOT A UNIT TEST
---------------------------
The property under test is that two callers arriving at the same moment cannot
receive the same number. That is a claim about SQL Server's row locks, and it
cannot be demonstrated against an in-memory double or a single connection — it
needs two real sessions contending for one row. So the concurrency case opens
two connections and measures that the second one blocks.

WHAT IT DOES TO THE DATABASE
----------------------------
The live counters (MN/202608 = 43, PL/202608 = 1) are exercised only inside
transactions that roll back, so their values are never permanently moved. The
concurrency case needs real commits, so it runs against a fixture counter in a
period nobody uses (209912) which is created and deleted by the run. The prefix
stays MN because CK_TMS_DOCUMENT_NUMBER_PREFIX allows only MN and PL.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
import time
from typing import Callable

PREAMBLE = "SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;"

# Exactly the statement DocumentNumberAllocator sends, with the parameters
# inlined for sqlcmd. If these two drift apart this file stops being evidence.
ALLOCATE = """
UPDATE dbo.TMS_DOCUMENT_NUMBER
SET    LASTNUMBER = LASTNUMBER + 1,
       EDITDATE   = GETDATE(),
       EDITWHO    = '{who}'
OUTPUT INSERTED.LASTNUMBER AS Value
WHERE  PREFIX = '{prefix}'
  AND  PERIOD = '{period}'
"""

FIXTURE_PERIOD = "209912"


class Sql:
    def __init__(self, server: str, database: str) -> None:
        self.server = server
        self.database = database

    def _run(self, batch: str, timeout: float | None = None) -> subprocess.CompletedProcess:
        return subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-h", "-1",
             "-f", "65001", "-W", "-s", "|", "-Q", f"{PREAMBLE} {batch}"],
            capture_output=True, text=True, encoding="utf-8", timeout=timeout,
        )

    def rows(self, batch: str) -> list[str]:
        result = self._run(batch)
        if result.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {result.stderr or result.stdout}")
        return [l.strip() for l in result.stdout.splitlines()
                if l.strip() and not l.strip().startswith("(")]

    def scalar(self, batch: str) -> str:
        rows = self.rows(batch)
        return rows[0] if rows else ""

    def exec(self, batch: str) -> None:
        result = subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-b",
             "-f", "65001", "-Q", f"{PREAMBLE} SET XACT_ABORT ON; {batch}"],
            capture_output=True, text=True, encoding="utf-8",
        )
        if result.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {result.stderr or result.stdout}")

    def spawn(self, batch: str) -> subprocess.Popen:
        return subprocess.Popen(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-h", "-1",
             "-f", "65001", "-W", "-s", "|", "-Q", f"{PREAMBLE} {batch}"],
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True, encoding="utf-8",
        )

    def last_number(self, prefix: str, period: str) -> str:
        return self.scalar(
            f"SELECT LASTNUMBER FROM dbo.TMS_DOCUMENT_NUMBER "
            f"WHERE PREFIX = '{prefix}' AND PERIOD = '{period}'"
        )


def allocate(who: str = "document_number_test", prefix: str = "MN",
             period: str = "202608") -> str:
    return ALLOCATE.format(who=who, prefix=prefix, period=period)


class Suite:
    def __init__(self, sql: Sql) -> None:
        self.sql = sql
        self.failures: list[str] = []
        self.passes = 0

    def check(self, name: str, run: Callable[[], None]) -> None:
        try:
            run()
        except AssertionError as error:
            self.failures.append(f"{name}: {error}")
            print(f"  FAIL  {name}\n        {error}")
        else:
            self.passes += 1
            print(f"  ok    {name}")

    # -- 01/02 · the live MN counter, inside a transaction that rolls back ----

    def test_01_02_sequential(self) -> None:
        out = self.sql.rows(
            f"BEGIN TRANSACTION; {allocate()} {allocate()} ROLLBACK TRANSACTION;"
        )
        assert out == ["44", "45"], f"expected 44 then 45, got {out}"

    def test_03_plan_counter(self) -> None:
        out = self.sql.rows(
            f"BEGIN TRANSACTION; {allocate(prefix='PL')} ROLLBACK TRANSACTION;"
        )
        assert out == ["2"], f"expected PL to go 1 -> 2, got {out}"

    def test_04_missing_counter(self) -> None:
        # A period nobody has opened a counter for. The statement must match no
        # row and return nothing, which is what the allocator turns into a
        # readable refusal rather than a number.
        out = self.sql.rows(
            f"BEGIN TRANSACTION; {allocate(period='209911')} ROLLBACK TRANSACTION;"
        )
        assert out == [], f"a counter that does not exist returned {out}"

    def test_06_rollback_restores(self) -> None:
        before = self.sql.last_number("MN", "202608")
        self.sql.rows(f"BEGIN TRANSACTION; {allocate()} ROLLBACK TRANSACTION;")
        after = self.sql.last_number("MN", "202608")
        assert after == before, f"rollback left the counter at {after}, was {before}"

    # -- 05 · two real sessions contending for one row -----------------------

    def test_05_concurrent_allocation(self) -> None:
        """The second caller must block on the first one's lock, not read past it.

        Session A takes the number and holds its transaction open for three
        seconds. Session B asks for a number one second in. If the lock works, B
        cannot answer until A commits, so B waits and then gets the next value.
        If it did not, B would return immediately with the same number.
        """
        period = FIXTURE_PERIOD
        self.sql.exec(
            f"DELETE FROM dbo.TMS_DOCUMENT_NUMBER WHERE PERIOD = '{period}'; "
            f"INSERT INTO dbo.TMS_DOCUMENT_NUMBER (PREFIX, PERIOD, LASTNUMBER, EDITWHO) "
            f"VALUES ('MN', '{period}', 100, 'document_number_test');"
        )

        a = self.sql.spawn(
            f"BEGIN TRANSACTION; {allocate(period=period)} "
            f"WAITFOR DELAY '00:00:03'; COMMIT TRANSACTION;"
        )
        time.sleep(1.0)

        started = time.monotonic()
        b = self.sql.spawn(allocate(who="second_caller", period=period))
        b_out, _ = b.communicate(timeout=40)
        b_waited = time.monotonic() - started

        a_out, _ = a.communicate(timeout=40)

        first = [l.strip() for l in a_out.splitlines()
                 if l.strip() and not l.strip().startswith("(")]
        second = [l.strip() for l in b_out.splitlines()
                  if l.strip() and not l.strip().startswith("(")]

        assert first == ["101"], f"the first caller got {first}, expected 101"
        assert second == ["102"], (
            f"the second caller got {second}, expected 102 — "
            "two callers were handed the same number"
        )
        assert b_waited > 1.0, (
            f"the second caller answered in {b_waited:.2f}s without waiting for "
            "the first transaction — the row lock did not serialise them"
        )
        assert self.sql.last_number("MN", period) == "102", "the counter did not settle at 102"

    # -- run -----------------------------------------------------------------

    def teardown(self) -> None:
        self.sql.exec(
            f"DELETE FROM dbo.TMS_DOCUMENT_NUMBER WHERE PERIOD = '{FIXTURE_PERIOD}';"
        )

    def verify_baseline(self) -> None:
        mn = self.sql.last_number("MN", "202608")
        pl = self.sql.last_number("PL", "202608")
        assert mn == "43", f"MN/202608 is {mn}, baseline is 43"
        assert pl == "1", f"PL/202608 is {pl}, baseline is 1"
        left = self.sql.scalar(
            "SELECT COUNT(*) FROM dbo.TMS_DOCUMENT_NUMBER WHERE PERIOD LIKE '2099%'"
        )
        assert left == "0", f"{left} fixture counter row(s) left behind"

    def run(self) -> int:
        print(f"Document number allocator — {self.sql.database}\n")
        tests = [
            ("01/02 MN counter goes 43 -> 44 -> 45", self.test_01_02_sequential),
            ("03 PL counter goes 1 -> 2", self.test_03_plan_counter),
            ("04 a counter that does not exist yields no number", self.test_04_missing_counter),
            ("05 concurrent callers are serialised, never duplicated",
             self.test_05_concurrent_allocation),
            ("06 rollback puts the number back", self.test_06_rollback_restores),
        ]
        for name, test in tests:
            self.check(name, test)

        print("\nteardown")
        self.teardown()
        self.check("baseline counters unchanged", self.verify_baseline)

        print()
        if self.failures:
            print(f"{len(self.failures)} failed, {self.passes} passed")
            for failure in self.failures:
                print(f"  - {failure}")
            return 1
        print(f"All {self.passes} checks passed.")
        return 0


def main() -> int:
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--server", default="(localdb)\\MSSQLLocalDB")
    parser.add_argument("--database", default="MMDEV")
    args = parser.parse_args()

    suite = Suite(Sql(args.server, args.database))
    try:
        return suite.run()
    except AssertionError as error:
        print(f"\nSetup failed: {error}")
        try:
            suite.teardown()
            print("Fixture counter removed.")
        except AssertionError as cleanup:
            print(f"Could not clean up: {cleanup}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
