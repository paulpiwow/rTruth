#!/usr/bin/env bash
# Fire a handful of contract-compliant test messages through the running
# Mosquitto container — zero dependencies, no app needed. Useful for a quick
# "is the pipeline alive?" check. For continuous/realistic data use
# scripts/sample_publisher.py instead.
#
# Usage:  ./scripts/send-test-messages.sh [rounds]
set -euo pipefail

ROUNDS="${1:-10}"
TESTCASE=1
# Each row: siteName lineName assetName tagName measurementType unit
ASSETS=(
  "Site1 Line1 Asset1 x_01 CV %"
  "Site1 Line1 Asset1 y_01 SP %"
  "Site1 Line1 Asset1 z_01 PV degC"
  "Site1 Line2 Asset2 z_02 PV bar"
  "Site2 Line1 Asset3 z_03 PV degC"
)

echo "Publishing ${ROUNDS} rounds to mqtt (rhobot/testharness/testcase/...)"
for ((r = 1; r <= ROUNDS; r++)); do
  for a in "${ASSETS[@]}"; do
    read -r site line asset tag mtype unit <<<"$a"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    value="$(awk -v s="$r" 'BEGIN{srand(); printf "%.3f", 50 + 5*sin(s/5.0) + (rand()*2-1)}')"
    topic="rhobot/testharness/testcase/${TESTCASE}/${site}/${line}/${asset}/${tag}"
    payload="{\"timestamp\":\"${ts}\",\"testcaseNumber\":${TESTCASE},\"siteName\":\"${site}\",\"lineName\":\"${line}\",\"assetName\":\"${asset}\",\"tagName\":\"${tag}\",\"measurementType\":\"${mtype}\",\"value\":${value},\"unit\":\"${unit}\",\"status\":\"GOOD\"}"
    docker compose exec -T mosquitto mosquitto_pub -h localhost -t "$topic" -m "$payload"
  done
  echo "round ${r}/${ROUNDS} sent"
  sleep 1
done
echo "done."
