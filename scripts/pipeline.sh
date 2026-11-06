#!/usr/bin/env bash
set -Eeuo pipefail

IMAGE_NAME="${1:-citybike:v1}"
PROD_API_KEY="${PROD_API_KEY:-lab-secret}"
TARGET_URL="http://localhost:4173"
CURRENT_CONTAINER=""

echo "======================================"
echo " CITYBIKE SDLC PROMOTION PIPELINE"
echo " Image: ${IMAGE_NAME}"
echo "======================================"

if ! docker image inspect "$IMAGE_NAME" >/dev/null 2>&1; then
  echo "ERROR: Image ${IMAGE_NAME} does not exist."
  exit 1
fi

run_gate() {
  local gate="$1"
  local app_env="$2"
  local test_script="$3"
  local container="citybike-gate-${gate}"

  echo ""
  echo "========== ${gate^^} GATE =========="

  docker rm -f "$container" >/dev/null 2>&1 || true

  CURRENT_CONTAINER="$container"

  docker run -d \
    --name "$container" \
    -p 4173:4173 \
    -e APP_ENV="$app_env" \
    -e PROD_API_KEY="$PROD_API_KEY" \
    "$IMAGE_NAME" >/dev/null

  local ready=0

  for i in $(seq 1 30); do
    if curl -fsS "${TARGET_URL}/health" >/dev/null 2>&1; then
      ready=1
      break
    fi
    sleep 1
  done

  if [ "$ready" -ne 1 ]; then
    echo "FAIL: ${gate^^} container did not become healthy."
    docker logs "$container" || true
    docker rm -f "$container" >/dev/null 2>&1 || true
    CURRENT_CONTAINER=""
    return 1
  fi

  if ! TARGET_URL="$TARGET_URL" \
       IMAGE_NAME="$IMAGE_NAME" \
       bash "scripts/test-${test_script}.sh"; then
    echo "FAIL: ${gate^^} gate rejected ${IMAGE_NAME}."
    docker logs "$container" || true
    docker rm -f "$container" >/dev/null 2>&1 || true
    CURRENT_CONTAINER=""
    return 1
  fi

  if [ "$gate" = "production" ]; then
    echo "PRODUCTION container remains running."
  else
    docker rm -f "$container" >/dev/null
  fi

  CURRENT_CONTAINER=""
  echo "GREEN: ${gate^^} gate passed."
}

run_gate staging staging staging
run_gate uat uat uat
run_gate oat oat oat
run_gate preprod preprod preprod
run_gate production production prod

echo ""
echo "======================================"
echo " ALL FIVE GATES PASSED"
echo " PROMOTION COMPLETE"
echo "======================================"

docker ps --filter name=citybike-gate-production
