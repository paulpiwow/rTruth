# MQTT message contract

This is the contract between the **testharness app** (publisher) and the
**rTruth stack** (Telegraf → InfluxDB → Grafana). As long as the testharness
publishes messages in this shape, they will be ingested automatically — no
changes needed on the rTruth side.

The mapping below is enforced by `configs/telegraf/telegraf.conf`.

## Topic

```
rhobot/testcase/<testId>/<siteId>/<lineId>/<assetId>
```

Telegraf subscribes to `rhobot/testcase/+/+/+/+` (exactly four trailing
segments). The segments are for routing/readability; the values that actually
get stored come from the JSON body, not the topic.

## Payload (JSON)

One measurement per message:

```json
{
  "timestamp": "2026-06-22T14:30:00Z",
  "source": "testharness",
  "testId": "t-1024",
  "siteId": "site1",
  "lineId": "line1",
  "assetId": "asset1",
  "tagName": "temperature",
  "measurementType": "process",
  "unit": "degC",
  "quality": "good",
  "value": 42.5
}
```

### Field reference

| JSON key          | Stored as        | Notes                                            |
|-------------------|------------------|--------------------------------------------------|
| `timestamp`       | point time       | RFC3339 / ISO-8601 (`2006-01-02T15:04:05Z07:00`) |
| `source`          | tag              |                                                  |
| `testId`          | tag              |                                                  |
| `siteId`          | tag              |                                                  |
| `lineId`          | tag              |                                                  |
| `assetId`         | tag              |                                                  |
| `tagName`         | tag              | the signal name, e.g. `temperature`              |
| `measurementType` | tag              |                                                  |
| `unit`            | tag              |                                                  |
| `quality`         | field (string)   |                                                  |
| `value`           | field (number)   | the numeric reading                              |

Everything lands in InfluxDB database **`raw_bucket`**, table (measurement)
**`raw_measurement`**.

> Tags are indexed and good for filtering/grouping (site, asset, tag name).
> Fields hold the actual values (`value`, `quality`). If you need a new
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
