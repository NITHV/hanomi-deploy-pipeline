#!/usr/bin/env bash
set -Eeuo pipefail

release_id="${GITHUB_SHA:?GITHUB_SHA is required}"
ssh_options=(-i "${SSH_KEY_FILE:?}" -o BatchMode=yes -o StrictHostKeyChecking=yes -o UserKnownHostsFile="${KNOWN_HOSTS_FILE:?}")
deployed=()

deploy_linux() {
  local service="$1" host="$2" user="$3" artifact="$4" health_url="$5"
  local remote_artifact="/tmp/${service}-${release_id}.tar.gz"

  scp "${ssh_options[@]}" "$artifact" "${user}@${host}:${remote_artifact}"
  ssh "${ssh_options[@]}" "${user}@${host}" \
    "sudo bash -s -- '$service' '$release_id' '$remote_artifact' '$health_url'" \
    < deploy/linux/deploy.sh
  deployed+=("$service")
}

deploy_worker() {
  local remote_zip="C:/Windows/Temp/worker-${release_id}.zip"

  scp "${ssh_options[@]}" artifacts/worker.zip \
    "${WINDOWS_USER}@${WINDOWS_HOST}:${remote_zip}"
  ssh "${ssh_options[@]}" "${WINDOWS_USER}@${WINDOWS_HOST}" \
    "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File - -ReleaseId '$release_id' -ArtifactPath '$remote_zip'" \
    < deploy/windows/Deploy-Worker.ps1
  deployed+=("worker")
}

rollback_all() {
  local status=0
  echo "Deployment failed after: ${deployed[*]:-none}. Rolling back every service."

  ssh "${ssh_options[@]}" "${BACKEND_USER}@${BACKEND_HOST}" \
    "sudo bash -s -- backend '${BACKEND_HEALTH_URL}'" < deploy/linux/rollback.sh || status=1
  ssh "${ssh_options[@]}" "${FRONTEND_USER}@${FRONTEND_HOST}" \
    "sudo bash -s -- frontend '${FRONTEND_HEALTH_URL}'" < deploy/linux/rollback.sh || status=1
  ssh "${ssh_options[@]}" "${WINDOWS_USER}@${WINDOWS_HOST}" \
    "powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File -" \
    < deploy/windows/Rollback-Worker.ps1 || status=1

  return "$status"
}

trap 'exit_code=$?; trap - ERR; rollback_all || true; exit "$exit_code"' ERR

deploy_linux backend "$BACKEND_HOST" "$BACKEND_USER" artifacts/backend.tar.gz "$BACKEND_HEALTH_URL"
deploy_linux frontend "$FRONTEND_HOST" "$FRONTEND_USER" artifacts/frontend.tar.gz "$FRONTEND_HEALTH_URL"
deploy_worker

trap - ERR
echo "Release ${release_id} is healthy on all services."
