#!/usr/bin/env python3
"""HTTP integration tests for DELETE /manifests/{id}.

    dotnet run
    py -3 tests/manifest_delete_http_test.py

A soft delete: STATUS becomes DELETED and the row stays. Cancelled documents
only. Answers 204, the convention this route has always used.

TWO THINGS IT MUST DO AND ONE IT MUST NOT
-----------------------------------------
It must mark the header and write the canonical lifecycle row, and it must hand
the issuing plan back to draft — a plan left ISSUED against a deleted number
would offer to open nothing. It must not touch a single stop, order or line: the
load went back to the pool when the document was cancelled, and deleting it
moves nothing.

WHAT IT DOES TO THE DATABASE
----------------------------
Every mutation runs against fixtures this file creates and removes — MN-TEST-7xxx
and a PL-TEST plan for the hand-back case. No baseline document is written; the
two it reads (a SENT manifest for the wrong-state case, a WPD one for isolation)
are read only.
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

BASELINE_SENT = "MN-202608-0041"        # WSK, SENT — cannot be deleted
BASELINE_OTHER_WHSE = "MN-202608-0042"  # WPD, CONFIRMED

# Cancelled fixtures, deletable. 7006 lives in WPD for the isolation case.
CANCELLED = {
    "MN-TEST-7001": "WSK", "MN-TEST-7002": "WSK", "MN-TEST-7003": "WSK",
    "MN-TEST-7004": "WSK", "MN-TEST-7005": "WSK", "MN-TEST-7006": "WPD",
    "MN-TEST-7007": "WSK",
}
PLAN_FIXTURE = "PL-TEST-7001"      # ISSUED, pointing at MN-TEST-7007
ISSUED_MANIFEST = "MN-TEST-7007"


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
            "SELECT WHSEID, STATUS, ISNULL(CONVERT(varchar(19), DELETEDDATE, 120), ''), "
            "ISNULL(DELETEDBY, ''), ISNULL(DELETEREASON, ''), ISNULL(CANCELREASON, ''), "
            "ISNULL(CONFIRMBY, ''), CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY = '{key}'")
        if not rows:
            raise AssertionError(f"{key} is not in DOC_SHIPMENT_HDR")
        r = rows[0]
        return {"whse": r[0], "status": r[1], "deletedDate": r[2], "deletedBy": r[3],
                "deleteReason": r[4], "cancelReason": r[5], "confirmBy": r[6], "rowver": r[7]}

    def status_log(self, key: str) -> list[dict[str, str]]:
        return [
            {"frm": r[0], "to": r[1], "source": r[2], "who": r[3], "whse": r[4]}
            for r in self.rows(
                "SELECT ISNULL(FROMSTATUS,''), ISNULL(TOSTATUS,''), ISNULL(SOURCESYSTEM,''), "
                "ISNULL(CHANGEWHO,''), WHSEID FROM DOC_SHIPMENT_STATUS_LOG "
                f"WHERE SHIPMENTKEY = '{key}' ORDER BY SERIALKEY")
        ]

    def plan(self, key: str) -> dict[str, str]:
        rows = self.rows(
            "SELECT STATUS, ISNULL(SHIPMENTKEY,''), ISNULL(EDITWHO,'') "
            f"FROM DOC_TRANSPORT_PLAN WHERE PLANKEY = '{key}'")
        if not rows:
            raise AssertionError(f"{key} is not in DOC_TRANSPORT_PLAN")
        return {"status": rows[0][0], "shipmentKey": rows[0][1], "editwho": rows[0][2]}


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

    def delete(self, whse: str, key: str, if_match: str | None,
               request_id: str | None = None) -> Response:
        return self.api.request("DELETE", f"/manifests/{key}",
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
        values = ",\n".join(f"('{whse}', '{key}')" for key, whse in CANCELLED.items())
        self.sql.exec(
            f"""
            DELETE FROM DOC_SHIPMENT_STATUS_LOG WHERE SHIPMENTKEY LIKE 'MN-TEST-%';
            DELETE FROM DOC_SHIPMENT_HDR        WHERE SHIPMENTKEY LIKE 'MN-TEST-%';
            DELETE FROM DOC_TRANSPORT_PLAN      WHERE PLANKEY  LIKE 'PL-TEST-%';

            /* Cancelled, with a cancellation reason and a confirm stamp already
               on them, so the test can prove the delete clears neither. */
            INSERT INTO DOC_SHIPMENT_HDR
                (WHSEID, SHIPMENTKEY, STATUS, CANCELREASON, CONFIRMBY, CONFIRMDATE, ADDDATE, ADDWHO)
            SELECT v.whse, v.k, 'CANCELLED', N'ยกเลิกไว้ก่อนลบ', 'someone-earlier',
                   GETDATE(), GETDATE(), 'manifest_delete_test'
            FROM (VALUES {values}) AS v(whse, k);

            /* An issued plan pointing at MN-TEST-7007, for the hand-back case. */
            INSERT INTO DOC_TRANSPORT_PLAN
                (WHSEID, PLANKEY, PLANDATE, DELIVERYDATE, ROUTE, SHIPMENTKEY, STATUS, ADDDATE, ADDWHO)
            VALUES ('WSK', '{PLAN_FIXTURE}', GETDATE(), '2026-09-30', 'RT-NORTH-01',
                    '{ISSUED_MANIFEST}', 'ISSUED', GETDATE(), 'manifest_delete_test');

            UPDATE DOC_SHIPMENT_HDR SET PLANKEY = '{PLAN_FIXTURE}'
            WHERE SHIPMENTKEY = '{ISSUED_MANIFEST}';
            """
        )

    # -- tests ---------------------------------------------------------------

    def test_01_soft_deletes_a_cancelled_manifest(self) -> None:
        whse, key = "WSK", "MN-TEST-7001"
        before = self.sql.shipment(key)
        v1 = self.version_of(whse, key)

        r = self.delete(whse, key, f'"{v1}"', request_id="del01")
        assert r.status == 204, f"expected 204, got {r.status}: {r.body}"

        row = self.sql.shipment(key)
        assert row["status"] == "DELETED", f"STATUS is {row['status']}"
        assert row["deletedDate"] != "", "DELETEDDATE was not written"
        assert row["deletedBy"] == self.actor, f"DELETEDBY is {row['deletedBy']!r}"
        assert row["rowver"] != before["rowver"], "ROWVER did not change"

        # The row must still be there — soft, not physical.
        assert self.sql.scalar(
            f"SELECT COUNT(*) FROM DOC_SHIPMENT_HDR WHERE SHIPMENTKEY = '{key}'"
        ) == "1", "the row was physically removed"

    def test_02_keeps_the_history_it_already_had(self) -> None:
        whse, key = "WSK", "MN-TEST-7002"
        before = self.sql.shipment(key)
        r = self.delete(whse, key, f'"{self.version_of(whse, key)}"')
        assert r.status == 204, f"expected 204, got {r.status}: {r.body}"

        row = self.sql.shipment(key)
        assert row["cancelReason"] == before["cancelReason"] != "", (
            "the cancellation reason was cleared")
        assert row["confirmBy"] == before["confirmBy"] != "", "the confirm stamp was cleared"
        assert row["deleteReason"] == "", (
            "DELETEREASON was filled in, but this route collects no reason")

    def test_03_writes_the_canonical_status_log(self) -> None:
        whse, key = "WSK", "MN-TEST-7003"
        r = self.delete(whse, key, f'"{self.version_of(whse, key)}"', request_id="del03")
        assert r.status == 204, f"expected 204, got {r.status}: {r.body}"

        log = self.sql.status_log(key)
        assert len(log) == 1, f"expected 1 status-log row, found {len(log)}"
        e = log[0]
        assert e["frm"] == "CANCELLED" and e["to"] == "DELETED", (
            f"the log records {e['frm']} -> {e['to']}")
        assert e["source"] == "TMS", f"SOURCESYSTEM is {e['source']!r}"
        assert e["who"] == self.actor, f"CHANGEWHO is {e['who']!r}"
        assert e["whse"] == whse, f"log WHSEID is {e['whse']}"

        assert self.sql.scalar(
            f"SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY = '{key}'"
        ) == "0", "a shipment transition was copied into TMS_DOCUMENT_AUDIT"

    def test_04_hands_the_issuing_plan_back(self) -> None:
        whse, key = "WSK", ISSUED_MANIFEST
        before = self.sql.plan(PLAN_FIXTURE)
        assert before["status"] == "ISSUED" and before["shipmentKey"] == key, (
            "the fixture plan is not issued against this manifest")

        r = self.delete(whse, key, f'"{self.version_of(whse, key)}"')
        assert r.status == 204, f"expected 204, got {r.status}: {r.body}"

        plan = self.sql.plan(PLAN_FIXTURE)
        assert plan["status"] == "DRAFT", (
            f"the plan is still {plan['status']} — it would name a deleted number")
        assert plan["shipmentKey"] == "", "the plan still points at the deleted manifest"
        assert plan["editwho"] == self.actor, f"plan EDITWHO is {plan['editwho']!r}"

    def test_05_wrong_state_is_refused(self) -> None:
        whse, key = "WSK", BASELINE_SENT
        before = self.sql.shipment(key)
        v1 = self.version_of(whse, key)

        r = self.delete(whse, key, f'"{v1}"')
        assert r.status == 409, f"expected 409 for a SENT manifest, got {r.status}: {r.body}"

        after = self.sql.shipment(key)
        assert after["status"] == "SENT", "the refusal changed the status"
        assert after["rowver"] == before["rowver"], "the refusal wrote to the row"
        assert self.sql.status_log(key) == before_log_sent, "the refusal wrote a status-log row"

    def test_06_missing_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-7004"
        before = self.sql.shipment(key)
        r = self.delete(whse, key, None)
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.shipment(key)["status"] == "CANCELLED", "the row was written anyway"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "the row was written anyway"

    def test_07_malformed_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-7004"
        before = self.sql.shipment(key)
        r = self.delete(whse, key, '"not-base64!!"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "the row was written anyway"

    def test_08_stale_if_match(self) -> None:
        whse, key = "WSK", "MN-TEST-7005"
        v1 = self.version_of(whse, key)

        self.sql.exec(
            f"UPDATE DOC_SHIPMENT_HDR SET NOTES = ISNULL(NOTES,'') + ' ' "
            f"WHERE WHSEID = '{whse}' AND SHIPMENTKEY = '{key}';")
        moved = self.sql.shipment(key)

        r = self.delete(whse, key, f'"{v1}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        current = r.body.get("currentVersion")
        assert isinstance(current, str) and current != v1, "the 409 handed back the stale version"
        assert base64.b64decode(current).hex().upper() == moved["rowver"][2:], (
            "the 409's currentVersion is not the database's")
        assert self.sql.shipment(key)["status"] == "CANCELLED", "a stale delete went through"
        assert self.sql.status_log(key) == [], "a stale delete wrote a status-log row"

    def test_09_repeated_stale_delete(self) -> None:
        whse, key = "WSK", "MN-TEST-7005"
        v1 = self.version_of(whse, key)

        first = self.delete(whse, key, f'"{v1}"')
        assert first.status == 204, f"the first delete failed: {first.status} {first.body}"

        second = self.delete(whse, key, f'"{v1}"')
        assert second.status == 409, (
            f"the same version deleted twice: {second.status} {second.body} — "
            "delete must not be silently idempotent")

    def test_10_cross_warehouse(self) -> None:
        before = self.sql.shipment(BASELINE_OTHER_WHSE)
        r = self.delete("WSK", BASELINE_OTHER_WHSE, '"AAAAAAAACAg="')
        assert r.status == 404, f"expected 404, got {r.status}: {r.body}"

        after = self.sql.shipment(BASELINE_OTHER_WHSE)
        assert after["rowver"] == before["rowver"], "a WSK request wrote WPD's document"
        assert after["status"] == "CONFIRMED", "WPD's document changed status"

    def test_11_isolated_fixture_in_another_warehouse(self) -> None:
        key = "MN-TEST-7006"
        before = self.sql.shipment(key)
        v1 = self.version_of("WPD", key)

        denied = self.delete("WSK", key, f'"{v1}"')
        assert denied.status == 404, f"expected 404, got {denied.status}: {denied.body}"
        assert self.sql.shipment(key)["status"] == "CANCELLED", "WSK deleted a WPD document"
        assert self.sql.shipment(key)["rowver"] == before["rowver"], "WPD's row was written"

    def test_12_children_untouched(self) -> None:
        # Counted across the whole database: deleting must move no order anywhere.
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_STOP") == stops_before, (
            "deleting changed the stops")
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL") == details_before, (
            "deleting changed the order details")
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL_LINE") == lines_before, (
            "deleting changed the detail lines")

    def test_14_version_round_trip(self) -> None:
        whse, key = "WSK", "MN-TEST-7001"  # deleted by test 01
        row = self.sql.shipment(key)
        assert row["status"] == "DELETED", "test 01 should have deleted this already"

        listed = self.api.request("GET", "/manifests", warehouse=whse)
        assert all(m["id"] != key for m in listed.body), (
            "a deleted manifest is still on the list")

        got = self.api.request("GET", f"/manifests/{key}", warehouse=whse)
        assert got.status == 200, (
            "reading a deleted manifest by number changed behaviour — "
            "the single read has never filtered DELETED")
        assert base64.b64decode(got.body["currentVersion"]).hex().upper() == row["rowver"][2:], (
            "a re-read disagrees with the version the database holds")

    # -- teardown ------------------------------------------------------------

    def teardown(self) -> None:
        self.sql.exec(
            "DELETE FROM DOC_SHIPMENT_STATUS_LOG WHERE SHIPMENTKEY LIKE 'MN-TEST-%';"
            "DELETE FROM TMS_DOCUMENT_AUDIT      WHERE DOCUMENTKEY LIKE 'MN-TEST-%';"
            # Shipments first: DOC_SHIPMENT_HDR.PLANKEY references the plan, so
            # the other order trips FK_DOC_SHIPMENT_HDR_PLAN.
            "DELETE FROM DOC_SHIPMENT_HDR        WHERE SHIPMENTKEY LIKE 'MN-TEST-%';"
            "DELETE FROM DOC_TRANSPORT_PLAN      WHERE PLANKEY  LIKE 'PL-TEST-%';")

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

        plans = self.sql.rows("SELECT WHSEID, PLANKEY, STATUS FROM DOC_TRANSPORT_PLAN")
        assert plans == [["WSK", "PL-202608-0001", "DRAFT"]], f"plans left as {plans}"

        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_STATUS_LOG") == "14", (
            "the status log is not back to its fourteen seeded rows")
        assert self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT") == "0"
        assert self.sql.scalar(
            "SELECT COUNT(*) FROM DOC_SHIPMENT_HDR WHERE DELETEDBY IS NOT NULL") == "0", (
            "a baseline manifest kept a DELETEDBY")

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        global before_log_sent, stops_before, details_before, lines_before
        print(f"Manifest delete — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")
        self.create_fixtures()
        print(f"  ok    {len(CANCELLED)} cancelled fixtures + 1 issued plan created")
        before_log_sent = self.sql.status_log(BASELINE_SENT)
        stops_before = self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_STOP")
        details_before = self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL")
        lines_before = self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_DETAIL_LINE")

        print("\nthe matrix")
        for name, test in [
            ("01 soft-deletes a cancelled manifest", self.test_01_soft_deletes_a_cancelled_manifest),
            ("02 clears none of the history it already had", self.test_02_keeps_the_history_it_already_had),
            ("03 writes the canonical status log, not the audit",
             self.test_03_writes_the_canonical_status_log),
            ("04 hands the issuing plan back to draft", self.test_04_hands_the_issuing_plan_back),
            ("05 a SENT manifest cannot be deleted (409)", self.test_05_wrong_state_is_refused),
            ("06 a missing If-Match is refused", self.test_06_missing_if_match),
            ("07 a malformed If-Match is refused", self.test_07_malformed_if_match),
            ("08 a stale If-Match answers 409 with the current version", self.test_08_stale_if_match),
            ("09 the same version cannot delete twice", self.test_09_repeated_stale_delete),
            ("10 another warehouse's document reads as absent", self.test_10_cross_warehouse),
            ("11 a WPD fixture cannot be deleted from WSK",
             self.test_11_isolated_fixture_in_another_warehouse),
            ("12 no stop, detail or line moved", self.test_12_children_untouched),
            ("14 gone from the list, version still consistent", self.test_14_version_round_trip),
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


before_log_sent: list[dict[str, str]] = []
stops_before = details_before = lines_before = ""


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
