#!/usr/bin/env bash
# Queries a live Turbonomic instance for pending cloud VM scale actions, and
# saves one as a payload file Claude Code can process (Variant A in
# DEMO_SCRIPT.md).
#
#   bash turbo-actions.sh                # list pending actions on $TURBO_TARGET
#   bash turbo-actions.sh --all          # list pending actions on every cloud target
#   bash turbo-actions.sh --save <uuid>  # write that action to live-payloads/action-<uuid>.json
#
# Auth: logs in with TURBO_USERNAME / TURBO_PASSWORD. In a Claude Code cloud
# session that has a "Body parameter" network secret (username/password) for
# the Turbonomic host, leave them unset and the proxy injects the real values.
# Every call is a POST, because that secret can't attach to a GET (no body).
set -euo pipefail
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST="${TURBO_HOST:-salesdemo01.customer.turbonomic.ibmappdomain.cloud}"
TARGET="${TURBO_TARGET:-AWS-steve-demo}"
SAVE_UUID=""

usage() { sed -n '6,8p' "${BASH_SOURCE[0]}" | sed 's/^# //'; }
case "${1:-}" in
  "") ;;
  --all) TARGET="" ;;
  --save) SAVE_UUID="${2:-}"; [[ -n "$SAVE_UUID" ]] || { usage; exit 2; } ;;
  *) usage; exit 2 ;;
esac

JAR="$(mktemp)"
trap 'rm -f "$JAR"' EXIT

curl -fsS -c "$JAR" -o /dev/null -X POST \
  --data-urlencode "username=${TURBO_USERNAME:-injected-by-proxy}" \
  --data-urlencode "password=${TURBO_PASSWORD:-injected-by-proxy}" \
  "https://${HOST}/api/v3/login"

ACTIONS="$(curl -fsS -b "$JAR" -X POST -H 'Content-Type: application/json' \
  --data '{"actionStateList":["READY"],"environmentType":"CLOUD","actionTypeList":["SCALE"],"relatedEntityTypes":["VirtualMachine"]}' \
  "https://${HOST}/api/v3/markets/Market/actions?limit=500" |
  jq --arg t "$TARGET" '[.[] | select($t == "" or .target.discoveredBy.displayName == $t)]')"

if [[ -n "$SAVE_UUID" ]]; then
  ACTION="$(jq --arg u "$SAVE_UUID" '.[] | select(.uuid == $u)' <<<"$ACTIONS")"
  [[ -n "$ACTION" ]] || { echo "No pending action with uuid $SAVE_UUID${TARGET:+ on target $TARGET}" >&2; exit 1; }
  mkdir -p "$DIR/live-payloads"
  OUT="$DIR/live-payloads/action-${SAVE_UUID}.json"
  printf '%s\n' "$ACTION" >"$OUT"
  echo "Saved ${OUT#"$DIR"/}"
  exit 0
fi

COUNT="$(jq length <<<"$ACTIONS")"
echo "${COUNT} pending cloud VM scale action(s)${TARGET:+ on target ${TARGET}}:"
[[ "$COUNT" -gt 0 ]] || exit 0
jq -r '(["ACTION_UUID", "VM", "CURRENT", "RECOMMENDED", "REASON", "ACCOUNT"]),
  (.[] | [.uuid, .target.displayName, .currentEntity.displayName, .newEntity.displayName,
          (.risk.description // "-"), (.target.aspects.cloudAspect.businessAccount.displayName // "-")])
  | @tsv' <<<"$ACTIONS" |
  awk -F'\t' '{ for (i = 1; i <= NF; i++) { cell[NR, i] = $i; if (length($i) > w[i]) w[i] = length($i) } }
    END { for (r = 1; r <= NR; r++) { for (i = 1; i <= NF; i++) printf "%-*s  ", w[i], cell[r, i]; print "" } }'
