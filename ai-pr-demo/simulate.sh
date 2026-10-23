#!/usr/bin/env bash
# Posts a sample Turbonomic action payload to the local webhook service, so
# you can run the full AI -> Terraform edit -> PR flow without a live
# Turbonomic instance. Start the service first: cd webhook-service && npm start
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PORT="${PORT:-4000}"

curl -sS -X POST "http://localhost:${PORT}/webhook" \
  -H "Content-Type: application/json" \
  --data @"${DIR}/sample-payloads/scale-action.json"
echo
echo "Webhook accepted. Watch the webhook-service logs for Claude Code's progress."
