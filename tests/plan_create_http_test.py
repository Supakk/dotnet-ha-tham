#!/usr/bin/env python3
"""HTTP integration tests for POST /transport-plans.

    dotnet run
    py -3 tests/plan_create_http_test.py

This is the first caller of the document-number allocator, so it is also where
the allocator stops being a statement that looks right and becomes one that has
demonstrably handed out a number, inside a real transaction, through EF.

WHAT IT DOES TO THE DATABASE
----------------------------
Creating a plan is a commit — there is no way to test it otherwise — so this run
does move the PL counter and does insert rows. Everything it creates is removed
afterwards and the counter is put back to 1, which the final check verifies
rather than assumes.

Baseline PL-202608-0001 is never touched. Plans raised by the run are identified
by being anything other than that number, and are deleted by number rather than
by a wildcard, so a plan someone else created while this was running would
survive rather than be swept up.
"""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
import threading
from dataclasses import dataclass
from typing import Any, Callable
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

PREAMBLE = "SET NOCOUNT ON; SET QUOTED_IDENTIFIER ON; SET ANSI_NULLS ON;"
BASELINE_PLAN = "PL-202608-0001"


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
                warehouse: str | None = None, request_id: str | None = None) -> Response:
        headers = {"Accept": "application/json"}
        data = None
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"
        if warehouse is not None:
            headers["X-Warehouse-Id"] = warehouse
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

    def plan(self, plan_key: str) -> dict[str, str] | None:
        rows = self.rows(
            "SELECT WHSEID, STATUS, ISNULL(ROUTE,''), CONVERT(varchar(10), DELIVERYDATE, 23), "
            f"ISNULL(ADDWHO,''), ISNULL(NOTES,'') FROM DOC_TRANSPORT_PLAN WHERE PLANKEY = '{plan_key}'")
        if not rows:
            return None
        r = rows[0]
        return {"whse": r[0], "status": r[1], "route": r[2],
                "delivery": r[3], "addwho": r[4], "notes": r[5]}

    def audits(self, key: str) -> list[dict[str, str]]:
        return [
            {"type": r[0], "action": r[1], "to": r[2], "actor": r[3], "requestId": r[4], "whse": r[5]}
            for r in self.rows(
                "SELECT DOCUMENTTYPE, ACTION, ISNULL(TOSTATUS,''), ACTOR, ISNULL(REQUESTID,''), WHSEID "
                f"FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY = '{key}' ORDER BY AUDITID")
        ]

    def pl_counter(self) -> str:
        return self.scalar(
            "SELECT LASTNUMBER FROM TMS_DOCUMENT_NUMBER WHERE PREFIX='PL' AND PERIOD='202608'")


class Suite:
    def __init__(self, api: ApiClient, sql: Sql, email: str) -> None:
        self.api, self.sql, self.email = api, sql, email
        self.actor = ""
        self.created: list[str] = []
        self.failures: list[str] = []
        self.passes = 0

    # -- helpers -------------------------------------------------------------

    def create(self, warehouse: str = "WSK", *, route: str = "rt-RT-NORTH-01",
               delivery: str = "2026-09-15", note: str = "",
               request_id: str | None = None) -> Response:
        body = {"warehouseCode": warehouse, "deliveryDate": delivery,
                "routeId": route, "note": note}
        r = self.api.request("POST", "/transport-plans", body,
                             warehouse=warehouse, request_id=request_id)
        if r.status == 200 and isinstance(r.body, dict) and r.body.get("planNo"):
            self.created.append(r.body["planNo"])
        return r

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

    # -- tests ---------------------------------------------------------------

    def test_01_creates_a_numbered_plan(self) -> None:
        before = int(self.sql.pl_counter())
        r = self.create(request_id="plancreate01")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        assert isinstance(r.body, dict)

        expected_no = f"PL-202608-{before + 1:04d}"
        assert r.body["planNo"] == expected_no, (
            f"expected {expected_no}, got {r.body.get('planNo')}")
        assert int(self.sql.pl_counter()) == before + 1, "the counter did not advance by one"

        row = self.sql.plan(expected_no)
        assert row is not None, f"{expected_no} is not in DOC_TRANSPORT_PLAN"
        assert row["whse"] == "WSK", f"WHSEID is {row['whse']}"
        assert row["status"] == "DRAFT", f"STATUS is {row['status']}"
        assert row["route"] == "RT-NORTH-01", f"ROUTE is {row['route']} — the rt- prefix was not stripped"
        assert row["delivery"] == "2026-09-15", f"DELIVERYDATE is {row['delivery']}"
        assert row["addwho"] == self.actor, f"ADDWHO is {row['addwho']!r}"

    def test_02_records_the_audit(self) -> None:
        r = self.create(request_id="plancreate02", note="ตรวจ audit")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        plan_no = r.body["planNo"]

        entries = self.sql.audits(plan_no)
        assert len(entries) == 1, f"expected 1 audit row, found {len(entries)}"
        e = entries[0]
        assert e["type"] == "PLAN", f"DOCUMENTTYPE is {e['type']}"
        assert e["action"] == "CREATED", f"ACTION is {e['action']}"
        assert e["to"] == "DRAFT", f"TOSTATUS is {e['to']}"
        assert e["actor"] == self.actor, f"ACTOR is {e['actor']!r}"
        assert e["requestId"] == "plancreate02", f"REQUESTID is {e['requestId']!r}"
        assert e["whse"] == "WSK", f"audit WHSEID is {e['whse']}"

    def test_03_warehouse_comes_from_the_header(self) -> None:
        # The body claims WPD, the header says WSK. The header wins, or a caller
        # could file a document against a site they only asserted.
        body = {"warehouseCode": "WPD", "deliveryDate": "2026-09-16",
                "routeId": "rt-RT-NORTH-01", "note": ""}
        r = self.api.request("POST", "/transport-plans", body, warehouse="WSK")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        self.created.append(r.body["planNo"])

        row = self.sql.plan(r.body["planNo"])
        assert row["whse"] == "WSK", (
            f"the body's warehouse won: row is {row['whse']}, header said WSK")

    def test_04_isolated_from_other_warehouses(self) -> None:
        r = self.create("WSK", delivery="2026-09-17")
        plan_no = r.body["planNo"]

        seen = self.api.request("GET", f"/transport-plans/{plan_no}", warehouse="WPD")
        assert seen.status == 404, (
            f"WPD can see WSK's plan: {seen.status}")

    def test_05_readable_immediately_with_a_version(self) -> None:
        r = self.create(delivery="2026-09-18", note="อ่านกลับ")
        plan_no = r.body["planNo"]
        assert isinstance(r.body.get("currentVersion"), str) and r.body["currentVersion"], (
            "the create response carried no currentVersion")

        got = self.api.request("GET", f"/transport-plans/{plan_no}", warehouse="WSK")
        assert got.status == 200, f"GET after create returned {got.status}"
        assert got.body["planNo"] == plan_no
        assert got.body["status"] == "draft", f"status reads {got.body['status']}"
        assert got.body["routeCode"] == "RT-NORTH-01"
        assert got.body["note"] == "อ่านกลับ"
        assert got.body["stops"] == [], "a new plan should be holding nothing"
        assert got.body["currentVersion"] == r.body["currentVersion"], (
            "the version from the read disagrees with the one create returned")

    def test_06_rejects_a_bad_date(self) -> None:
        before = self.sql.pl_counter()
        r = self.create(delivery="15/09/2026")
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.pl_counter() == before, "a rejected create consumed a number"

    def test_07_rejects_a_missing_route(self) -> None:
        before = self.sql.pl_counter()
        r = self.create(route="")
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.pl_counter() == before, "a rejected create consumed a number"

    def test_08_rejects_an_unknown_route(self) -> None:
        # FK_DOC_TRANSPORT_PLAN_ROUTE refuses it. The number must go back with
        # the failed insert rather than being burnt on a plan that never existed.
        before = self.sql.pl_counter()
        r = self.create(route="rt-NOT-A-ROUTE")
        assert r.status >= 400, f"an unknown route was accepted: {r.status} {r.body}"
        assert self.sql.pl_counter() == before, (
            "the number was consumed by a create that rolled back")

    def test_09_concurrent_creates_get_distinct_numbers(self) -> None:
        results: list[Response] = []
        lock = threading.Lock()

        def fire(day: int) -> None:
            r = self.create(delivery=f"2026-09-{day:02d}")
            with lock:
                results.append(r)

        threads = [threading.Thread(target=fire, args=(20 + i,)) for i in range(3)]
        for t in threads:
            t.start()
        for t in threads:
            t.join(timeout=40)

        assert len(results) == 3, f"only {len(results)} of 3 requests returned"
        for r in results:
            assert r.status == 200, f"a concurrent create failed: {r.status} {r.body}"

        numbers = sorted(r.body["planNo"] for r in results)
        assert len(set(numbers)) == 3, f"two plans got the same number: {numbers}"

        rows = self.sql.rows(
            "SELECT COUNT(*) FROM DOC_TRANSPORT_PLAN WHERE PLANKEY IN "
            f"('{numbers[0]}','{numbers[1]}','{numbers[2]}')")
        assert rows[0][0] == "3", "not every concurrent plan reached the database"

    def test_10_warehouse_header_is_required(self) -> None:
        body = {"warehouseCode": "WSK", "deliveryDate": "2026-09-25",
                "routeId": "rt-RT-NORTH-01", "note": ""}
        r = self.api.request("POST", "/transport-plans", body)
        assert r.status == 400, f"expected 400 without X-Warehouse-Id, got {r.status}"

    # -- teardown ------------------------------------------------------------

    def teardown(self) -> None:
        made = [p for p in dict.fromkeys(self.created) if p != BASELINE_PLAN]
        if made:
            keys = "', '".join(made)
            self.sql.exec(
                f"DELETE FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY IN ('{keys}');"
                f"DELETE FROM DOC_TRANSPORT_PLAN WHERE PLANKEY IN ('{keys}');")
        # The counter is restored, not decremented blindly: it goes back to what
        # the baseline says, which is also what the next run needs to see.
        self.sql.exec(
            "UPDATE TMS_DOCUMENT_NUMBER SET LASTNUMBER = 1, EDITWHO = 'migration-006' "
            "WHERE PREFIX = 'PL' AND PERIOD = '202608' AND LASTNUMBER <> 1;")

    def verify_baseline(self) -> None:
        plans = self.sql.rows("SELECT WHSEID, PLANKEY, STATUS FROM DOC_TRANSPORT_PLAN")
        assert plans == [["WSK", BASELINE_PLAN, "DRAFT"]], f"plans left as {plans}"

        lines = self.sql.scalar("SELECT COUNT(*) FROM DOC_TRANSPORT_PLAN_LINE")
        assert lines == "0", f"{lines} plan line(s) present, baseline is 0"

        assert self.sql.pl_counter() == "1", f"PL counter is {self.sql.pl_counter()}, baseline 1"
        assert self.sql.scalar(
            "SELECT LASTNUMBER FROM TMS_DOCUMENT_NUMBER WHERE PREFIX='MN' AND PERIOD='202608'"
        ) == "43", "the MN counter moved — plan creation must not touch it"

        audits = self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT")
        assert audits == "0", f"{audits} audit row(s) left behind"

        shipments = self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_HDR")
        assert shipments == "5", f"manifest count moved to {shipments}"

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        print(f"Plan create — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")

        print("\nthe matrix")
        for name, test in [
            ("01 creates a plan with the next PL number", self.test_01_creates_a_numbered_plan),
            ("02 records one audit row", self.test_02_records_the_audit),
            ("03 warehouse comes from the header, not the body",
             self.test_03_warehouse_comes_from_the_header),
            ("04 another warehouse cannot see it", self.test_04_isolated_from_other_warehouses),
            ("05 readable immediately, with a version", self.test_05_readable_immediately_with_a_version),
            ("06 a malformed date is refused", self.test_06_rejects_a_bad_date),
            ("07 a missing route is refused", self.test_07_rejects_a_missing_route),
            ("08 an unknown route rolls the number back", self.test_08_rejects_an_unknown_route),
            ("09 concurrent creates get distinct numbers",
             self.test_09_concurrent_creates_get_distinct_numbers),
            ("10 the warehouse header is required", self.test_10_warehouse_header_is_required),
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
            print("Created plans removed.")
        except AssertionError as cleanup:
            print(f"Could not clean up: {cleanup}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
