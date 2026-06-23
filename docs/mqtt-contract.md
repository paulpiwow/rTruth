# MQTT message contract

This is the contract between the **testharness app** (publisher) and the
**rTruth stack** (Telegraf → InfluxDB → Grafana). As long as the testharness
publishes messages in this shape, they will be ingested automatically — no
changes needed on the rTruth side.

The mapping below is enforced by `configs/telegraf/telegraf.conf`.

## Topic

```
rhobot/testharness/testcase/<testcaseNumber>/<siteName>/<lineName>/<assetName>/<tagName>
```

`rhobot/testharness/testcase` is the fixed prefix. Telegraf subscribes to
`rhobot/testharness/testcase/+/+/+/+/+` (exactly five trailing segments). The
segments are for routing/readability; the values that actually get stored come
from the JSON body, not the topic.

## Payload (JSON)

One measurement per message, 10 fields:

```json
{
  "timestamp": "2026-06-22T14:30:00Z",
  "testcaseNumber": 1,
  "siteName": "Site1",
  "lineName": "Line1",
  "assetName": "Asset1",
  "tagName": "x_01",
  "measurementType": "CV",
  "value": 42.5,
  "unit": "degC",
  "status": "GOOD"
}
```

### Field reference

| JSON key          | Stored as        | Notes                                            |
|-------------------|------------------|--------------------------------------------------|
| `timestamp`       | point time       | RFC3339 / ISO-8601 (`2006-01-02T15:04:05Z07:00`) |
| `testcaseNumber`  | tag              | the test-case run number                         |
| `siteName`        | tag              |                                                  |
| `lineName`        | tag              |                                                  |
| `assetName`       | tag              |                                                  |
| `measurementType` | tag              | one of `CV`, `SP`, `PV`                          |
| `unit`            | tag              |                                                  |
| `status`          | tag              | quality flag — `GOOD` in v1                       |
| `tagName`         | field (string)   | the signal name, e.g. `x_01`                     |
| `value`           | field (number)   | the numeric reading                              |

Everything lands in InfluxDB database **`raw_bucket`**, table (measurement)
**`raw_measurement`**.

> Tags are indexed and good for filtering/grouping (site, asset, test case).
> Fields hold the actual values (`value`, `tagName`). If you need a new
> filterable dimension, add it to `tag_keys` in `telegraf.conf`.

## Try it

Send a few sample messages through the running broker (no app needed yet):

```bash
./scripts/send-test-messages.sh
```

Or model the real testharness publisher with the Python reference:

```bash
pip install paho-mqtt
python scripts/sample_publisher.py --count 20
```
