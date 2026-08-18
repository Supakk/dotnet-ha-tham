#!/usr/bin/env python3
"""HTTP integration tests for POST /manifests/{id}/invoice.

Run this while the backend is listening on http://localhost:5080 with the MMDEV
connection string configured:

    dotnet run
    py -3 tests/invoice_http_test.py

Everything here goes through real HTTP against real SQL Server. Calling the
service directly would test the service; it would not test the header, the
middleware that binds the warehouse, the status code, or the JSON the client
actually reads — which is where every one of the mistakes this file exists to
catch would live.

WHAT IT DOES TO THE DATABASE
----------------------------
Two things, and it undoes both.

The baseline documents (MN-202608-0039..0043) are what every other test and
screen is written against, so their STATUS and their number never change here.
Invoicing MN-202608-0041 does write INVOICEDAT and INVOICEDBY to it, and the
teardown clears them again along with the audit rows written for them.

The statuses the matrix needs that the baseline does not have in the right
warehouse — a COMPLETED and a CONFIRMED document in WSK — are inserted as
fixtures with keys outside the MN-YYYYMM-NNNN space (MN-TEST-9001, -9002) and
deleted afterwards. Moving a baseline document between warehouses to make a test
pass would be changing the thing under test.

ROWVER on the touched baseline rows does change and cannot be put back: it is
SQL Server's, not ours. It is not part of the baseline anything asserts on.
"""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
from dataclasses import dataclass, field
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

Json = dict[str, Any] | list[Any] | str | int | float | bool | None

# ── ข้อมูลตั้งต้น · the baseline these tests must leave untouched ────────────

BASELINE = {
    ("WSK", "MN-202608-0043"): "DRAFT",
    ("WSK", "MN-202608-0041"): "SENT",
    ("WPD", "MN-202608-0042"): "CONFIRMED",
    ("WPD", "MN-202608-0040"): "COMPLETED",
    ("WWP", "MN-202608-0039"): "ERROR",
}

# Statuses the matrix needs in WSK that the baseline does not have there.
FIXTURES = {
    "MN-TEST-9001": "COMPLETED",
    "MN-TEST-9002": "CONFIRMED",
}

FIXTURE_WAREHOUSE = "WSK"

# sqlcmd connects with QUOTED_IDENTIFIER OFF, and DOC_SHIPMENT_DETAIL and
# DOC_TRANSPORT_PLAN_LINE both carry filtered indexes — SQL Server refuses any
# write to a table with one unless the option is on. The migration scripts set it
# for the same reason; every statement here goes through the same preamble so a
# query and a write cannot behave differently.
PREAMBLE = "SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;"


# ── HTTP ────────────────────────────────────────────────────────────────────


@dataclass
class Response:
    status: int
    body: Json
    headers: dict[str, str] = field(default_factory=dict)


class ApiClient:
    """Standard library only, so this file needs nothing installed to run."""

    def __init__(self, base_url: str, timeout: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.access_token = ""

    def request(
        self,
        method: str,
        path: str,
        body: Json = None,
        *,
        warehouse: str | None = None,
        if_match: str | None = None,
        request_id: str | None = None,
    ) -> Response:
        headers = {"Accept": "application/json"}
        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        if warehouse is not None:
            headers["X-Warehouse-Id"] = warehouse
        if if_match is not None:
            headers["If-Match"] = if_match
        if request_id is not None:
            headers["X-Request-Id"] = request_id

        request = Request(
            f"{self.base_url}{path}", data=data, method=method.upper(), headers=headers
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                return Response(
                    response.status,
                    self._json(response.read()),
                    dict(response.headers.items()),
                )
        except HTTPError as error:
            return Response(error.code, self._json(error.read()), dict(error.headers.items()))
        except URLError as error:
            raise AssertionError(
                f"Cannot reach {self.base_url}. Start the API with 'dotnet run' first. "
                f"({error.reason})"
            ) from error

    @staticmethod
    def _json(raw: bytes) -> Json:
        if not raw:
            return None
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return raw.decode("utf-8", "replace")


# ── SQL ─────────────────────────────────────────────────────────────────────


class Sql:
    """`sqlcmd`, for the same reason generate_sql_data.py uses it.

    Neither pyodbc nor pymssql ships with Python, and requiring a native ODBC
    driver to check two columns would make this file harder to run than the code
    it tests. Assertions are made against the database directly rather than
    against the API's own answer, because "the API says it wrote it" is the claim
    under test.
    """

    def __init__(self, server: str, database: str) -> None:
        self.server = server
        self.database = database

    def rows(self, query: str) -> list[list[str]]:
        result = subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-h", "-1",
             "-f", "65001", "-W", "-s", "|", "-Q", f"{PREAMBLE} {query}"],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {result.stderr or result.stdout}")
        out = []
        for line in result.stdout.splitlines():
            line = line.strip()
            if not line or line.startswith("(") or set(line) <= set("-|"):
                continue
            out.append(line.split("|"))
        return out

    def one(self, query: str) -> list[str] | None:
        rows = self.rows(query)
        return rows[0] if rows else None

    def scalar(self, query: str) -> str:
        row = self.one(query)
        return row[0] if row else ""

    def run(self, statements: str) -> None:
        result = subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-b",
             "-f", "65001", "-Q", f"{PREAMBLE} SET XACT_ABORT ON; {statements}"],
            capture_output=True,
            text=True,
            encoding="utf-8",
        )
        if result.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {result.stderr or result.stdout}")

    # -- the questions these tests ask ---------------------------------------

    def shipment(self, whse: str, key: str) -> dict[str, str]:
        row = self.one(
            "SELECT STATUS, ISNULL(CONVERT(varchar(30), INVOICEDAT, 126), ''), "
            # CONVERT straight off a `timestamp` column answers an empty string rather
            # than failing. Cast to binary(8) first — the value is the same eight
            # bytes, but only this form actually prints them.
            f"ISNULL(INVOICEDBY, ''), CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_SHIPMENT_HDR WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}'"
        )
        if row is None:
            raise AssertionError(f"{whse}/{key} is not in DOC_SHIPMENT_HDR")
        return {"status": row[0], "invoicedAt": row[1], "invoicedBy": row[2], "rowver": row[3]}

    def audits(self, whse: str, key: str) -> list[dict[str, str]]:
        rows = self.rows(
            "SELECT DOCUMENTTYPE, ACTION, ISNULL(FROMSTATUS,''), ISNULL(TOSTATUS,''), "
            "ACTOR, ISNULL(REQUESTID,''), ISNULL(METADATA,'') "
            f"FROM TMS_DOCUMENT_AUDIT WHERE WHSEID = '{whse}' AND DOCUMENTKEY = '{key}' "
            "ORDER BY AUDITID"
        )
        return [
            {"type": r[0], "action": r[1], "from": r[2], "to": r[3],
             "actor": r[4], "requestId": r[5], "metadata": r[6]}
            for r in rows
        ]

    def audit_count(self) -> int:
        return int(self.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT"))


# ── การทดสอบ · the matrix ───────────────────────────────────────────────────


class Suite:
    def __init__(self, api: ApiClient, sql: Sql, email: str) -> None:
        self.api = api
        self.sql = sql
        self.email = email
        self.actor = ""
        self.failures: list[str] = []
        self.passes = 0

    # -- helpers -------------------------------------------------------------

    def get_manifest(self, whse: str, key: str) -> dict[str, Any]:
        response = self.api.request("GET", f"/manifests/{key}", warehouse=whse)
        assert response.status == 200, f"GET {key} in {whse} returned {response.status}"
        assert isinstance(response.body, dict)
        return response.body

    def version_of(self, whse: str, key: str) -> str:
        manifest = self.get_manifest(whse, key)
        version = manifest.get("currentVersion")
        assert isinstance(version, str) and version, f"{key} carries no currentVersion"
        return version

    def invoice(
        self, whse: str, key: str, if_match: str | None, request_id: str | None = None
    ) -> Response:
        return self.api.request(
            "POST", f"/manifests/{key}/invoice",
            warehouse=whse, if_match=if_match, request_id=request_id,
        )

    def check(self, name: str, run: Callable[[], None]) -> None:
        try:
            run()
        except AssertionError as error:
            self.failures.append(f"{name}: {error}")
            print(f"  FAIL  {name}\n        {error}")
        else:
            self.passes += 1
            print(f"  ok    {name}")

    # -- setup / teardown ----------------------------------------------------

    def login(self) -> None:
        response = self.api.request(
            "POST", "/auth/login", {"email": self.email, "password": "test-only"}
        )
        assert response.status == 200 and isinstance(response.body, dict), (
            f"login failed: {response.status} {response.body}"
        )
        token = response.body.get("accessToken")
        assert isinstance(token, str) and token, "login returned no accessToken"
        self.api.access_token = token

        me = self.api.request("GET", "/auth/me")
        assert isinstance(me.body, dict), "/auth/me returned no user"
        # The audit's ACTOR comes from ClaimTypes.Name, which is the user's name.
        self.actor = str(me.body.get("name", ""))
        assert self.actor, "/auth/me returned no name — the audit actor would be blank"

    def create_fixtures(self) -> None:
        values = ",\n".join(
            f"('{FIXTURE_WAREHOUSE}', '{key}', '{status}')" for key, status in FIXTURES.items()
        )
        self.sql.run(
            f"""
            DELETE FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY LIKE 'MN-TEST-%';
            DELETE FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY LIKE 'MN-TEST-%';
            INSERT INTO DOC_SHIPMENT_HDR (WHSEID, SHIPMENTKEY, STATUS, ADDDATE, ADDWHO)
            SELECT v.whse, v.k, v.s, GETDATE(), 'invoice_http_test'
            FROM (VALUES {values}) AS v(whse, k, s);
            """
        )

    def teardown(self) -> None:
        keys = "', '".join(FIXTURES)
        baseline_keys = "', '".join(key for _, key in BASELINE)
        self.sql.run(
            f"""
            DELETE FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY IN ('{keys}');
            DELETE FROM DOC_SHIPMENT_HDR   WHERE SHIPMENTKEY IN ('{keys}');
            DELETE FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY IN ('{baseline_keys}');
            UPDATE DOC_SHIPMENT_HDR SET INVOICEDAT = NULL, INVOICEDBY = NULL
            WHERE SHIPMENTKEY IN ('{baseline_keys}')
              AND (INVOICEDAT IS NOT NULL OR INVOICEDBY IS NOT NULL);
            """
        )

    def verify_baseline(self) -> None:
        for (whse, key), status in BASELINE.items():
            row = self.sql.shipment(whse, key)
            assert row["status"] == status, (
                f"baseline {whse}/{key} is {row['status']}, expected {status}"
            )
            assert row["invoicedAt"] == "", f"baseline {whse}/{key} still holds INVOICEDAT"
            assert row["invoicedBy"] == "", f"baseline {whse}/{key} still holds INVOICEDBY"

        left = self.sql.scalar(
            "SELECT COUNT(*) FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY LIKE 'MN-TEST-%'"
        )
        assert left == "0", f"{left} fixture shipments were left behind"

        counts = {
            r[0]: int(r[1])
            for r in self.sql.rows(
                "SELECT WHSEID, COUNT(*) FROM DOC_SHIPMENT_HDR GROUP BY WHSEID"
            )
        }
        assert counts == {"WSK": 2, "WPD": 2, "WWP": 1}, f"manifest counts moved: {counts}"

    # -- the tests -----------------------------------------------------------

    def test_01_sent_is_invoiced(self) -> None:
        whse, key = "WSK", "MN-202608-0041"
        before = self.sql.shipment(whse, key)
        v1 = self.version_of(whse, key)

        request_id = "invtest01"
        response = self.invoice(whse, key, f'"{v1}"', request_id)
        assert response.status == 200, f"expected 200, got {response.status}: {response.body}"
        assert isinstance(response.body, dict)

        after = self.sql.shipment(whse, key)
        assert after["invoicedAt"] != "", "INVOICEDAT was not written"
        assert after["invoicedBy"] == self.actor, (
            f"INVOICEDBY is {after['invoicedBy']!r}, expected {self.actor!r}"
        )
        assert after["status"] == "SENT", f"STATUS changed to {after['status']}"
        assert after["rowver"] != before["rowver"], "ROWVER did not change"

        assert response.body.get("status") == "sent", (
            f"response says status {response.body.get('status')!r} — invoicing must not change it"
        )
        v2 = response.body.get("currentVersion")
        assert isinstance(v2, str) and v2 != v1, "the response carried the old version"
        assert base64.b64decode(v2).hex().upper() == after["rowver"][2:], (
            f"currentVersion {v2} is not the ROWVER the database holds ({after['rowver']})"
        )

        audits = self.sql.audits(whse, key)
        assert len(audits) == 1, f"expected 1 audit row, found {len(audits)}"
        entry = audits[0]
        assert entry["type"] == "SHIPMENT", f"audit DOCUMENTTYPE is {entry['type']}"
        assert entry["action"] == "INVOICED", f"audit ACTION is {entry['action']}"
        assert entry["from"] == "SENT" and entry["to"] == "SENT", (
            "the audit row does not record that the status was left alone"
        )
        assert entry["actor"] == self.actor, f"audit ACTOR is {entry['actor']!r}"
        assert entry["requestId"] == request_id, (
            f"audit REQUESTID is {entry['requestId']!r}, expected {request_id!r}"
        )

    def test_02_completed_is_invoiced(self) -> None:
        # Fixture, not baseline: the only COMPLETED manifest in the database is
        # MN-202608-0040 and it belongs to WPD. Moving it would be changing the
        # test data to fit the test.
        whse, key = FIXTURE_WAREHOUSE, "MN-TEST-9001"
        v1 = self.version_of(whse, key)
        response = self.invoice(whse, key, f'"{v1}"')
        assert response.status == 200, f"expected 200, got {response.status}: {response.body}"

        after = self.sql.shipment(whse, key)
        assert after["invoicedAt"] != "", "INVOICEDAT was not written"
        assert after["status"] == "COMPLETED", f"STATUS changed to {after['status']}"
        assert len(self.sql.audits(whse, key)) == 1, "no audit row"

    def test_03_draft_is_refused(self) -> None:
        self.refused("WSK", "MN-202608-0043")

    def test_04_confirmed_is_refused(self) -> None:
        self.refused(FIXTURE_WAREHOUSE, "MN-TEST-9002")

    def test_05_error_is_refused(self) -> None:
        self.refused("WWP", "MN-202608-0039")

    def refused(self, whse: str, key: str) -> None:
        before = self.sql.shipment(whse, key)
        v1 = self.version_of(whse, key)
        response = self.invoice(whse, key, f'"{v1}"')

        assert response.status == 409, (
            f"expected 409 for {before['status']}, got {response.status}: {response.body}"
        )
        after = self.sql.shipment(whse, key)
        assert after["invoicedAt"] == "" and after["invoicedBy"] == "", (
            f"{key} was invoiced despite being {before['status']}"
        )
        assert after["status"] == before["status"], "STATUS moved on a refused request"
        assert after["rowver"] == before["rowver"], "the row was written on a refused request"
        assert self.sql.audits(whse, key) == [], "a refusal wrote an audit row"

    def test_06_missing_if_match(self) -> None:
        self.rejected_precondition("WSK", "MN-202608-0041", None)

    def test_07_malformed_if_match(self) -> None:
        self.rejected_precondition("WSK", "MN-202608-0041", '"not-base64!!"')

    def rejected_precondition(self, whse: str, key: str, if_match: str | None) -> None:
        before = self.sql.shipment(whse, key)
        response = self.invoice(whse, key, if_match)

        assert response.status == 400, (
            f"expected 400 for If-Match {if_match!r}, got {response.status}: {response.body}"
        )
        assert isinstance(response.body, dict) and response.body.get("message"), (
            "the refusal carried no message for the user to read"
        )
        after = self.sql.shipment(whse, key)
        assert after["rowver"] == before["rowver"], "the database was written anyway"
        assert after["invoicedAt"] == before["invoicedAt"], "INVOICEDAT changed anyway"

    def test_08_stale_if_match(self) -> None:
        whse, key = "WSK", "MN-202608-0041"
        v1 = self.version_of(whse, key)
        before_rowver = self.sql.shipment(whse, key)["rowver"]

        # Moved by something that is not this API, which is the case If-Match
        # exists for: another process, another instance, a DBA.
        self.sql.run(
            f"UPDATE DOC_SHIPMENT_HDR SET NOTES = ISNULL(NOTES, '') + ' ' "
            f"WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}';"
        )
        moved = self.sql.shipment(whse, key)
        assert moved["rowver"] != before_rowver, "the independent update did not happen"
        audits_before = self.sql.audits(whse, key)

        response = self.invoice(whse, key, f'"{v1}"')
        assert response.status == 409, f"expected 409, got {response.status}: {response.body}"
        assert isinstance(response.body, dict)

        current = response.body.get("currentVersion")
        assert isinstance(current, str) and current, "the 409 did not say what the version is"
        assert current != v1, "the 409 handed back the stale version"
        assert base64.b64decode(current).hex().upper() == moved["rowver"][2:], (
            f"the 409's currentVersion is not the database's ({moved['rowver']})"
        )

        after = self.sql.shipment(whse, key)
        assert after["invoicedAt"] == moved["invoicedAt"], "a stale write went through anyway"
        assert after["invoicedBy"] == moved["invoicedBy"], "a stale write changed INVOICEDBY"
        assert len(self.sql.audits(whse, key)) == len(audits_before), (
            "a stale write left an audit row"
        )

    def test_09_double_submit(self) -> None:
        whse, key = "WSK", "MN-202608-0041"
        v1 = self.version_of(whse, key)
        audits_before = len(self.sql.audits(whse, key))

        first = self.invoice(whse, key, f'"{v1}"')
        assert first.status == 200, f"the first invoice failed: {first.status} {first.body}"
        assert isinstance(first.body, dict)
        v2 = first.body["currentVersion"]

        second = self.invoice(whse, key, f'"{v1}"')
        assert second.status == 409, (
            f"the same version was accepted twice: {second.status} {second.body}"
        )
        assert isinstance(second.body, dict)
        assert second.body.get("currentVersion") == v2, (
            "the 409 did not point at the version the first call produced"
        )
        assert len(self.sql.audits(whse, key)) == audits_before + 1, (
            "the replay wrote an audit row of its own"
        )

    def test_10_cross_warehouse(self) -> None:
        # MN-202608-0040 is WPD's. Asked for under WSK it has to read as absent:
        # a 403 would confirm the number exists somewhere the caller cannot look.
        whse, key = "WPD", "MN-202608-0040"
        before = self.sql.shipment(whse, key)

        response = self.invoice("WSK", key, '"AAAAAAAACAo="')
        assert response.status == 404, f"expected 404, got {response.status}: {response.body}"

        after = self.sql.shipment(whse, key)
        assert after["rowver"] == before["rowver"], "WPD's document was written by a WSK request"
        assert after["invoicedAt"] == "", "WPD's document was invoiced by a WSK request"
        assert self.sql.audits(whse, key) == [], "an audit row was filed against another warehouse"

    def test_11_audit_failure_rolls_back(self) -> None:
        """The audit insert is made to fail, and the shipment must not be invoiced.

        REQUESTID is nvarchar(64) and the middleware preserves whatever the
        caller sent, so an over-long X-Request-Id fails the INSERT and nothing
        else — no schema change, no test-only branch in the production code, and
        the failure lands exactly where a real audit failure would.
        """
        whse, key = FIXTURE_WAREHOUSE, "MN-TEST-9002"
        # Move it to a status invoicing allows, so the refusal under test is the
        # audit failing rather than the policy.
        self.sql.run(
            f"UPDATE DOC_SHIPMENT_HDR SET STATUS = 'SENT' "
            f"WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}';"
        )
        before = self.sql.shipment(whse, key)
        v1 = self.version_of(whse, key)

        response = self.invoice(whse, key, f'"{v1}"', request_id="x" * 200)
        assert response.status == 500, (
            f"the oversized request id did not fail the audit insert: "
            f"{response.status} {response.body}"
        )

        after = self.sql.shipment(whse, key)
        assert after["invoicedAt"] == "", "the shipment was invoiced without an audit row"
        assert after["invoicedBy"] == "", "INVOICEDBY was written without an audit row"
        assert after["rowver"] == before["rowver"], "the UPDATE was committed without the INSERT"
        assert self.sql.audits(whse, key) == [], "a partial audit row survived"

        self.sql.run(
            f"UPDATE DOC_SHIPMENT_HDR SET STATUS = 'CONFIRMED' "
            f"WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}';"
        )

    def test_12_version_round_trip(self) -> None:
        whse, key = FIXTURE_WAREHOUSE, "MN-TEST-9001"
        v_before = self.version_of(whse, key)

        response = self.invoice(whse, key, f'"{v_before}"')
        assert response.status == 200, f"expected 200, got {response.status}: {response.body}"
        assert isinstance(response.body, dict)
        v_after = response.body["currentVersion"]
        assert v_after != v_before, "the response repeated the version it was sent"

        # The loop has to close: what the next GET says is what the next mutation
        # will have to send, and it has to be what this response already gave.
        assert self.version_of(whse, key) == v_after, (
            "a re-read disagrees with the version the mutation returned"
        )

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        print(f"Invoice slice — {self.api.base_url} against {self.sql.database}\n")

        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")
        self.create_fixtures()
        print(f"  ok    fixtures {', '.join(FIXTURES)} created in {FIXTURE_WAREHOUSE}")
        audits_before = self.sql.audit_count()

        print("\nthe matrix")
        tests = [
            ("01 WSK + SENT, valid If-Match", self.test_01_sent_is_invoiced),
            ("02 WSK + COMPLETED (fixture)", self.test_02_completed_is_invoiced),
            ("03 WSK + DRAFT is refused", self.test_03_draft_is_refused),
            ("04 WSK + CONFIRMED is refused (fixture)", self.test_04_confirmed_is_refused),
            ("05 WWP + ERROR is refused", self.test_05_error_is_refused),
            ("06 missing If-Match", self.test_06_missing_if_match),
            ("07 malformed If-Match", self.test_07_malformed_if_match),
            ("08 stale If-Match answers 409 with the current version",
             self.test_08_stale_if_match),
            ("09 double submit is refused", self.test_09_double_submit),
            ("10 cross-warehouse reads as absent", self.test_10_cross_warehouse),
            ("11 a failing audit rolls the invoice back", self.test_11_audit_failure_rolls_back),
            ("12 the version round-trips", self.test_12_version_round_trip),
        ]
        for name, test in tests:
            self.check(name, test)

        print("\nteardown")
        self.teardown()
        self.check("baseline is exactly as it was", self.verify_baseline)
        self.check(
            "no audit rows left behind",
            lambda: self._assert_audits_restored(audits_before),
        )

        print()
        if self.failures:
            print(f"{len(self.failures)} failed, {self.passes} passed")
            for failure in self.failures:
                print(f"  - {failure}")
            return 1

        print(f"All {self.passes} checks passed.")
        return 0

    def _assert_audits_restored(self, before: int) -> None:
        after = self.sql.audit_count()
        assert after == before, f"TMS_DOCUMENT_AUDIT went from {before} rows to {after}"


def main() -> int:
    # The actor names and every refusal message are Thai, and a Windows console
    # defaults to cp1252, which cannot encode them — the run would die on its
    # first print rather than on a failing assertion.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8", errors="replace")

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://localhost:5080")
    parser.add_argument("--server", default="(localdb)\\MSSQLLocalDB")
    parser.add_argument("--database", default="MMDEV")
    parser.add_argument("--email", default="tms@mammod.co")
    parser.add_argument("--timeout", type=float, default=20.0)
    args = parser.parse_args()

    suite = Suite(
        ApiClient(args.base_url, args.timeout),
        Sql(args.server, args.database),
        args.email,
    )
    try:
        return suite.run()
    except AssertionError as error:
        print(f"\nSetup failed: {error}")
        # Leaving fixtures behind would poison the next run and every screen.
        try:
            suite.teardown()
            print("Fixtures removed.")
        except AssertionError as cleanup:
            print(f"Could not clean up: {cleanup}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
