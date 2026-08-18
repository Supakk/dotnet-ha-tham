#!/usr/bin/env python3
"""HTTP integration tests for POST /transport-plans/{id}/cancel.

    dotnet run
    py -3 tests/plan_cancel_http_test.py

Draft only. The header becomes CANCELLED and every line it holds is cancelled
with it, in one transaction.

WHY THE LINES MATTER MORE THAN THE HEADER
-----------------------------------------
The pending pool is derived from *line* status, not plan status — an order is
claimed while some line names it and is not CANCELLED, and the pool query never
looks at which plan that line belongs to. So cancelling only the header would
strand every order the plan held: out of the pool, on a plan nobody can use, and
invisible to the screen that would put them somewhere else. Test 02 is the one
that checks this, and it checks the pool rather than the row count.

WHAT IT DOES TO THE DATABASE
----------------------------
It raises its own plans and removes them afterwards, restoring the PL counter.
Orders come from the real WSK pool and are handed back by cancelling; the run
asserts the pool is back at 10 at the end. PL-202608-0001 is never touched.
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
BASELINE_PLAN = "PL-202608-0001"
ROUTE_EAST = "rt-RT-EAST-01"
ROUTE_CODE = "RT-EAST-01"


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

    def plan(self, plan_key: str) -> dict[str, str]:
        rows = self.rows(
            "SELECT STATUS, ISNULL(CANCELREASON,''), ISNULL(CAST(TOTALORDER AS varchar(9)),''), "
            "ISNULL(EDITWHO,''), CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_TRANSPORT_PLAN WHERE PLANKEY = '{plan_key}'")
        if not rows:
            raise AssertionError(f"{plan_key} is not in DOC_TRANSPORT_PLAN")
        return {"status": rows[0][0], "reason": rows[0][1], "totalOrder": rows[0][2],
                "editwho": rows[0][3], "rowver": rows[0][4]}

    def lines(self, plan_key: str) -> list[dict[str, str]]:
        return [
            {"order": r[0], "status": r[1], "editwho": r[2]}
            for r in self.rows(
                "SELECT ORDERKEY, STATUS, ISNULL(EDITWHO,'') FROM DOC_TRANSPORT_PLAN_LINE "
                f"WHERE PLANKEY = '{plan_key}' ORDER BY ORDERKEY")
        ]

    def audits(self, key: str) -> list[dict[str, str]]:
        return [
            {"action": r[0], "frm": r[1], "to": r[2], "reason": r[3],
             "actor": r[4], "requestId": r[5], "whse": r[6], "metadata": r[7]}
            for r in self.rows(
                "SELECT ACTION, ISNULL(FROMSTATUS,''), ISNULL(TOSTATUS,''), ISNULL(REASON,''), "
                "ACTOR, ISNULL(REQUESTID,''), WHSEID, ISNULL(METADATA,'') "
                f"FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY = '{key}' ORDER BY AUDITID")
        ]


class Suite:
    def __init__(self, api: ApiClient, sql: Sql, email: str) -> None:
        self.api, self.sql, self.email = api, sql, email
        self.actor = ""
        self.created: list[str] = []
        self.pool: list[str] = []
        self.failures: list[str] = []
        self.passes = 0

    # -- helpers -------------------------------------------------------------

    def new_plan(self, warehouse: str = "WSK") -> dict[str, Any]:
        body = {"warehouseCode": warehouse, "deliveryDate": "2026-09-14",
                "routeId": ROUTE_EAST, "note": ""}
        r = self.api.request("POST", "/transport-plans", body, warehouse=warehouse)
        assert r.status == 200, f"could not raise a plan: {r.status} {r.body}"
        self.created.append(r.body["planNo"])
        return r.body

    def filled_plan(self, orders: list[str], warehouse: str = "WSK") -> tuple[str, str]:
        """A draft plan holding these orders. Returns (planNo, currentVersion)."""
        plan = self.new_plan(warehouse)
        r = self.api.request("PUT", f"/transport-plans/{plan['planNo']}/stops",
                             {"stopIds": orders}, warehouse=warehouse,
                             if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 200, f"could not fill the plan: {r.status} {r.body}"
        return plan["planNo"], r.body["currentVersion"]

    def cancel(self, plan_no: str, *, warehouse: str = "WSK", if_match: str | None,
               reason: str | None = None, request_id: str | None = None) -> Response:
        return self.api.request("POST", f"/transport-plans/{plan_no}/cancel",
                                {"reason": reason} if reason is not None else {},
                                warehouse=warehouse, if_match=if_match, request_id=request_id)

    def version_of(self, plan_no: str, warehouse: str = "WSK") -> str:
        r = self.api.request("GET", f"/transport-plans/{plan_no}", warehouse=warehouse)
        assert r.status == 200, f"GET {plan_no} returned {r.status}"
        return r.body["currentVersion"]

    def pool_ids(self, warehouse: str = "WSK") -> list[str]:
        r = self.api.request("GET", "/manifests/pending-stops", warehouse=warehouse)
        assert r.status == 200, f"pool read returned {r.status}"
        return sorted(s["doNo"] for s in r.body)

    def release_all(self) -> None:
        """Empty any plan still holding orders, so the next test can have them."""
        for plan_no in self.created:
            try:
                live = [l for l in self.sql.lines(plan_no) if l["status"] != "CANCELLED"]
                if live and self.sql.plan(plan_no)["status"] == "DRAFT":
                    self.api.request("PUT", f"/transport-plans/{plan_no}/stops",
                                     {"stopIds": []}, warehouse="WSK",
                                     if_match=f'"{self.version_of(plan_no)}"')
            except AssertionError:
                pass

    def check(self, name: str, run: Callable[[], None]) -> None:
        try:
            run()
        except AssertionError as e:
            self.failures.append(f"{name}: {e}")
            print(f"  FAIL  {name}\n        {e}")
        else:
            self.passes += 1
            print(f"  ok    {name}")
        finally:
            self.release_all()

    def login(self) -> None:
        r = self.api.request("POST", "/auth/login",
                             {"email": self.email, "password": "test-only"})
        assert r.status == 200 and isinstance(r.body, dict), f"login failed: {r.status} {r.body}"
        self.api.access_token = r.body["accessToken"]
        me = self.api.request("GET", "/auth/me")
        self.actor = str(me.body.get("name", ""))
        assert self.actor, "/auth/me returned no name"

    def reachable_orders(self, count: int) -> list[str]:
        rows = self.sql.rows(
            "SELECT TOP (%d) o.ORDERKEY FROM DOC_DO_HDR o "
            "WHERE o.WHSEID = 'WSK' AND o.ZONE IN ("
            "  SELECT rz.TRANSPORTZONEKEY FROM MST_ROUTE_ZONE rz "
            f"  WHERE rz.WHSEID = 'WSK' AND rz.ROUTE = '{ROUTE_CODE}')"
            " AND NOT EXISTS (SELECT 1 FROM DOC_SHIPMENT_DETAIL d "
            "                 WHERE d.WHSEID = o.WHSEID AND d.ORDERKEY = o.ORDERKEY "
            "                   AND d.STATUS <> 'CANCELLED')"
            " ORDER BY o.ORDERKEY" % count)
        keys = [r[0] for r in rows]
        assert len(keys) >= count, (
            f"the pool needs {count} unplanned WSK orders on {ROUTE_CODE}, found {len(keys)}")
        return keys

    # -- tests ---------------------------------------------------------------

    def test_01_cancels_an_empty_draft(self) -> None:
        plan = self.new_plan()
        r = self.cancel(plan["planNo"], if_match=f'"{plan["currentVersion"]}"',
                        request_id="pc01")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        row = self.sql.plan(plan["planNo"])
        assert row["status"] == "CANCELLED", f"STATUS is {row['status']}"
        assert row["editwho"] == self.actor, f"EDITWHO is {row['editwho']!r}"
        assert r.body["status"] == "cancelled", f"response says {r.body.get('status')!r}"

    def test_02_returns_its_orders_to_the_pool(self) -> None:
        a, b = self.pool[0], self.pool[1]
        plan_no, version = self.filled_plan([a, b])
        assert a not in self.pool_ids() and b not in self.pool_ids(), "setup did not claim them"

        r = self.cancel(plan_no, if_match=f'"{version}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        # The pool is derived from line status, so this is the assertion that
        # matters: cancelling only the header would strand both orders.
        pool = self.pool_ids()
        assert a in pool and b in pool, (
            "the plan's orders did not come back to the pool — "
            "its lines were left live under a cancelled header")

        lines = self.sql.lines(plan_no)
        assert len(lines) == 2, f"line rows were deleted rather than cancelled: {lines}"
        assert all(l["status"] == "CANCELLED" for l in lines), f"line statuses are {lines}"
        assert all(l["editwho"] == self.actor for l in lines), "cancelled lines record no actor"
        assert self.sql.plan(plan_no)["totalOrder"] == "0", "TOTALORDER was not cleared"
        assert r.body["stops"] == [], "the cancelled plan still reports stops"

    def test_03_records_the_reason(self) -> None:
        plan = self.new_plan()
        r = self.cancel(plan["planNo"], if_match=f'"{plan["currentVersion"]}"',
                        reason="ลูกค้าเลื่อนวันส่ง")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["reason"] == "ลูกค้าเลื่อนวันส่ง", (
            "CANCELREASON was not stored")

    def test_04_blank_reason_stays_null(self) -> None:
        plan = self.new_plan()
        r = self.cancel(plan["planNo"], if_match=f'"{plan["currentVersion"]}"', reason="   ")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["reason"] == "", (
            "a blank reason was stored rather than left unset")

    def test_05_audit_records_what_was_released(self) -> None:
        a = self.pool[0]
        plan_no, version = self.filled_plan([a])

        r = self.cancel(plan_no, if_match=f'"{version}"', reason="รวมรอบ", request_id="pc05")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        entries = [e for e in self.sql.audits(plan_no) if e["action"] == "CANCELLED"]
        assert len(entries) == 1, f"expected 1 CANCELLED audit row, found {len(entries)}"
        e = entries[0]
        assert e["frm"] == "DRAFT" and e["to"] == "CANCELLED", f"{e['frm']} -> {e['to']}"
        assert e["reason"] == "รวมรอบ", f"audit REASON is {e['reason']!r}"
        assert e["actor"] == self.actor, f"ACTOR is {e['actor']!r}"
        assert e["requestId"] == "pc05", f"REQUESTID is {e['requestId']!r}"
        assert e["whse"] == "WSK", f"audit WHSEID is {e['whse']}"
        assert a in e["metadata"], "the audit does not record which orders were released"

    def test_06_already_cancelled_is_refused(self) -> None:
        plan = self.new_plan()
        first = self.cancel(plan["planNo"], if_match=f'"{plan["currentVersion"]}"')
        assert first.status == 200, f"setup failed: {first.status} {first.body}"

        again = self.cancel(plan["planNo"], if_match=f'"{first.body["currentVersion"]}"')
        assert again.status == 409, f"expected 409, got {again.status}: {again.body}"

    def test_07_issued_plan_is_refused(self) -> None:
        # A plan that has cut a manifest is the record of where it came from.
        plan = self.new_plan()
        plan_no = plan["planNo"]
        self.sql.exec(
            "UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'ISSUED', SHIPMENTKEY = 'MN-202608-0043' "
            f"WHERE PLANKEY = '{plan_no}';")

        r = self.cancel(plan_no, if_match=f'"{self.version_of(plan_no)}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        assert self.sql.plan(plan_no)["status"] == "ISSUED", "the refusal changed the status"

        self.sql.exec(
            "UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'DRAFT', SHIPMENTKEY = NULL "
            f"WHERE PLANKEY = '{plan_no}';")

    def test_08_missing_if_match(self) -> None:
        plan = self.new_plan()
        before = self.sql.plan(plan["planNo"])
        r = self.cancel(plan["planNo"], if_match=None)
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["rowver"] == before["rowver"], "the row was written"

    def test_09_malformed_if_match(self) -> None:
        plan = self.new_plan()
        before = self.sql.plan(plan["planNo"])
        r = self.cancel(plan["planNo"], if_match='"not-base64!!"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["rowver"] == before["rowver"], "the row was written"

    def test_10_stale_if_match(self) -> None:
        a = self.pool[0]
        plan = self.new_plan()
        v1 = plan["currentVersion"]

        filled = self.api.request("PUT", f"/transport-plans/{plan['planNo']}/stops",
                                  {"stopIds": [a]}, warehouse="WSK", if_match=f'"{v1}"')
        assert filled.status == 200, f"setup failed: {filled.status} {filled.body}"
        v2 = filled.body["currentVersion"]

        stale = self.cancel(plan["planNo"], if_match=f'"{v1}"')
        assert stale.status == 409, f"a stale version was accepted: {stale.status} {stale.body}"
        assert stale.body.get("currentVersion") == v2, "the 409 did not hand back the live version"
        assert self.sql.plan(plan["planNo"])["status"] == "DRAFT", "the stale cancel went through"
        assert a not in self.pool_ids(), "a refused cancel released the order anyway"

    def test_11_cross_warehouse(self) -> None:
        plan = self.new_plan("WSK")
        r = self.cancel(plan["planNo"], warehouse="WPD",
                        if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 404, f"expected 404, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["status"] == "DRAFT", "a WPD request cancelled it"

    def test_12_version_round_trip(self) -> None:
        plan = self.new_plan()
        v1 = plan["currentVersion"]
        r = self.cancel(plan["planNo"], if_match=f'"{v1}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        v2 = r.body["currentVersion"]
        assert v2 != v1, "the response repeated the version it was sent"
        row = self.sql.plan(plan["planNo"])
        assert base64.b64decode(v2).hex().upper() == row["rowver"][2:], (
            "currentVersion is not the ROWVER the database holds")

        got = self.api.request("GET", f"/transport-plans/{plan['planNo']}", warehouse="WSK")
        assert got.body["currentVersion"] == v2, "a re-read disagrees with the write"
        assert got.body["status"] == "cancelled", f"the read says {got.body['status']}"

    # -- teardown ------------------------------------------------------------

    def teardown(self) -> None:
        made = [p for p in dict.fromkeys(self.created) if p != BASELINE_PLAN]
        if made:
            keys = "', '".join(made)
            self.sql.exec(
                f"DELETE FROM TMS_DOCUMENT_AUDIT      WHERE DOCUMENTKEY IN ('{keys}');"
                f"DELETE FROM DOC_TRANSPORT_PLAN_LINE WHERE PLANKEY IN ('{keys}');"
                f"DELETE FROM DOC_TRANSPORT_PLAN      WHERE PLANKEY IN ('{keys}');")
        self.sql.exec(
            "UPDATE TMS_DOCUMENT_NUMBER SET LASTNUMBER = 1, EDITWHO = 'migration-006' "
            "WHERE PREFIX = 'PL' AND PERIOD = '202608' AND LASTNUMBER <> 1;")

    def verify_baseline(self) -> None:
        plans = self.sql.rows("SELECT WHSEID, PLANKEY, STATUS FROM DOC_TRANSPORT_PLAN")
        assert plans == [["WSK", BASELINE_PLAN, "DRAFT"]], f"plans left as {plans}"
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_TRANSPORT_PLAN_LINE") == "0"
        assert self.sql.scalar(
            "SELECT LASTNUMBER FROM TMS_DOCUMENT_NUMBER WHERE PREFIX='PL' AND PERIOD='202608'"
        ) == "1", "the PL counter was not restored"
        assert self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT") == "0"
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_HDR") == "5"
        assert len(self.pool_ids()) == 10, (
            f"the WSK pool is {len(self.pool_ids())}, baseline is 10")

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        print(f"Plan cancel — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")
        self.pool = self.reachable_orders(2)
        print(f"  ok    {len(self.pool)} WSK orders reachable on {ROUTE_CODE}")

        print("\nthe matrix")
        for name, test in [
            ("01 cancels an empty draft", self.test_01_cancels_an_empty_draft),
            ("02 returns its orders to the pool", self.test_02_returns_its_orders_to_the_pool),
            ("03 records the reason", self.test_03_records_the_reason),
            ("04 a blank reason stays unset", self.test_04_blank_reason_stays_null),
            ("05 the audit records what was released",
             self.test_05_audit_records_what_was_released),
            ("06 cancelling twice is refused", self.test_06_already_cancelled_is_refused),
            ("07 an issued plan cannot be cancelled", self.test_07_issued_plan_is_refused),
            ("08 a missing If-Match is refused", self.test_08_missing_if_match),
            ("09 a malformed If-Match is refused", self.test_09_malformed_if_match),
            ("10 a stale If-Match answers 409 and releases nothing",
             self.test_10_stale_if_match),
            ("11 another warehouse cannot cancel it", self.test_11_cross_warehouse),
            ("12 the version round-trips", self.test_12_version_round_trip),
        ]:
            self.check(name, test)

        print("\nteardown")
        self.teardown()
        self.check("baseline restored, pool back to 10", self.verify_baseline)

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
