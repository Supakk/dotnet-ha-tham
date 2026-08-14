#!/usr/bin/env python3
"""Generate development data for the Mammod backend.

Examples:

    python tests/generate_data.py delivery-orders --count 20
    python tests/generate_data.py delivery-orders --count 20 --post
    python tests/generate_data.py fleet --count 3 --post
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import time
from datetime import datetime, timedelta, timezone
from typing import Any
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


JsonObject = dict[str, Any]

WAREHOUSES = ["คลัง MAIN", "คลัง BANGNA", "คลัง LADKRABANG", "คลัง WSK", "คลัง WPD"]
VENDORS = [
    "Northwind Trading",
    "Siam Retail",
    "Bangna Fresh",
    "Makro",
    "Villa Market",
    "Rayong Foods",
    "Ayutthaya Trading",
]
USERS = [
    "สมชาย ใจดี",
    "วิชัย พงษ์ทอง",
    "ประเสริฐ ศรีสุข",
    "ฝ่ายทดสอบ Python",
]
ORDER_STATUSES = ["pending", "in_transit", "delivered", "cancelled"]
VEHICLE_TYPES = ["4-wheel", "6-wheel", "10-wheel"]
LICENSE_TYPES = ["ท.1", "ท.2", "ท.3", "ท.4"]


class ApiClient:
    def __init__(self, base_url: str, timeout: float) -> None:
        self.base_url = base_url.rstrip("/")
        self.timeout = timeout

    def post(self, path: str, body: JsonObject) -> JsonObject:
        request = Request(
            f"{self.base_url}{path}",
            data=json.dumps(body, ensure_ascii=False).encode("utf-8"),
            method="POST",
            headers={"Accept": "application/json", "Content-Type": "application/json"},
        )
        try:
            with urlopen(request, timeout=self.timeout) as response:
                payload = response.read().decode("utf-8")
        except HTTPError as error:
            detail = error.read().decode("utf-8")
            raise RuntimeError(f"POST {path} failed with {error.code}: {detail}") from error
        except URLError as error:
            raise RuntimeError(
                f"Cannot reach {self.base_url}. Start the API with 'dotnet run' first. ({error.reason})"
            ) from error

        parsed = json.loads(payload)
        if not isinstance(parsed, dict):
            raise RuntimeError(f"POST {path} returned non-object JSON: {parsed!r}")
        return parsed


def delivery_orders(count: int, rng: random.Random) -> list[JsonObject]:
    today = datetime.now(timezone.utc).replace(hour=0, minute=0, second=0, microsecond=0)
    rows: list[JsonObject] = []
    for index in range(count):
        created_at = today - timedelta(days=rng.randint(0, 45))
        rows.append(
            {
                "id": "",
                "deliveryNo": "",
                "createdDate": created_at.isoformat().replace("+00:00", "Z"),
                "warehouse": rng.choice(WAREHOUSES),
                "createdBy": rng.choice(USERS),
                "vendor": rng.choice(VENDORS),
                "status": ORDER_STATUSES[index % len(ORDER_STATUSES)],
            }
        )
    return rows


def fleet(count: int, rng: random.Random) -> list[JsonObject]:
    stamp = int(time.time())
    rows: list[JsonObject] = []
    for index in range(1, count + 1):
        carrier_id = f"gen-cr-{stamp}-{index}"
        rows.append(
            {
                "kind": "carrier",
                "path": "/carriers",
                "body": {
                    "id": carrier_id,
                    "code": f"GEN-CR-{stamp % 100000}-{index:03d}",
                    "name": f"Generated Carrier {index}",
                    "type": "subcontract" if index % 2 else "in-house",
                    "contactName": rng.choice(USERS),
                    "phone": f"08{rng.randint(10000000, 99999999)}",
                    "email": f"carrier{index}@example.test",
                    "taxId": f"{rng.randint(1000000000000, 9999999999999)}",
                    "active": True,
                },
            }
        )
        rows.append(
            {
                "kind": "driver",
                "path": "/drivers",
                "body": {
                    "id": f"gen-dr-{stamp}-{index}",
                    "code": f"GEN-DR-{stamp % 100000}-{index:03d}",
                    "name": f"Generated Driver {index}",
                    "phone": f"09{rng.randint(10000000, 99999999)}",
                    "licenseNo": f"DL-{stamp % 100000}-{index:04d}",
                    "licenseType": rng.choice(LICENSE_TYPES),
                    "carrierId": carrier_id,
                    "active": True,
                },
            }
        )
        rows.append(
            {
                "kind": "vehicle",
                "path": "/fleet-vehicles",
                "body": {
                    "id": f"gen-vh-{stamp}-{index}",
                    "type": rng.choice(VEHICLE_TYPES),
                    "plateHead": f"{rng.randint(10, 99)}-{rng.randint(1000, 9999)} กรุงเทพฯ",
                    "plateTrailer": "-" if index % 2 else f"{rng.randint(10, 99)}-{rng.randint(1000, 9999)} กรุงเทพฯ",
                    "carrierId": carrier_id,
                    "maxPayloadKg": rng.choice([3500, 8000, 12000, 15000]),
                    "maxVolumeCbm": rng.choice([12, 24, 35, 45]),
                    "active": True,
                },
            }
        )
    return rows


def print_json(rows: list[JsonObject]) -> None:
    print(json.dumps(rows, ensure_ascii=False, indent=2))


def post_rows(api: ApiClient, rows: list[JsonObject], default_path: str) -> None:
    created = 0
    for row in rows:
        path = row.get("path", default_path)
        body = row.get("body", row)
        if not isinstance(path, str) or not isinstance(body, dict):
            raise RuntimeError(f"invalid generated row: {row!r}")
        result = api.post(path, body)
        created += 1
        label = result.get("id") or result.get("code") or result.get("deliveryNo")
        print(f"created {path}: {label}")
    print(f"\nCreated {created} row(s).")


def main() -> int:
    parser = argparse.ArgumentParser(description="Generate Mammod development data.")
    parser.add_argument("kind", choices=["delivery-orders", "fleet"])
    parser.add_argument("--count", type=int, default=10)
    parser.add_argument("--seed", type=int, default=20260814)
    parser.add_argument("--post", action="store_true", help="POST generated rows to the running API.")
    parser.add_argument("--base-url", default="http://localhost:5080")
    parser.add_argument("--timeout", type=float, default=10)
    args = parser.parse_args()

    if args.count < 1:
        raise SystemExit("--count must be at least 1")

    rng = random.Random(args.seed)
    if args.kind == "delivery-orders":
        rows = delivery_orders(args.count, rng)
        default_path = "/delivery-orders"
    else:
        rows = fleet(args.count, rng)
        default_path = ""

    if args.post:
        post_rows(ApiClient(args.base_url, args.timeout), rows, default_path)
    else:
        print_json(rows)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except RuntimeError as error:
        print(error, file=sys.stderr)
        raise SystemExit(1)
