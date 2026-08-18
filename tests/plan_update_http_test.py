#!/usr/bin/env python3
"""HTTP integration tests for PUT /transport-plans/{id}.

    dotnet run
    py -3 tests/plan_update_http_test.py

Header-only update: delivery date, route and note. What a plan is holding is
changed through {id}/stops, which is a separate slice and is not exercised here.

WHAT IT DOES TO THE DATABASE
----------------------------
Editing needs a plan to edit, and creating one is a commit, so this run raises
its own plans through the existing create endpoint and deletes them afterwards,
putting the PL counter back to 1. The baseline plan PL-202608-0001 is read for
nothing and written for nothing — every test operates on a plan this file made.

The audit-atomicity case injects its failure the same way the invoice suite
does: REQUESTID is nvarchar(64) and the middleware preserves whatever the caller
sent, so an over-long X-Request-Id fails the audit INSERT and nothing else. No
test-only branch exists in the production code.
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
ROUTE_A, ROUTE_B = "rt-RT-NORTH-01", "rt-RT-EAST-01"


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
            "SELECT WHSEID, STATUS, ISNULL(ROUTE,''), CONVERT(varchar(10), DELIVERYDATE, 23), "
            "ISNULL(NOTES,''), ISNULL(EDITWHO,''), "
            "CONVERT(varchar(64), CAST(ROWVER AS binary(8)), 1) "
            f"FROM DOC_TRANSPORT_PLAN WHERE PLANKEY = '{plan_key}'")
        if not rows:
            raise AssertionError(f"{plan_key} is not in DOC_TRANSPORT_PLAN")
        r = rows[0]
        return {"whse": r[0], "status": r[1], "route": r[2], "delivery": r[3],
                "notes": r[4], "editwho": r[5], "rowver": r[6]}

    def updated_audits(self, key: str) -> list[dict[str, str]]:
        """Only UPDATED rows. Raising the plan wrote a CREATED one, and a
        refusal leaving that untouched is correct rather than a leak."""
        return [e for e in self.audits(key) if e["action"] == "UPDATED"]

    def audits(self, key: str) -> list[dict[str, str]]:
        return [
            {"type": r[0], "action": r[1], "frm": r[2], "to": r[3],
             "actor": r[4], "requestId": r[5], "whse": r[6]}
            for r in self.rows(
                "SELECT DOCUMENTTYPE, ACTION, ISNULL(FROMSTATUS,''), ISNULL(TOSTATUS,''), "
                "ACTOR, ISNULL(REQUESTID,''), WHSEID FROM TMS_DOCUMENT_AUDIT "
                f"WHERE DOCUMENTKEY = '{key}' ORDER BY AUDITID")
        ]


class Suite:
    def __init__(self, api: ApiClient, sql: Sql, email: str) -> None:
        self.api, self.sql, self.email = api, sql, email
        self.actor = ""
        self.created: list[str] = []
        self.failures: list[str] = []
        self.passes = 0

    # -- helpers -------------------------------------------------------------

    def new_plan(self, warehouse: str = "WSK", route: str = ROUTE_A,
                 delivery: str = "2026-09-10", note: str = "") -> dict[str, Any]:
        body = {"warehouseCode": warehouse, "deliveryDate": delivery,
                "routeId": route, "note": note}
        r = self.api.request("POST", "/transport-plans", body, warehouse=warehouse)
        assert r.status == 200, f"could not raise a plan to edit: {r.status} {r.body}"
        self.created.append(r.body["planNo"])
        return r.body

    def update(self, plan_no: str, *, warehouse: str = "WSK", route: str = ROUTE_A,
               delivery: str = "2026-09-11", note: str = "",
               if_match: str | None, request_id: str | None = None) -> Response:
        body = {"warehouseCode": warehouse, "deliveryDate": delivery,
                "routeId": route, "note": note}
        return self.api.request("PUT", f"/transport-plans/{plan_no}", body,
                                warehouse=warehouse, if_match=if_match, request_id=request_id)

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

    def test_01_updates_the_header(self) -> None:
        plan = self.new_plan(note="ก่อนแก้")
        v1 = plan["currentVersion"]
        before = self.sql.plan(plan["planNo"])

        r = self.update(plan["planNo"], delivery="2026-09-22",
                        note="หลังแก้", if_match=f'"{v1}"', request_id="planupd01")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        row = self.sql.plan(plan["planNo"])
        assert row["delivery"] == "2026-09-22", f"DELIVERYDATE is {row['delivery']}"
        assert row["notes"] == "หลังแก้", f"NOTES is {row['notes']!r}"
        assert row["status"] == "DRAFT", f"STATUS moved to {row['status']}"
        assert row["editwho"] == self.actor, f"EDITWHO is {row['editwho']!r}"
        assert row["rowver"] != before["rowver"], "ROWVER did not change"

        v2 = r.body["currentVersion"]
        assert v2 != v1, "the response carried the old version"
        assert base64.b64decode(v2).hex().upper() == row["rowver"][2:], (
            f"currentVersion {v2} is not the ROWVER the database holds")
        assert r.body["deliveryDate"] == "2026-09-22"
        assert r.body["note"] == "หลังแก้"

    def test_02_stale_if_match(self) -> None:
        plan = self.new_plan()
        v1 = plan["currentVersion"]

        first = self.update(plan["planNo"], note="ครั้งแรก", if_match=f'"{v1}"')
        assert first.status == 200, f"the first update failed: {first.status} {first.body}"
        v2 = first.body["currentVersion"]

        stale = self.update(plan["planNo"], note="ครั้งที่สอง", if_match=f'"{v1}"')
        assert stale.status == 409, f"a stale version was accepted: {stale.status} {stale.body}"
        assert stale.body.get("currentVersion") == v2, (
            "the 409 did not hand back the version the first update produced")
        assert self.sql.plan(plan["planNo"])["notes"] == "ครั้งแรก", (
            "the stale write went through anyway")

    def test_03_missing_if_match(self) -> None:
        plan = self.new_plan(note="เดิม")
        r = self.update(plan["planNo"], note="ใหม่", if_match=None)
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["notes"] == "เดิม", "the database was written anyway"

    def test_04_malformed_if_match(self) -> None:
        plan = self.new_plan(note="เดิม")
        r = self.update(plan["planNo"], note="ใหม่", if_match='"not-base64!!"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["notes"] == "เดิม", "the database was written anyway"

    def test_05_route_change_is_refused_while_holding_orders(self) -> None:
        """A plan holding nothing may move run; one holding orders may not — yet.

        Changing the run strands the load, and returning it to the pool is a line
        mutation whose semantics are still undecided. The empty case is the one
        that is safe, so it is the one that is allowed.
        """
        plan = self.new_plan(route=ROUTE_A)
        moved = self.update(plan["planNo"], route=ROUTE_B,
                            if_match=f'"{plan["currentVersion"]}"')
        assert moved.status == 200, (
            f"an empty plan could not change run: {moved.status} {moved.body}")
        assert self.sql.plan(plan["planNo"])["route"] == "RT-EAST-01"

    def test_06_wrong_state_is_refused(self) -> None:
        # Only a draft may be edited. Moved directly in SQL because the
        # transition that would do it is a different, unimplemented slice.
        plan = self.new_plan(note="เดิม")
        plan_no = plan["planNo"]
        self.sql.exec(
            f"UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'CANCELLED' WHERE PLANKEY = '{plan_no}';")

        fresh = self.api.request("GET", f"/transport-plans/{plan_no}", warehouse="WSK")
        r = self.update(plan_no, note="ใหม่", if_match=f'"{fresh.body["currentVersion"]}"')

        assert r.status == 409, f"a cancelled plan was edited: {r.status} {r.body}"
        row = self.sql.plan(plan_no)
        assert row["notes"] == "เดิม", "a refused update wrote anyway"
        assert row["status"] == "CANCELLED", "the refusal changed the status"
        assert self.sql.updated_audits(plan_no) == [], "a refusal wrote an UPDATED audit row"

        self.sql.exec(
            f"UPDATE DOC_TRANSPORT_PLAN SET STATUS = 'DRAFT' WHERE PLANKEY = '{plan_no}';")

    def test_07_cross_warehouse(self) -> None:
        plan = self.new_plan("WSK", note="ของ WSK")
        r = self.update(plan["planNo"], warehouse="WPD", note="ถูกแก้ข้ามคลัง",
                        if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 404, f"expected 404, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["notes"] == "ของ WSK", (
            "a WPD request edited a WSK plan")

    def test_08_audit_records_actor_and_request(self) -> None:
        plan = self.new_plan(note="ก่อน")
        r = self.update(plan["planNo"], note="หลัง",
                        if_match=f'"{plan["currentVersion"]}"', request_id="planupd08")
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"

        entries = [e for e in self.sql.audits(plan["planNo"]) if e["action"] == "UPDATED"]
        assert len(entries) == 1, f"expected 1 UPDATED audit row, found {len(entries)}"
        e = entries[0]
        assert e["type"] == "PLAN", f"DOCUMENTTYPE is {e['type']}"
        assert e["frm"] == "DRAFT" and e["to"] == "DRAFT", (
            "the audit row does not record that the status was left alone")
        assert e["actor"] == self.actor, f"ACTOR is {e['actor']!r}"
        assert e["requestId"] == "planupd08", f"REQUESTID is {e['requestId']!r}"
        assert e["whse"] == "WSK", f"audit WHSEID is {e['whse']}"

    def test_09_audit_failure_rolls_back(self) -> None:
        plan = self.new_plan(note="ก่อน")
        before = self.sql.plan(plan["planNo"])

        r = self.update(plan["planNo"], note="หลัง",
                        if_match=f'"{plan["currentVersion"]}"', request_id="x" * 200)
        assert r.status == 500, (
            f"the oversized request id did not fail the audit insert: {r.status} {r.body}")

        row = self.sql.plan(plan["planNo"])
        assert row["notes"] == "ก่อน", "the plan was updated without an audit row"
        assert row["rowver"] == before["rowver"], "the UPDATE committed without the INSERT"
        assert self.sql.updated_audits(plan["planNo"]) == [], "a partial UPDATED audit row survived"

    def test_10_version_round_trip(self) -> None:
        plan = self.new_plan()
        r = self.update(plan["planNo"], note="รอบใหม่",
                        if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 200, f"expected 200, got {r.status}: {r.body}"
        v2 = r.body["currentVersion"]
        assert v2 != plan["currentVersion"], "the response repeated the version it was sent"

        got = self.api.request("GET", f"/transport-plans/{plan['planNo']}", warehouse="WSK")
        assert got.body["currentVersion"] == v2, (
            "a re-read disagrees with the version the update returned")

    def test_11_rejects_a_bad_date(self) -> None:
        plan = self.new_plan(note="เดิม")
        r = self.update(plan["planNo"], delivery="11/09/2026", note="ใหม่",
                        if_match=f'"{plan["currentVersion"]}"')
        assert r.status == 400, f"expected 400, got {r.status}: {r.body}"
        assert self.sql.plan(plan["planNo"])["notes"] == "เดิม", "the database was written anyway"

    # -- teardown ------------------------------------------------------------

    def teardown(self) -> None:
        made = [p for p in dict.fromkeys(self.created) if p != BASELINE_PLAN]
        if made:
            keys = "', '".join(made)
            self.sql.exec(
                f"DELETE FROM TMS_DOCUMENT_AUDIT WHERE DOCUMENTKEY IN ('{keys}');"
                f"DELETE FROM DOC_TRANSPORT_PLAN WHERE PLANKEY IN ('{keys}');")
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
        assert self.sql.scalar(
            "SELECT LASTNUMBER FROM TMS_DOCUMENT_NUMBER WHERE PREFIX='MN' AND PERIOD='202608'"
        ) == "43", "the MN counter moved"
        assert self.sql.scalar("SELECT COUNT(*) FROM TMS_DOCUMENT_AUDIT") == "0", (
            "audit rows left behind")
        assert self.sql.scalar("SELECT COUNT(*) FROM DOC_SHIPMENT_HDR") == "5", (
            "manifest count moved")

    # -- run -----------------------------------------------------------------

    def run(self) -> int:
        print(f"Plan update — {self.api.base_url} against {self.sql.database}\n")
        print("setup")
        self.login()
        print(f"  ok    signed in as {self.actor!r}")

        print("\nthe matrix")
        for name, test in [
            ("01 edits the header and returns a new version", self.test_01_updates_the_header),
            ("02 a stale If-Match answers 409 with the current version", self.test_02_stale_if_match),
            ("03 a missing If-Match is refused", self.test_03_missing_if_match),
            ("04 a malformed If-Match is refused", self.test_04_malformed_if_match),
            ("05 an empty plan may change run", self.test_05_route_change_is_refused_while_holding_orders),
            ("06 a plan that is not a draft cannot be edited", self.test_06_wrong_state_is_refused),
            ("07 another warehouse cannot edit it", self.test_07_cross_warehouse),
            ("08 the audit records actor, request id and warehouse",
             self.test_08_audit_records_actor_and_request),
            ("09 a failing audit rolls the edit back", self.test_09_audit_failure_rolls_back),
            ("10 the version round-trips", self.test_10_version_round_trip),
            ("11 a malformed date is refused", self.test_11_rejects_a_bad_date),
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
