#!/usr/bin/env bash
# Fire a handful of contract-compliant test messages through the running
# Mosquitto container — zero dependencies, no app needed. Useful for a quick
# "is the pipeline alive?" check. For continuous/realistic data use
# scripts/sample_publisher.py instead.
#
# Usage:  ./scripts/send-test-messages.sh [rounds]
set -euo pipefail

ROUNDS="${1:-10}"
ASSETS=(
  "site1 line1 asset1 temperature degC"
  "site1 line1 asset2 pressure bar"
  "site1 line2 asset3 flow lpm"
  "site2 line1 asset4 temperature degC"
)

echo "Publishing ${ROUNDS} rounds to mqtt (rhobot/testcase/...)"
for ((r = 1; r <= ROUNDS; r++)); do
  for a in "${ASSETS[@]}"; do
    read -r site line asset tag unit <<<"$a"
    ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
    value="$(awk -v s="$r" 'BEGIN{srand(); printf "%.3f", 50 + 5*sin(s/5.0) + (rand()*2-1)}')"
    topic="rhobot/testcase/t-1024/${site}/${line}/${asset}"
    payload="{\"timestamp\":\"${ts}\",\"source\":\"testharness\",\"testId\":\"t-1024\",\"siteId\":\"${site}\",\"lineId\":\"${line}\",\"assetId\":\"${asset}\",\"tagName\":\"${tag}\",\"measurementType\":\"process\",\"unit\":\"${unit}\",\"quality\":\"good\",\"value\":${value}}"
    docker compose exec -T mosquitto mosquitto_pub -h localhost -t "$topic" -m "$payload"
  done
  echo "round ${r}/${ROUNDS} sent"
  sleep 1
done
echo "done."
