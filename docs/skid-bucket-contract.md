# Skid bucket contract

## What this is

`skid_bucket` is a new storage area (a "bucket", which in InfluxDB 3 is just a
database) inside rTruth's InfluxDB. It is where the **skid simulator's** live
sensor readings will land, kept separate from the existing `raw_bucket` (which
holds test-harness data).

This document describes the **shape** of that data — the set of labels every
reading carries. That shape is a shared agreement: rPulse, and the InfluxDB
connector that reads for it, all rely on it to match a stored piece of equipment
configuration to its live readings.

## Why it exists now (and what is *not* being built)

Building the skid simulator itself is **Phase 5**, which we are skipping for now.
The only thing Phase 6 (rPulse alarms) needs from Phase 5 is this destination —
Phase 5's "Ticket 6": *give rTruth a bucket, measurement, and tag/field schema to
persist the incoming time-series data.* So we build just that tail end.

Not built here: the simulator program, its MQTT topics, the Telegraf ingest of
those topics, and Grafana views. Those are the rest of Phase 5.

## Why a separate bucket

The existing `raw_bucket` is fed by the test harness and its readings are labeled
`siteName, lineName, assetName, tagName` — it has **no** machine or data-source
label. rPulse's stored hierarchy is `site -> asset -> machine -> data_source ->
tag`. Those two didn't line up. The skid bucket is our chance to define the labels
from scratch so they match rPulse exactly.

## The shape (measurement + tags + field)

- **Measurement (table):** `skid_measurement`
- **Tags (the equipment hierarchy — how each reading is addressed):**

  | Tag | Meaning | Matches rPulse's |
  | --- | --- | --- |
  | `siteName` | the overall site | `site` |
  | `assetName` | the equipment package | `asset` |
  | `machineName` | a sub-unit of the asset | `machine` |
  | `dataSourceName` | the specific feed/endpoint | `data_source` |
  | `tagName` | the individual signal | `tag` |

- **Field (the actual data):** `value` — the number the sensor reported.
- **Time:** every reading is timestamped (InfluxDB adds this).

Note there is intentionally **no `lineName`**. `line` is an rPipes concept, and
the skid stream does not feed rPipes (per the Phase 5 doc it is for rPulse alarm
analysis only), so the skid bucket does not carry it.

## How to create it

With the rTruth stack running (`docker compose up -d`):

```
./scripts/create-skid-bucket.sh
```

InfluxDB 3 creates the database and table on first write, so that one command is
enough. Re-running it is harmless — it just adds another sample reading.

## Open decision (needs the team)

**Match by name or by code?** The tags above use human names (`Suction Pressure`),
matching the existing `raw_bucket` style and the connector's current filters.
rPulse also stores a stable short code for each item (e.g. `suct-press`) that never
changes when something is renamed. If we want the two sides to match on that stable
code instead of the name, we would add code tags (e.g. `tagCode`, `assetCode`) here.
Recommended, but left open until the team confirms — adding tags later is easy and
does not break anything already reading the bucket.
