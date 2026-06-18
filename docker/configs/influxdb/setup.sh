#!/bin/sh
# Runs once on first boot via /docker-entrypoint-initdb.d (InfluxDB setup mode).
#
# The DOCKER_INFLUXDB_INIT_* env vars already create the org, admin user, the
# initial bucket (raw_bucket) and the admin token. This script verifies that
# bucket exists and is the place to add anything beyond it — extra buckets,
# retention policies, etc. It is safe to re-run (idempotent).
set -e

ORG="${DOCKER_INFLUXDB_INIT_ORG}"
TOKEN="${DOCKER_INFLUXDB_INIT_ADMIN_TOKEN}"
BUCKET="${DOCKER_INFLUXDB_INIT_BUCKET}"

echo "[rtruth setup] verifying initial bucket '${BUCKET}' in org '${ORG}'..."
if influx bucket list --org "${ORG}" --token "${TOKEN}" --name "${BUCKET}" >/dev/null 2>&1; then
  echo "[rtruth setup] '${BUCKET}' present."
else
  echo "[rtruth setup] WARNING: '${BUCKET}' not found — check INIT env vars."
fi

# --- Add extra buckets here, e.g. a downsampled store:
# influx bucket create --org "${ORG}" --token "${TOKEN}" \
#   --name downsampled --retention 90d
