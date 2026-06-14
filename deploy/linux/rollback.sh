#!/usr/bin/env bash
set -euo pipefail

service="${1:?service is required}"
health_url="${2:?health URL is required}"
root="/opt/app-stack/${service}"

if [[ ! -L "${root}/previous" ]]; then
  echo "No previous ${service} release exists; leaving current unchanged." >&2
  exit 0
fi

current_target="$(readlink -f "${root}/current")"
previous_target="$(readlink -f "${root}/previous")"
ln -sfn "${previous_target}" "${root}/current"
ln -sfn "${current_target}" "${root}/previous"
systemctl restart "app-${service}.service"

for attempt in {1..12}; do
  if curl --fail --silent --show-error --max-time 5 "${health_url}" >/dev/null; then
    echo "${service} rollback is healthy"
    exit 0
  fi
  sleep 5
done

echo "${service} rollback failed its health check" >&2
exit 1
