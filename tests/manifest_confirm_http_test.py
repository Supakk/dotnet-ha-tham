#!/usr/bin/env python3
"""HTTP integration tests for POST /manifests/{id}/confirm.

    dotnet run
    py -3 tests/manifest_confirm_http_test.py

Confirm is a pure header transition: DRAFT -> CONFIRMED, plus who confirmed it
and when. Stops, orders and lines are untouched, and this file checks that they
are rather than assuming it.

WHERE THE RECORD GOES
---------------------
A shipment status change is recorded in DOC_SHIPMENT_STATUS_LOG, not in
TMS_DOCUMENT_AUDIT. That is the split the schema already draws and the fourteen
existing rows already follow — two of them are this exact transition, written as
DRAFT -> CONFIRMED with SOURCESYSTEM 'TMS'. So the assertions below look for a
status-log row and for the audit table to stay empty.

WHAT IT DOES TO THE DATABASE
----------------------------
Confirming is a commit, so the happy path runs against fixtures this file
creates and deletes (MN-TEST-8xxx), never against a baseline manifest.

The one baseline document it touches is read-only: MN-202608-0043 is WSK's draft
and has a driver and a run but no plate, so it fails the assignment gate. That
makes it the honest subject for the "not assigned yet" case — no fixture needed
and nothing written.
"""

from __future__ import annotations

import argparse
import base64
import json
import subprocess
import sys
from dataclasses import dataclass
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

PREAMBLE = "SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;"

BASELINE_DRAFT = "MN-202608-0043"      # WSK, DRAFT, unassigned (no plate)
BASELINE_SENT = "MN-202608-0041"       # WSK, SENT
BASELINE_OTHER_WHSE = "MN-202608-0042"  # WPD, CONFIRMED

# Fixtures: assigned drafts, in the MN-TEST space so they cannot be mistaken for
# real documents and are removable by prefix.
FIXTURES = {
    "MN-TEST-8001": "WSK",
    "MN-TEST-8002": "WSK",
    "MN-TEST-8003": "WSK",
    "MN-TEST-8004": "WSK",
    "MN-TEST-8005": "WSK",
    "MN-TEST-8006": "WPD",
}


@dataclass
class Response:
    status: int
    body: Any


class ApiClient:
    def __init__(self, base_url: str, timeout: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout
        self.access_token = ""

    def request(self, method: str, path: str, body: Any = None, *,
                warehouse: str | None = None, if_match: str | None = None,
                request_id: str | None = None) -> Response:
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

        req = Request(f"{self.base_url}{path}", data=data, method=method.upper(), headers=headers)
        try:
            with urlopen(req, timeout=self.timeout) as r:
                return Response(r.status, self._json(r.read()))
        except HTTPError as e:
            return Response(e.code, self._json(e.read()))
        except URLError as e:
            raise AssertionError(
                f"Cannot reach {self.base_url}. Start the API with 'dotnet run' first. ({e.reason})"
            ) from e

    @staticmethod
    def _json(raw: bytes) -> Any:
        if not raw:
            return None
        try:
            return json.loads(raw.decode("utf-8"))
        except (UnicodeDecodeError, json.JSONDecodeError):
            return raw.decode("utf-8", "replace")


class Sql:
    def __init__(self, server: str, database: str) -> None:
        self.server, self.database = server, database

    def rows(self, query: str) -> list[list[str]]:
        r = subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-h", "-1",
             "-f", "65001", "-W", "-s", "|", "-Q", f"{PREAMBLE} {query}"],
            capture_output=True, text=True, encoding="utf-8")
        if r.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {r.stderr or r.stdout}")
        out = []
        for line in r.stdout.splitlines():
            line = line.strip()
            if not line or line.startswith("(") or set(line) <= set("-|"):
                continue
            out.append(line.split("|"))
        return out

    def scalar(self, query: str) -> str:
        rows = self.rows(query)
        return rows[0][0] if rows else ""

    def exec(self, batch: str) -> None:
        r = subprocess.run(
            ["sqlcmd", "-S", self.server, "-d", self.database, "-E", "-b", "-f", "65001",
             "-Q", f"{PREAMBLE} SET XACT_ABORT ON; {batch}"],
            capture_output=True, text=True, encoding="utf-8")
        if r.returncode != 0:
            raise AssertionError(f"sqlcmd failed: {r.stderr or r.stdout}")

    def shipment(self, key: str) -> dict[str, str]:
        rows = self.rows(
            "SELECT WHSEID, STATUS, ISNULL(CONVERT(varchar(19), CONFIRMDATE, 120), ''), "
            "ISNULL(CONFIRMBY, ''), CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY = '{key}'")
        if not rows:
            raise AssertionError(f"{key} is not in DOC_SHIPMENT_HDR")
        r = rows[0]
        return {"whse": r[0], "status": r[1], "confirmDate": r[2],
                "confirmBy": r[3], "rowver": r[4]}

    def status_log(self, key: str) -> list[dict[str, str]]:
        return [
            {"frm": r[0], "to": r[1], "source": r[2], "who": r[3], "whse": r[4]}
            for r in self.rows(
                "SELECT ISNULL(FROMSTATUS,''), ISNULL(TOSTATUS,''), ISNULL(SOURCESYSTEM,''), "
                "ISNULL(CHANGEWHO,''), WHSEID FROM DOC_SHIPMENT_STATUS_LOG "
                f"WHERE SHIPMENTKEY = '{key}' ORDER BY SERIALKEY")
        ]


class Suite:
    def __init__(self, api: ApiClient, sql: Sql, email: str) -> None:
        self.api, self.sql, self.email = api, sql, email
        self.actor = ""
        self.failures: list[str] = []
        self.passes = 0

    # -- helpers -------------------------------------------------------------

    def version_of(self, whse: str, key: str) -> str:
        r = self.api.request("GET", f"/manifests/{key}", warehouse=whse)
        assert r.status == 200, f"GET {key} in {whse} returned {r.status}"
        v = r.body.get("currentVersion")
        assert isinstance(v, str) and v, f"{key} carries no currentVersion"
        return v

    def confirm(self, whse: str, key: str, if_match: str | None,
                request_id: str | None = None) -> Response:
        return self.api.request("POST", f"/manifests/{key}/confirm",
                                warehouse=whse, if_match=if_match, request_id=request_id)

    def check(self, name: str, run: Callable[[], None]) -> None:
        try:
            run()
        except AssertionError as e:
            self.failures.append(f"{name}: {e}")
            print(f"  FAIL  {name}\n        {e}")
        else:
            self.passes += 1
            print(f"  ok    {name}")

    def login(self) -> None:
        r = self.api.request("POST", "/auth/login",
                             {"email": self.email, "password": "test-only"})
        assert r.status == 200 and isinstance(r.body, dict), f"login failed: {r.status} {r.body}"
        self.api.access_token = r.body["accessToken"]
        me = self.api.request("GET", "/auth/me")
        self.actor = str(me.body.get("name", ""))
        assert self.actor, "/auth/me returned no name"

    def create_fixtures(self) -> None:
        # Assigned drafts: driver, plate and run all present, so the assignment
        # gate is satisfied and the transition itself is what is under test.
        values = ",\n".join(
            f"('{whse}', '{key}')" for key, whse in FIXTURES.items())
        self.sql.exec(
            f"""
            DELETE FROM DOC_SHIPMENT_STATUS_LOG WHERE SHIPMENTKEY LIKE 'MN-TEST-%';
            DELETE FROM TMS_DOCUMENT_AUDIT      WHERE DOCUMENTKEY LIKE 'MN-TEST-%';
            DELETE FROM DOC_SHIPMENT_HDR        WHERE SHIPMENTKEY LIKE 'MN-TEST-%';
            INSERT INTO DOC_SHIPMENT_HDR
                (WHSEID, SHIPMENTKEY, STATUS, DRIVERKEY, LICENSEPLATE, ROUTE, ADDDATE, ADDWHO)
            SELECT v.whse, v.k, 'DRAFT', 'DRV-001', '70-1234', 'RT-NORTH-01',
                   GETDATE(), 'manifest_confirm_test'
            FROM (VALUES {values}) AS v(whse, k);
            """
        )

    # -- tests ---------------------------------------------------------------

    def test_01_confirms_an_assigned_draft(self) -> None:
        whse, key = "WSK", "MN-TEST-8001"
        before = self.sql.shipment(key)
        v1 = self.version_of(whse, key)

        r = self.confirm(whse, key, f'"{v1}"', request_id="confirm01")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        row = self.sql.shipment(key)
        assert row["status"] == "CONFIRMED", f"STATUS is {row['status']}"
        assert row["confirmDate"] != "", "CONFIRMDATE was not written"
        assert row["confirmBy"] == self.actor, f"CONFIRMBY is {row['confirmBy']!r}"
        assert row["rowver"] != before["rowver"], "ROWVER did not change"

        assert r.body["status"] == "confirmed", f"response says {r.body.get('status')!r}"
        v2 = r.body["currentVersion"]
        assert v2 != v1, "the response carried the old version"
        assert base64.b64decode(v2).hex().upper() == row["rowver"][2:], (
            "currentVersion is not the ROWVER the database holds")

    def test_02_records_the_status_log_not_the_audit(self) -> None:
        whse, key = "WSK", "MN-TEST-8002"
        v1 = self.version_of(whse, key)
        r = self.confirm(whse, key, f'"{v1}"', request_id="confirm02")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        log = self.sql.status_log(key)
        assert len(log) == 1, f"expected 1 status-log row, found {len(log)}"
        e = log[0]
        assert e["frm"] == "DRAFT" and e["to"] == "CONFIRMED", (
            f"the log records {e['frm']} -> {e['to']}")
        assert e["source"] == "TMS", f"SOURCESYSTEM is {e['source']!r}"
        assert e["who"] == self.actor, f"CHANGEWHO is {e['who']!r}"
        assert e["whse"] == whse, f"log WHSEID is {e['whse']}"

        audits = self.sql.scalar(
            f"SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY = '{key}'")
        assert audits == "0", (
            "a shipment transition was copied into TMS_DOCUMENT_AUDIT — "
            "the status log is meant to be the single account of it")

    def test_03_unassigned_draft_is_refused(self) -> None:
        # Baseline WSK draft: driver and run, no plate. Read-only throughout.
        whse, key = "WSK", BASELINE_DRAFT
        before = self.sql.shipment(key)
        v1 = self.version_of(whse, key)

        r = self.confirm(whse, key, f'"{v1}"')
        assert r.status == 422, (
            f"expected 422 for an unassigned draft, got {r.status}: {r.body}")
        assert isinstance(r.body, dict) and "ระบุรถ" in str(r.body.get("message", "")), (
            f"the refusal did not name the missing assignment: {r.body}")

        after = self.sql.shipment(key)
        assert after["status"] == "DRAFT", "the refusal changed the status"
        assert after["rowver"] == before["rowver"], "the refusal wrote to the row"
        assert self.sql.status_log(key) == before_log_43, (
            "the refusal wrote a status-log row")

    def test_04_wrong_state_is_refused(self) -> None:
        whse, key = "WSK", BASELINE_SENT
        before = self.sql.shipment(key)
        v1 = self.version_of(whse, key)

        r = self.confirm(whse, key, f'"{v1}"')
        assert r.status == 409, f"expected 409 for a SENT manifest, got {r.status}: {r.body}"

        after = self.sql.shipment(key)
        assert after["status"] == "SENT", "the refusal changed the status"
        assert after["rowver"] == before["rowver"], "the refusal wrote to the row"

    def test_05_missing_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-8003"
        before = self.sql.shipment(key)
        r = self.confirm(whse, key, None)
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "the row was written anyway"

    def test_06_malformed_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-8003"
        before = self.sql.shipment(key)
        r = self.confirm(whse, key, '"not-base64!!"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "the row was written anyway"

    def test_07_stale_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-8004"
        v1 = self.version_of(whse, key)

        # Moved by something that is not this API — the case If-Match exists for.
        self.sql.exec(
            f"UPDATE DOC_SHIPMENT_HDR SET NOTES = ISNULL(NOTES,'') + ' ' "
            f"WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}';")
        moved = self.sql.shipment(key)

        r = self.confirm(whse, key, f'"{v1}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        current = r.body.get("currentVersion")
        assert isinstance(current, str) and current != v1, "the 409 handed back the stale version"
        assert base64.b64decode(current).hex().upper() == moved["rowver"][2:], (
            "the 409's currentVersion is not the database's")
        assert self.sql.shipment(key)["status"] == "DRAFT", "a stale confirm went through"
        assert self.sql.status_log(key) == [], "a stale confirm wrote a status-log row"

    def test_08_cross_warehouse(self) -> None:
        # A WPD document asked for under WSK reads as absent, not forbidden.
        before = self.sql.shipment(BASELINE_OTHER_WHSE)
        r = self.confirm("WSK", BASELINE_OTHER_WHSE, '"AAAAAAAACAg="')
        assert r.status == 404, f"expected 404, got {r.status}: {r.body}"

        after = self.sql.shipment(BASELINE_OTHER_WHSE)
        assert after["rowver"] == before["rowver"], "a WSK request wrote WPD's document"
        assert after["status"] == "CONFIRMED", "WPD's document changed status"

    def test_09_isolated_fixture_in_another_warehouse(self) -> None:
        # The fixture exists in WPD; WSK must not be able to confirm it.
        key = "MN-TEST-8006"
        before = self.sql.shipment(key)
        v1 = self.version_of("WPD", key)

        denied = self.confirm("WSK", key, f'"{v1}"')
        assert denied.status == 404, f"expected 404, got {denied.status}: {denied.body}"
        assert self.sql.shipment(key)["status"] == "DRAFT", "WSK confirmed a WPD document"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "WPD's row was written"

    def test_10_stops_are_untouched(self) -> None:
        whse, key = "WSK", "MN-TEST-8005"
        stops_before = self.sql.scalar(
            f"SELECT COUNT(*) FROM DOC_SHIPMENT_STOP WHERE SHIPMENTKEY = '{key}'")
        details_before = self.sql.scalar(
            f"SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL WHERE SHIPMENTKEY = '{key}'")

        v1 = self.version_of(whse, key)
        r = self.confirm(whse, key, f'"{v1}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        assert self.sql.scalar(
            f"SELECT COUNT(*) FROM DOC_SHIPMENT_STOP WHERE SHIPMENTKEY = '{key}'"
        ) == stops_before, "confirming changed the stops"
        assert self.sql.scalar(
            f"SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL WHERE SHIPMENTKEY = '{key}'"
        ) == details_before, "confirming changed the order details"

    def test_11_version_round_trip(self) -> None:
        whse, key = "WSK", "MN-TEST-8001"  # already confirmed by test 01
        row = self.sql.shipment(key)
        assert row["status"] == "CONFIRMED", "test 01 should have confirmed this already"

        got = self.api.request("GET", f"/manifests/{key}", warehouse=whse)
        assert base64.b64decode(got.body["currentVersion"]).hex().upper() == row["rowver"][2:], (
            "a re-read disagrees with the version the database holds")

    # -- teardown ------------------------------------------------------------

    def teardown(self) -> None:
        self.sql.exec(
            "DELETE FROM DOC_SHIPMENT_STATUS_LOG WHERE SHIPMENTKEY LIKE 'MN-TEST-%';"
            "DELETE FROM TMS_DOCUMENT_AUDIT      WHERE DOCUMENTKEY LIKE 'MN-TEST-%';"
            "DELETE FROM DOC_SHIPMENT_HDR        WHERE SHIPMENTKEY LIKE 'MN-TEST-%';")

    def verify_baseline(self) -> None:
        rows = self.sql.rows(
            "SELECT WHSEID, SHIPMENTKEY, STATUS FROM DOC_SHIPMENT_HDR ORDER BY WHSEID, SHIPMENTKEY")
        assert rows == [
            ["WPD", "MN-202608-0040", "COMPLETED"],
            ["WPD", "MN-202608-0042", "CONFIRMED"],
            ["WSK", "MN-202608-0041", "SENT"],
            ["WSK", "MN-202608-0043", "DRAFT"],
            ["WWP", "MN-202608-0039", "ERROR"],
        ], f"the manifest baseline moved: {rows}"

        assert self.sql.scalar(
            "SELECT COUNT(*) FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY LIKE 'MN-TEST-%'"
        ) == "0", "fixtures left behind"
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_STATUS_LOG") == "14", (
            "the status log is not back to its fourteen seeded rows")
        assert self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT") == "0", (
            "audit rows left behind")
        assert self.sql.scalar(
            "SELECT COUNT(*) FROM DOC_SHIPMENT_HDR WHERE CONFIRMBY IS NOT NULL"
        ) == "0", "a baseline manifest kept a CONFIRMBY"

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        global before_log_43
        print(f"Manifest confirm — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")
        self.create_fixtures()
        print(f"  ok    {len(FIXTURES)} assigned draft fixtures created")
        before_log_43 = self.sql.status_log(BASELINE_DRAFT)

        print("\nthe matrix")
        for name, test in [
            ("01 confirms an assigned draft", self.test_01_confirms_an_assigned_draft),
            ("02 writes the status log, not the document audit",
             self.test_02_records_the_status_log_not_the_audit),
            ("03 an unassigned draft is refused (422)", self.test_03_unassigned_draft_is_refused),
            ("04 a SENT manifest cannot be confirmed (409)", self.test_04_wrong_state_is_refused),
            ("05 a missing If-Match is refused", self.test_05_missing_if_match),
            ("06 a malformed If-Match is refused", self.test_06_malformed_if_match),
            ("07 a stale If-Match answers 409 with the current version",
             self.test_07_stale_if_match),
            ("08 another warehouse's document reads as absent", self.test_08_cross_warehouse),
            ("09 a WPD fixture cannot be confirmed from WSK",
             self.test_09_isolated_fixture_in_another_warehouse),
            ("10 stops and details are untouched", self.test_10_stops_are_untouched),
            ("11 the version round-trips", self.test_11_version_round_trip),
        ]:
            self.check(name, test)

        print("\nteardown")
        self.teardown()
        self.check("baseline restored", self.verify_baseline)

        print()
        if self.failures:
            print(f"{len(self.failures)} failed, {self.passes} passed")
            for f in self.failures:
                print(f"  - {f}")
            return 1
        print(f"All {self.passes} checks passed.")
        return 0


before_log_43: list[dict[str, str]] = []


def main() -> int:
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

    suite = Suite(ApiClient(args.base_url, args.timeout),
                  Sql(args.server, args.database), args.email)
    try:
        return suite.run()
    except AssertionError as error:
        print(f"\nSetup failed: {error}")
        try:
            suite.teardown()
            print("Fixtures removed.")
        except AssertionError as cleanup:
            print(f"Could not clean up: {cleanup}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
