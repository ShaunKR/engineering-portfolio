#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
if [[ $# -lt 2 ]]; then
  echo "Usage: bash mqtt.sh {a|b|proxy} {sub|pub} [mosquitto arguments...]" >&2
  exit 1
fi
case "$1" in
  a) host=broker-a ;;
  b) host=broker-b ;;
  proxy) host=haproxy ;;
  *) echo "Unknown target: $1" >&2; exit 1 ;;
esac
case "$2" in
  sub) command=mosquitto_sub ;;
  pub) command=mosquitto_pub ;;
  *) echo "Use sub or pub" >&2; exit 1 ;;
esac
shift 2
exec docker compose run --rm --no-deps mqtt "$command" -h "$host" -p 1883 -k 5 "$@"
