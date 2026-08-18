#!/usr/bin/env python3
"""HTTP integration tests for PUT /transport-plans/{id}/stops.

    dotnet run
    py -3 tests/plan_setstops_http_test.py

Replace, not patch: the plan ends up holding exactly the orders in the request.

THE RULE UNDER TEST
-------------------
An order leaves a plan by having its line cancelled, never deleted. The row
stays, and that is what returns the order to the pool — the pool is derived as
"nothing live has claimed this", where live means STATUS <> 'CANCELLED'. Test 03
checks both halves at once: the row is still there, its status is CANCELLED, and
the order is back in the pool.

Re-adding revives. PK_DOC_TRANSPORT_PLAN_LINE is (WHSEID, PLANKEY, ORDERKEY), so
a plan can never hold two rows for one order — test 04 puts back what test 03
took out and asserts one row, not two.

WHAT IT DOES TO THE DATABASE
----------------------------
It raises its own plans through the create endpoint and removes them afterwards,
restoring the PL counter. Orders come from the real WSK pool and are returned to
it by the teardown, which cancels every line the run created. The baseline plan
PL-202608-0001 is never touched, and the pool is asserted back at 10 at the end.
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

    def lines(self, plan_key: str) -> list[dict[str, str]]:
        return [
            {"order": r[0], "status": r[1], "whse": r[2], "editwho": r[3]}
            for r in self.rows(
                "SELECT ORDERKEY, STATUS, WHSEID, ISNULL(EDITWHO,'') "
                f"FROM DOC_TRANSPORT_PLAN_LINE WHERE PLANKEY = '{plan_key}' ORDER BY ORDERKEY")
        ]

    def live_orders(self, plan_key: str) -> list[str]:
        return sorted(l["order"] for l in self.lines(plan_key) if l["status"] != "CANCELLED")

    def plan(self, plan_key: str) -> dict[str, str]:
        rows = self.rows(
            "SELECT STATUS, ISNULL(CAST(TOTALORDER AS varchar(9)),''), ISNULL(EDITWHO,''), "
            "CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_TRANSPORT_PLAN WHERE PLANKEY = '{plan_key}'")
        if not rows:
            raise AssertionError(f"{plan_key} is not in DOC_TRANSPORT_PLAN")
        return {"status": rows[0][0], "totalOrder": rows[0][1],
                "editwho": rows[0][2], "rowver": rows[0][3]}

    def audits(self, key: str) -> list[dict[str, str]]:
        return [
            {"action": r[0], "actor": r[1], "requestId": r[2], "whse": r[3], "metadata": r[4]}
            for r in self.rows(
                "SELECT ACTION, ACTOR, ISNULL(REQUESTID,''), WHSEID, ISNULL(METADATA,'') "
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

    def new_plan(self, route: str = ROUTE_EAST, warehouse: str = "WSK") -> dict[str, Any]:
        body = {"warehouseCode": warehouse, "deliveryDate": "2026-09-12",
                "routeId": route, "note": ""}
        r = self.api.request("POST", "/transport-plans", body, warehouse=warehouse)
        assert r.status == 200, f"could not raise a plan: {r.status} {r.body}"
        self.created.append(r.body["planNo"])
        return r.body

    def set_stops(self, plan_no: str, order_ids: list[str], *, warehouse: str = "WSK",
                  if_match: str | None, request_id: str | None = None) -> Response:
        return self.api.request("PUT", f"/transport-plans/{plan_no}/stops",
                                {"stopIds": order_ids}, warehouse=warehouse,
                                if_match=if_match, request_id=request_id)

    def version_of(self, plan_no: str, warehouse: str = "WSK") -> str:
        r = self.api.request("GET", f"/transport-plans/{plan_no}", warehouse=warehouse)
        assert r.status == 200, f"GET {plan_no} returned {r.status}"
        return r.body["currentVersion"]

    def pool_ids(self, warehouse: str = "WSK") -> list[str]:
        r = self.api.request("GET", "/manifests/pending-stops", warehouse=warehouse)
        assert r.status == 200, f"pool read returned {r.status}"
        return sorted(s["doNo"] for s in r.body)

    def release(self, plan_no: str) -> None:
        """Empty the plan so its orders return to the pool for the next test.

        The WSK pool offers only two orders on any one run, so the suite shares
        them. Handing them back is the same cancel-the-line path test 03 checks,
        which makes the sharing honest rather than a fixture trick.
        """
        r = self.set_stops(plan_no, [], if_match=f'"{self.version_of(plan_no)}"')
        assert r.status == 200, f"could not release {plan_no}: {r.status} {r.body}"

    def release_all(self) -> None:
        """Hand every order back between tests, so the next one can have them.

        The WSK pool offers only two orders reachable on any single run, so the
        suite shares them. Handing them back goes through the same cancel-the-line
        path test 03 checks, which makes the sharing honest rather than a fixture
        trick.
        """
        for plan_no in self.created:
            try:
                if self.sql.live_orders(plan_no):
                    self.release(plan_no)
            except AssertionError:
                # Whatever caused this is reported by the test itself; cleanup
                # must not mask it with a second failure.
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
        """Orders in zones the eastern run actually passes through.

        Picked from the live pool by asking the database which zones the route
        covers, rather than assuming — the plan refuses anything off-route, and
        a test that picked blind would be testing the refusal.
        """
        rows = self.sql.rows(
            "SELECT TOP (%d) o.ORDERKEY FROM DOC_DO_HDR o "
            "WHERE o.WHSEID = 'WSK' AND o.ZONE IN ("
            "  SELECT rz.TRANSPORTZONEKEY FROM MST_ROUTE_ZONE rz "
            "  WHERE rz.WHSEID = 'WSK' AND rz.ROUTE = 'RT-EAST-01')"
            " AND NOT EXISTS (SELECT 1 FROM DOC_SHIPMENT_DETAIL d "
            "                 WHERE d.WHSEID = o.WHSEID AND d.ORDERKEY = o.ORDERKEY "
            "                   AND d.STATUS <> 'CANCELLED')"
            " ORDER BY o.ORDERKEY" % count)
        keys = [r[0] for r in rows]
        assert len(keys) >= count, (
            f"the pool needs {count} unplanned WSK orders on RT-EAST-01, found {len(keys)}")
        return keys

    def off_route_order(self) -> str:
        rows = self.sql.rows(
            "SELECT TOP (1) o.ORDERKEY FROM DOC_DO_HDR o "
            "WHERE o.WHSEID = 'WSK' AND (o.ZONE IS NULL OR o.ZONE NOT IN ("
            "  SELECT rz.TRANSPORTZONEKEY FROM MST_ROUTE_ZONE rz "
            "  WHERE rz.WHSEID = 'WSK' AND rz.ROUTE = 'RT-EAST-01'))"
            " AND NOT EXISTS (SELECT 1 FROM DOC_SHIPMENT_DETAIL d "
            "                 WHERE d.WHSEID = o.WHSEID AND d.ORDERKEY = o.ORDERKEY "
            "                   AND d.STATUS <> 'CANCELLED')"
            " ORDER BY o.ORDERKEY")
        assert rows, "the pool needs one WSK order off the eastern run"
        return rows[0][0]

    # -- tests ---------------------------------------------------------------

    def test_01_adds_orders(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[0], self.pool[1]

        r = self.set_stops(plan["planNo"], [a, b],
                           if_match=f'"{plan["currentVersion"]}"', request_id="ss01")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        lines = self.sql.lines(plan["planNo"])
        assert len(lines) == 2, f"expected 2 line rows, found {len(lines)}"
        assert all(l["status"] == "NEW" for l in lines), f"line statuses are {lines}"
        assert all(l["whse"] == "WSK" for l in lines), "a line landed in the wrong warehouse"
        assert self.sql.live_orders(plan["planNo"]) == sorted([a, b])

        assert self.sql.plan(plan["planNo"])["totalOrder"] == "2", "TOTALORDER was not maintained"
        assert sorted(s["doNo"] for s in r.body["stops"]) == sorted([a, b]), (
            "the response does not show what the plan is holding")

        # The pool is derived, so the orders must have left it with no second list.
        pool = self.pool_ids()
        assert a not in pool and b not in pool, "a claimed order is still in the pool"

    def test_02_no_op_same_set(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[0], self.pool[1]
        v1 = plan["currentVersion"]

        first = self.set_stops(plan["planNo"], [a, b], if_match=f'"{v1}"')
        assert first.status == 200, f"setup failed: {first.status} {first.body}"
        before = self.sql.lines(plan["planNo"])

        again = self.set_stops(plan["planNo"], [b, a],
                               if_match=f'"{first.body["currentVersion"]}"')
        assert again.status == 200, f"expected 200, got {again.status}: {again.body}"

        after = self.sql.lines(plan["planNo"])
        assert after == before, f"a no-op changed the lines: {before} -> {after}"
        assert self.sql.live_orders(plan["planNo"]) == sorted([a, b])

    def test_03_removed_order_is_cancelled_not_deleted(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[0], self.pool[1]
        v1 = plan["currentVersion"]

        first = self.set_stops(plan["planNo"], [a, b], if_match=f'"{v1}"')
        assert first.status == 200, f"setup failed: {first.status} {first.body}"

        r = self.set_stops(plan["planNo"], [a],
                           if_match=f'"{first.body["currentVersion"]}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        lines = {l["order"]: l for l in self.sql.lines(plan["planNo"])}
        assert set(lines) == {a, b}, (
            f"the dropped order's row is gone — it must be kept as CANCELLED: {sorted(lines)}")
        assert lines[b]["status"] == "CANCELLED", f"{b} is {lines[b]['status']}, expected CANCELLED"
        assert lines[a]["status"] == "NEW", f"{a} is {lines[a]['status']}"
        assert lines[b]["editwho"] == self.actor, "the cancelled line records no actor"

        assert b in self.pool_ids(), "a cancelled line did not return its order to the pool"
        assert a not in self.pool_ids(), "a kept order leaked back into the pool"
        assert self.sql.plan(plan["planNo"])["totalOrder"] == "1"

    def test_04_re_adding_revives_the_same_row(self) -> None:
        plan = self.new_plan()
        a = self.pool[0]

        v = plan["currentVersion"]
        added = self.set_stops(plan["planNo"], [a], if_match=f'"{v}"')
        assert added.status == 200, f"setup failed: {added.status} {added.body}"

        dropped = self.set_stops(plan["planNo"], [],
                                 if_match=f'"{added.body["currentVersion"]}"')
        assert dropped.status == 200, f"drop failed: {dropped.status} {dropped.body}"
        assert self.sql.lines(plan["planNo"])[0]["status"] == "CANCELLED"

        back = self.set_stops(plan["planNo"], [a],
                              if_match=f'"{dropped.body["currentVersion"]}"')
        assert back.status == 200, f"re-add failed: {back.status} {back.body}"

        lines = self.sql.lines(plan["planNo"])
        assert len(lines) == 1, (
            f"re-adding inserted a second row for the same order: {lines} — "
            "PK_DOC_TRANSPORT_PLAN_LINE is (WHSEID, PLANKEY, ORDERKEY)")
        assert lines[0]["status"] == "NEW", "the revived row is not live again"

    def test_05_replace_one_with_another(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[1], self.pool[0]

        first = self.set_stops(plan["planNo"], [a], if_match=f'"{plan["currentVersion"]}"')
        assert first.status == 200, f"setup failed: {first.status} {first.body}"

        r = self.set_stops(plan["planNo"], [b], if_match=f'"{first.body["currentVersion"]}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        assert self.sql.live_orders(plan["planNo"]) == [b]
        assert a in self.pool_ids(), "the replaced order did not return to the pool"
        assert b not in self.pool_ids(), "the new order is still in the pool"

    def test_06_duplicate_order_counts_once(self) -> None:
        plan = self.new_plan()
        a = self.pool[1]

        r = self.set_stops(plan["planNo"], [a, a], if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        assert len(self.sql.lines(plan["planNo"])) == 1, "the same order was taken twice"

    def test_07_unknown_order_is_refused(self) -> None:
        plan = self.new_plan()
        r = self.set_stops(plan["planNo"], ["DO-NOT-A-REAL-ORDER"],
                           if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        assert self.sql.lines(plan["planNo"]) == [], "a refused call wrote a line"

    def test_08_order_already_claimed_is_refused(self) -> None:
        # An order on a live shipment detail is not free, and the refusal names it
        # rather than surfacing a unique-index violation.
        taken = self.sql.scalar(
            "SELECT TOP (1) ORDERKEY FROM DOC_SHIPMENT_DETAIL "
            "WHERE WHSEID = 'WSK' AND STATUS <> 'CANCELLED' ORDER BY ORDERKEY")
        assert taken, "the baseline needs one WSK order already on a shipment"

        plan = self.new_plan()
        r = self.set_stops(plan["planNo"], [taken], if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        assert taken in str(r.body.get("message", "")), "the refusal did not name the order"
        assert self.sql.lines(plan["planNo"]) == [], "a refused call wrote a line"

    def test_09_cross_warehouse_order_is_refused(self) -> None:
        other = self.sql.scalar(
            "SELECT TOP (1) ORDERKEY FROM DOC_DO_HDR WHERE WHSEID = 'WPD' ORDER BY ORDERKEY")
        assert other, "the baseline needs a WPD order"

        plan = self.new_plan()
        r = self.set_stops(plan["planNo"], [other], if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        assert self.sql.lines(plan["planNo"]) == [], "a WSK plan took a WPD order"

    def test_10_off_route_order_is_refused(self) -> None:
        stray = self.off_route_order()
        plan = self.new_plan()

        r = self.set_stops(plan["planNo"], [stray], if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 422, f"expected 422, got {r.status}: {r.body}"
        assert "ไม่ได้วิ่งผ่าน" in str(r.body.get("message", "")), (
            f"the refusal did not explain the run does not pass that zone: {r.body}")
        assert self.sql.lines(plan["planNo"]) == [], "a refused call wrote a line"
        assert stray in self.pool_ids(), "a refused order left the pool anyway"

    def test_11_wrong_plan_state(self) -> None:
        plan = self.new_plan()
        plan_no = plan["planNo"]
        self.sql.exec(
            f"UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'CANCELLED' WHERE PLANKEY = '{plan_no}';")

        v = self.version_of(plan_no)
        r = self.set_stops(plan_no, [self.pool[0]], if_match=f'"{v}"')
        assert r.status == 409, f"expected 409, got {r.status}: {r.body}"
        assert self.sql.lines(plan_no) == [], "a refused call wrote a line"

        self.sql.exec(
            f"UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'DRAFT' WHERE PLANKEY = '{plan_no}';")

    def test_12_missing_if_match(self) -> None:
        plan = self.new_plan()
        r = self.set_stops(plan["planNo"], [self.pool[0]], if_match=None)
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.lines(plan["planNo"]) == [], "the database was written anyway"

    def test_13_malformed_if_match(self) -> None:
        plan = self.new_plan()
        r = self.set_stops(plan["planNo"], [self.pool[0]], if_match='"not-base64!!"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.lines(plan["planNo"]) == [], "the database was written anyway"

    def test_14_stale_if_match(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[0], self.pool[1]
        v1 = plan["currentVersion"]

        first = self.set_stops(plan["planNo"], [a], if_match=f'"{v1}"')
        assert first.status == 200, f"setup failed: {first.status} {first.body}"
        v2 = first.body["currentVersion"]

        stale = self.set_stops(plan["planNo"], [b], if_match=f'"{v1}"')
        assert stale.status == 409, f"a stale version was accepted: {stale.status} {stale.body}"
        assert stale.body.get("currentVersion") == v2, (
            "the 409 did not hand back the version the first call produced")
        assert self.sql.live_orders(plan["planNo"]) == [a], "the stale write went through"

    def test_15_audit_records_the_change(self) -> None:
        plan = self.new_plan()
        a, b = self.pool[0], self.pool[1]

        first = self.set_stops(plan["planNo"], [a, b], if_match=f'"{plan["currentVersion"]}"',
                               request_id="ss15a")
        assert first.status == 200, f"setup failed: {first.status} {first.body}"

        r = self.set_stops(plan["planNo"], [a], if_match=f'"{first.body["currentVersion"]}"',
                           request_id="ss15b")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        entries = [e for e in self.sql.audits(plan["planNo"]) if "SET_STOPS" in e["metadata"]]
        assert len(entries) == 2, f"expected 2 SET_STOPS audit rows, found {len(entries)}"

        last = entries[-1]
        assert last["action"] == "UPDATED", f"ACTION is {last['action']}"
        assert last["actor"] == self.actor, f"ACTOR is {last['actor']!r}"
        assert last["requestId"] == "ss15b", f"REQUESTID is {last['requestId']!r}"
        assert last["whse"] == "WSK", f"audit WHSEID is {last['whse']}"
        assert b in last["metadata"], "the audit does not record which order was removed"

    def test_16_version_round_trip(self) -> None:
        plan = self.new_plan()
        v1 = plan["currentVersion"]
        r = self.set_stops(plan["planNo"], [self.pool[0]], if_match=f'"{v1}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        v2 = r.body["currentVersion"]
        assert v2 != v1, "the response repeated the version it was sent"
        row = self.sql.plan(plan["planNo"])
        assert base64.b64decode(v2).hex().upper() == row["rowver"][2:], (
            "currentVersion is not the ROWVER the database holds")
        assert row["editwho"] == self.actor, "the plan header records no editor"

        got = self.api.request("GET", f"/transport-plans/{plan['planNo']}", warehouse="WSK")
        assert got.body["currentVersion"] == v2, "a re-read disagrees with the write"
        assert [s["doNo"] for s in got.body["stops"]] == [self.pool[0]], (
            "the plan read does not show what it is holding")

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
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_TRANSPORT_PLAN_LINE") == "0", (
            "plan lines left behind")
        assert self.sql.scalar(
            "SELECT LASTNUMBER FROM TMS_DOCUMENT_NUMBER WHERE PREFIX='PL' AND PERIOD='202608'"
        ) == "1", "the PL counter was not restored"
        assert self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT") == "0", (
            "audit rows left behind")
        assert len(self.pool_ids()) == 10, (
            f"the WSK pool is {len(self.pool_ids())}, baseline is 10 — "
            "an order did not come back")

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        print(f"Plan set stops — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")
        self.pool = self.reachable_orders(2)
        print(f"  ok    {len(self.pool)} WSK orders reachable on {ROUTE_CODE}")

        print("\nthe matrix")
        for name, test in [
            ("01 adds orders and takes them out of the pool", self.test_01_adds_orders),
            ("02 the same set again changes nothing", self.test_02_no_op_same_set),
            ("03 a removed order is CANCELLED, not deleted",
             self.test_03_removed_order_is_cancelled_not_deleted),
            ("04 re-adding revives the same row", self.test_04_re_adding_revives_the_same_row),
            ("05 replacing one order with another", self.test_05_replace_one_with_another),
            ("06 the same order twice counts once", self.test_06_duplicate_order_counts_once),
            ("07 an unknown order is refused", self.test_07_unknown_order_is_refused),
            ("08 an order already claimed is refused by name",
             self.test_08_order_already_claimed_is_refused),
            ("09 another warehouse's order is refused",
             self.test_09_cross_warehouse_order_is_refused),
            ("10 an order off the run is refused (422)", self.test_10_off_route_order_is_refused),
            ("11 a plan that is not a draft is refused", self.test_11_wrong_plan_state),
            ("12 a missing If-Match is refused", self.test_12_missing_if_match),
            ("13 a malformed If-Match is refused", self.test_13_malformed_if_match),
            ("14 a stale If-Match answers 409 with the current version",
             self.test_14_stale_if_match),
            ("15 the audit records what moved", self.test_15_audit_records_the_change),
            ("16 the version round-trips", self.test_16_version_round_trip),
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
