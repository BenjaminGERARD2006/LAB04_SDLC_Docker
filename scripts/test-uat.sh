#!/usr/bin/env bash
set -euo pipefail
TARGET_URL="${TARGET_URL:-http://localhost:4173}"

echo "[UAT] Verifying UI static assets (/, /app.js, /styles.css)..."
for path in "/" "/app.js" "/styles.css"; do
  STATUS=$(curl -s -o /dev/null -w "%{http_code}" "${TARGET_URL}${path}")
  [ "${STATUS}" -eq 200 ] || { echo "FAIL: Asset ${path} returned HTTP ${STATUS}"; exit 1; }
done

echo "[UAT] Scenario 1: Valid reservation at Central Square (8 bikes)..."
RES_CODE=$(curl -s -o /tmp/uat_res.json -w "%{http_code}" -X POST "${TARGET_URL}/api/reservations" \
  -H "Content-Type: application/json" \
  -d '{"stationId":"central","email":"rider@example.com"}')
[ "${RES_CODE}" -eq 201 ] || { echo "FAIL: Expected 201 for valid reservation, got ${RES_CODE}"; exit 1; }
grep -q '"reservationId":"CB-CENTRAL"' /tmp/uat_res.json || { echo "FAIL: Missing or malformed reservation ID in response"; exit 1; }

echo "[UAT] Scenario 2: Reject reservation with invalid email format..."
EMAIL_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET_URL}/api/reservations" \
  -H "Content-Type: application/json" \
  -d '{"stationId":"central","email":"not-an-email"}')
[ "${EMAIL_CODE}" -eq 422 ] || { echo "FAIL: Invalid email should return 422, got ${EMAIL_CODE}"; exit 1; }

echo "[UAT] Scenario 3: Reject reservation at zero-bike station (Riverside Park)..."
BIKE_CODE=$(curl -s -o /dev/null -w "%{http_code}" -X POST "${TARGET_URL}/api/reservations" \
  -H "Content-Type: application/json" \
  -d '{"stationId":"riverside","email":"rider@example.com"}')
[ "${BIKE_CODE}" -eq 422 ] || { echo "FAIL: Zero-bike station should return 422, got ${BIKE_CODE}"; exit 1; }

echo "[UAT] PASSED."
