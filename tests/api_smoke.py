#!/usr/bin/env python3
"""Smoke tests for the Mammod .NET backend API.

Run this while the backend is listening on http://localhost:5080:

    python tests/api_smoke.py

The script uses only Python's standard library so it can live beside the C#
project without adding runtime dependencies.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
from dataclasses import dataclass
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.parse import urlencode
from urllib.request import Request, urlopen


Json = dict[str, Any] | list[Any] | str | int | float | bool | None


@dataclass
class ApiResponse:
    status: int
    body: Json


class ApiClient:
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
        query: dict[str, str | int] | None = None,
        expect: int | range = range(200, 300),
    ) -> ApiResponse:
        url = f"{self.base_url}{path}"
        if query:
            url = f"{url}?{urlencode(query)}"

        data = None
        headers = {"Accept": "application/json"}
        if body is not None:
            data = json.dumps(body).encode("utf-8")
            headers["Content-Type"] = "application/json"
        if self.access_token:
            headers["Authorization"] = f"Bearer {self.access_token}"

        request = Request(url, data=data, method=method.upper(), headers=headers)
        try:
            with urlopen(request, timeout=self.timeout) as response:
                status = response.status
                payload = self._read_json(response.read())
        except HTTPError as error:
            status = error.code
            payload = self._read_json(error.read())
        except URLError as error:
            raise AssertionError(
                f"Cannot reach {self.base_url}. Start the API with 'dotnet run' first. ({error.reason})"
            ) from error

        ok = status in expect if isinstance(expect, range) else status == expect
        if not ok:
            raise AssertionError(
                f"{method.upper()} {path} returned {status}, expected {expect}: {payload}"
            )
        return ApiResponse(status, payload)

    @staticmethod
    def _read_json(raw: bytes) -> Json:
        if not raw:
            return None
        text = raw.decode("utf-8")
        try:
            return json.loads(text)
        except json.JSONDecodeError:
            return text


class SmokeSuite:
    def __init__(self, api: ApiClient, email: str) -> None:
        self.api = api
        self.email = email
        self.results: list[tuple[str, str, str]] = []

    def run(self) -> int:
        tests = [
            ("auth issues a usable access token", self.auth_token),
            ("master data endpoints return seeded data", self.master_data),
            ("business rule rejects duplicate carrier code", self.duplicate_carrier_code),
            ("transport plan to manifest lifecycle works", self.transport_lifecycle),
        ]

        for name, test in tests:
            started = time.perf_counter()
            try:
                note = test()
            except AssertionError as error:
                self.results.append(("FAIL", name, str(error)))
            else:
                elapsed_ms = (time.perf_counter() - started) * 1000
                suffix = f"{elapsed_ms:.0f} ms"
                if note:
                    suffix = f"{suffix}; {note}"
                self.results.append(("PASS", name, suffix))

        for status, name, detail in self.results:
            print(f"{status:4} {name} ({detail})")

        failed = [name for status, name, _ in self.results if status == "FAIL"]
        if failed:
            print(f"\n{len(failed)} smoke test(s) failed.", file=sys.stderr)
            return 1

        print("\nAll smoke tests passed.")
        return 0

    def auth_token(self) -> str:
        response = self.api.request(
            "POST",
            "/auth/login",
            {"email": self.email, "password": "test-only"},
        ).body
        assert isinstance(response, dict), "login did not return a JSON object"
        token = response.get("accessToken")
        assert isinstance(token, str) and token, "login response has no accessToken"
        self.api.access_token = token

        me = self.api.request("GET", "/auth/me").body
        assert isinstance(me, dict), "/auth/me did not return a user"
        assert me.get("email") == self.email, f"/auth/me returned {me.get('email')!r}"
        return f"user={me.get('id')}"

    def master_data(self) -> str:
        endpoints = [
            "/warehouses",
            "/delivery-zones",
            "/routes",
            "/carriers",
            "/fleet-vehicles",
            "/drivers",
            "/geo/provinces",
            "/integration/messages",
            "/integrations/configs",
            "/delivery-orders",
        ]
        counts: dict[str, int] = {}
        for endpoint in endpoints:
            body = self.api.request("GET", endpoint).body
            if isinstance(body, dict) and "items" in body:
                items = body["items"]
            else:
                items = body
            assert isinstance(items, list), f"{endpoint} did not return a list"
            counts[endpoint] = len(items)

        required = ["/warehouses", "/delivery-zones", "/routes", "/carriers", "/drivers"]
        missing = [endpoint for endpoint in required if counts[endpoint] == 0]
        assert not missing, f"missing seeded data for {', '.join(missing)}"
        return ", ".join(f"{key}={value}" for key, value in counts.items())

    def duplicate_carrier_code(self) -> str:
        carriers = self._list("/carriers")
        assert carriers, "no carrier seed data available"
        existing = carriers[0]

        duplicate = {
            "id": "",
            "code": existing["code"],
            "name": "Python smoke duplicate",
            "type": existing.get("type", "subcontract"),
            "contactName": "",
            "phone": "",
            "email": "",
            "taxId": "",
            "active": True,
        }
        response = self.api.request("POST", "/carriers", duplicate, expect=400)
        assert isinstance(response.body, dict), "duplicate rejection did not return JSON"
        assert response.body.get("message"), "duplicate rejection did not include message"
        return f"code={existing['code']}"

    def transport_lifecycle(self) -> str:
        pending = self._list("/manifests/pending-stops")
        if not pending:
            return "skipped: no pending stops; restart dotnet run to reseed in-memory data"

        stop_ids = [stop["id"] for stop in pending[:2]]
        first_stop = pending[0]

        plan = self.api.request(
            "POST",
            "/transport-plans",
            {
                "warehouseCode": first_stop["warehouseCode"],
                "deliveryDate": first_stop.get("dueDate", "2026-08-09"),
                "deliveryZoneId": first_stop["deliveryZoneId"],
                "note": "python smoke test",
            },
        ).body
        assert isinstance(plan, dict) and plan.get("id"), "plan creation failed"

        plan_id = plan["id"]
        planned = self.api.request(
            "PUT", f"/transport-plans/{plan_id}/stops", {"stopIds": stop_ids}
        ).body
        assert isinstance(planned, dict), "setting plan stops failed"
        assert {stop["id"] for stop in planned.get("stops", [])} == set(stop_ids)

        issue = self.api.request("POST", f"/transport-plans/{plan_id}/issue").body
        assert isinstance(issue, dict), "plan issue did not return JSON"
        manifest = issue.get("manifest")
        assert isinstance(manifest, dict) and manifest.get("id"), "issue returned no manifest"

        manifest_id = manifest["id"]
        rejected = self.api.request(
            "POST", f"/manifests/{manifest_id}/confirm", expect=400
        ).body
        assert isinstance(rejected, dict) and rejected.get("message"), (
            "unassigned confirm was not rejected with a message"
        )

        manifest = self._assign_manifest(manifest)
        assert manifest["freightCost"] == 1300, "server did not derive freightCost from pricing"

        confirmed = self.api.request("POST", f"/manifests/{manifest_id}/confirm").body
        assert isinstance(confirmed, dict) and confirmed.get("status") == "confirmed"

        sent = self.api.request("POST", f"/manifests/{manifest_id}/send").body
        assert isinstance(sent, dict) and sent.get("status") == "sent"

        self.api.request("PUT", f"/manifests/{manifest_id}", {"stops": []}, expect=400)

        completed = self.api.request(
            "POST",
            f"/manifests/{manifest_id}/status",
            {"outcome": "completed", "message": "Python smoke test completed"},
        ).body
        assert isinstance(completed, dict) and completed.get("status") == "completed"
        return f"manifest={completed.get('manifestNo')}"

    def _assign_manifest(self, manifest: dict[str, Any]) -> dict[str, Any]:
        routes = self._list("/routes")
        carriers = self._list("/carriers")
        vehicles = self._list("/fleet-vehicles")
        drivers = self._list("/drivers")
        assert routes and carriers and vehicles and drivers, "missing assignment master data"

        zone_ids = {stop["deliveryZoneId"] for stop in manifest.get("stops", [])}
        route = next(
            (
                item
                for item in routes
                if zone_ids.intersection(set(item.get("deliveryZoneIds", [])))
            ),
            routes[0],
        )
        vehicle = vehicles[0]
        carrier = next(
            (item for item in carriers if item.get("id") == vehicle.get("carrierId")),
            carriers[0],
        )
        driver = next(
            (item for item in drivers if item.get("carrierId") == carrier.get("id")),
            drivers[0],
        )

        payload = {
            "warehouseCode": manifest["warehouseCode"],
            "createdBy": manifest.get("createdBy", "python smoke"),
            "deliveryDate": manifest["deliveryDate"],
            "driverId": driver["id"],
            "driverName": driver["name"],
            "driverPhone": driver.get("phone", ""),
            "plateHead": vehicle["plateHead"],
            "plateTrailer": vehicle.get("plateTrailer", "-"),
            "vehicle": vehicle["type"],
            "assistantCount": 1,
            "maxPayloadKg": vehicle.get("maxPayloadKg", 0),
            "maxVolumeCbm": vehicle.get("maxVolumeCbm", 0),
            "carrierId": carrier["id"],
            "carrier": carrier["name"],
            "routeId": route["id"],
            "routeCode": route["code"],
            "routeName": route["name"],
            "origin": route["defaultOrigin"],
            "dock": "Smoke Dock",
            "sealNo": f"SMK-{int(time.time())}",
            "pricing": {
                "tripPrice": 1234,
                "priceAdd": 100,
                "priceDeduct": 34,
                "freightNote": "python smoke test",
            },
            "stops": manifest.get("stops", []),
        }
        updated = self.api.request("PUT", f"/manifests/{manifest['id']}", payload).body
        assert isinstance(updated, dict), "manifest assignment did not return JSON"
        return updated

    def _list(self, endpoint: str) -> list[dict[str, Any]]:
        body = self.api.request("GET", endpoint).body
        assert isinstance(body, list), f"{endpoint} did not return a list"
        return body


def main() -> int:
    parser = argparse.ArgumentParser(description="Run Mammod backend API smoke tests.")
    parser.add_argument("--base-url", default="http://localhost:5080")
    parser.add_argument("--email", default="tms@mammod.co")
    parser.add_argument("--timeout", type=float, default=10)
    args = parser.parse_args()

    suite = SmokeSuite(ApiClient(args.base_url, args.timeout), args.email)
    return suite.run()


if __name__ == "__main__":
    raise SystemExit(main())
