#!/usr/bin/env python3
"""Reference MQTT publisher for the rTruth stack.

This models what the *testharness app* should do: take JSON measurements and
publish them to MQTT in the shape Telegraf expects. Use it as a template for
the real integration, or as a load/smoke generator during development.

See docs/mqtt-contract.md for the topic + payload contract.

Usage:
    pip install paho-mqtt
    python scripts/sample_publisher.py --count 20 --interval 1.0
    python scripts/sample_publisher.py --host localhost --port 1883
"""
import argparse
import json
import math
import random
import time
from datetime import datetime, timezone

import paho.mqtt.client as mqtt

TOPIC_TEMPLATE = "rhobot/testcase/{testId}/{siteId}/{lineId}/{assetId}"

# A small fixed fleet so dashboards have a few series to show.
ASSETS = [
    {"siteId": "site1", "lineId": "line1", "assetId": "asset1", "tagName": "temperature", "unit": "degC"},
    {"siteId": "site1", "lineId": "line1", "assetId": "asset2", "tagName": "pressure",    "unit": "bar"},
    {"siteId": "site1", "lineId": "line2", "assetId": "asset3", "tagName": "flow",        "unit": "lpm"},
    {"siteId": "site2", "lineId": "line1", "assetId": "asset4", "tagName": "temperature", "unit": "degC"},
]


def build_message(asset, test_id, step):
    """Return (topic, payload_dict) for one measurement matching the contract."""
    # A gentle sine wave + noise so the timeseries panel looks alive.
    base = {"temperature": 50.0, "pressure": 3.0, "flow": 120.0}[asset["tagName"]]
    value = base + 5.0 * math.sin(step / 5.0) + random.uniform(-1.0, 1.0)

    payload = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "source": "testharness",
        "testId": test_id,
        "siteId": asset["siteId"],
        "lineId": asset["lineId"],
        "assetId": asset["assetId"],
        "tagName": asset["tagName"],
        "measurementType": "process",
        "unit": asset["unit"],
        "quality": "good",
        "value": round(value, 3),
    }
    topic = TOPIC_TEMPLATE.format(**payload)
    return topic, payload


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--count", type=int, default=20, help="messages per asset (0 = run forever)")
    ap.add_argument("--interval", type=float, default=1.0, help="seconds between rounds")
    ap.add_argument("--test-id", default="t-1024")
    args = ap.parse_args()

    client = mqtt.Client()
    client.connect(args.host, args.port, keepalive=60)
    client.loop_start()
    print(f"Connected to {args.host}:{args.port}; publishing...")

    step = 0
    try:
        while args.count == 0 or step < args.count:
            for asset in ASSETS:
                topic, payload = build_message(asset, args.test_id, step)
                client.publish(topic, json.dumps(payload), qos=0)
            step += 1
            print(f"round {step}: published {len(ASSETS)} messages")
            time.sleep(args.interval)
    except KeyboardInterrupt:
        print("\nstopped.")
    finally:
        client.loop_stop()
        client.disconnect()


if __name__ == "__main__":
    main()
