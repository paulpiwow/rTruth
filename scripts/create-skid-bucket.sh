#!/usr/bin/env bash
#
# Creates the "skid_bucket" in rTruth's InfluxDB.
#
# Plain-English picture: this is the storage spot that will hold the live readings
# coming from the skid simulator (the fake sensor generator). We are NOT building
# the simulator yet — that's the rest of Phase 5. All Phase 6 (rPulse alarms) needs
# from Phase 5 is this destination to exist with the right shape.
#
# InfluxDB 3 makes a database and its table automatically the first time you write
# to them, so writing a single sample reading is all it takes to (1) create the
# bucket and (2) lock in the set of labels every reading will carry. That set of
# labels is the important part — it's the agreed shape that lets rPulse's stored
# settings line up with these live readings. See docs/skid-bucket-contract.md.
#
# Usage:  ./scripts/create-skid-bucket.sh
# The rTruth stack (docker compose up) must be running first.

set -euo pipefail

# Where InfluxDB is and what we're writing to. These can be overridden with
# environment variables; the defaults match this project's .env.example.
INFLUX_URL="${INFLUX_URL:-http://localhost:${INFLUX_PORT:-8087}}"
INFLUX_ORG="${INFLUX_ORG:-rhobot}"
INFLUX_TOKEN="${INFLUX_TOKEN:-dev-rtruth-token}"
SKID_BUCKET="${SKID_BUCKET:-skid_bucket}"

# One sample reading, written in InfluxDB's "line protocol" text format:
#   skid_measurement          -> the table name
#   the comma-separated pairs  -> the equipment-hierarchy labels (tags)
#   value=51.5                 -> the actual number the sensor reported (a field)
# The "\ " is how line protocol escapes the spaces inside a label value.
LINE='skid_measurement,siteName=Cadre\ Compressor\ Skid,assetName=Cadre\ Compressor\ Skid,machineName=EMIT\ DCT\ Panel,dataSourceName=EMIT\ DCT\ Panel,tagName=Suction\ Pressure value=51.5'

echo "Creating '${SKID_BUCKET}' at ${INFLUX_URL} by writing one sample reading..."
curl -sS -X POST \
  "${INFLUX_URL}/api/v2/write?org=${INFLUX_ORG}&bucket=${SKID_BUCKET}&precision=ns" \
  -H "Authorization: Token ${INFLUX_TOKEN}" \
  --data-binary "${LINE}"

echo "Done. '${SKID_BUCKET}' now exists with the table 'skid_measurement'."
