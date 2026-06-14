#!/usr/bin/env bash
set -euo pipefail

service="${1:?service is required}"
release_id="${2:?release id is required}"
artifact="${3:?artifact path is required}"
health_url="${4:?health URL is required}"
root="/opt/app-stack/${service}"
release_dir="${root}/releases/${release_id}"

install -d -m 0755 "${release_dir}"
tar -xzf "${artifact}" -C "${release_dir}"
rm -f "${artifact}"

if [[ -L "${root}/current" ]]; then
  ln -sfn "$(readlink -f "${root}/current")" "${root}/previous"
fi
ln -sfn "${release_dir}" "${root}/current"

systemctl restart "app-${service}.service"

for attempt in {1..12}; do
  if curl --fail --silent --show-error --max-time 5 "${health_url}" >/dev/null; then
    echo "${service} release ${release_id} is healthy"
    exit 0
  fi
  sleep 5
done

echo "${service} failed its health check" >&2
exit 1
