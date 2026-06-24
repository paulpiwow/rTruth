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

TOPIC_TEMPLATE = (
    "rhobot/testharness/testcase/{testcaseNumber}/{siteName}/{lineName}/{assetName}/{tagName}"
)

# A small fixed fleet so dashboards have a few series to show. Tag naming
# follows the convention CV -> x_NN, SP -> y_NN, PV -> z_NN.
ASSETS = [
    {"siteName": "Site1", "lineName": "Line1", "assetName": "Asset1", "tagName": "x_01", "measurementType": "CV", "unit": "%"},
    {"siteName": "Site1", "lineName": "Line1", "assetName": "Asset1", "tagName": "y_01", "measurementType": "SP", "unit": "%"},
    {"siteName": "Site1", "lineName": "Line1", "assetName": "Asset1", "tagName": "z_01", "measurementType": "PV", "unit": "degC"},
    {"siteName": "Site1", "lineName": "Line2", "assetName": "Asset2", "tagName": "z_02", "measurementType": "PV", "unit": "bar"},
    {"siteName": "Site2", "lineName": "Line1", "assetName": "Asset3", "tagName": "z_03", "measurementType": "PV", "unit": "degC"},
]


def build_message(asset, testcase_number, step):
    """Return (topic, payload_dict) for one measurement matching the contract."""
    # A gentle sine wave + noise so the timeseries panel looks alive.
    base = {"CV": 50.0, "SP": 75.0, "PV": 50.0}[asset["measurementType"]]
    value = base + 5.0 * math.sin(step / 5.0) + random.uniform(-1.0, 1.0)

    payload = {
        "timestamp": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "testcaseNumber": testcase_number,
        "siteName": asset["siteName"],
        "lineName": asset["lineName"],
        "assetName": asset["assetName"],
        "tagName": asset["tagName"],
        "measurementType": asset["measurementType"],
        "value": round(value, 3),
        "unit": asset["unit"],
        "status": "GOOD",
    }
    topic = TOPIC_TEMPLATE.format(testcaseNumber=testcase_number, **asset)
    return topic, payload


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--host", default="localhost")
    ap.add_argument("--port", type=int, default=1883)
    ap.add_argument("--count", type=int, default=20, help="messages per asset (0 = run forever)")
    ap.add_argument("--interval", type=float, default=1.0, help="seconds between rounds")
    ap.add_argument("--testcase-number", type=int, default=1, dest="testcase_number")
    args = ap.parse_args()

    client = mqtt.Client()
    client.connect(args.host, args.port, keepalive=60)
    client.loop_start()
    print(f"Connected to {args.host}:{args.port}; publishing...")

    step = 0
    try:
        while args.count == 0 or step < args.count:
            for asset in ASSETS:
                topic, payload = build_message(asset, args.testcase_number, step)
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
