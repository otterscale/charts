#!/bin/sh
# Periodically checks whether the LVM volume group ${VG_NAME} is defined on
# the host — detected even when no logical volume is active — and atomically
# writes "true"/"false" to ${STATUS_FILE} for the labeler container.
#
# vgs(8) must read the PVs, so it runs against the host: inside the pod via
# the host mount namespace (nsenter -t 1 -m, needs a privileged pod with
# hostPID); on a plain host it falls back to vgs on PATH.

set -eu

VG_NAME="${VG_NAME:?VG_NAME is required}"
STATUS_FILE="${STATUS_FILE:-/status/vg-present}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-60}"

vg_names() {
  if command -v nsenter >/dev/null 2>&1 && nsenter -t 1 -m -- vgs --version >/dev/null 2>&1; then
    nsenter -t 1 -m -- vgs --noheadings -o vg_name 2>/dev/null
  elif command -v vgs >/dev/null 2>&1; then
    vgs --noheadings -o vg_name 2>/dev/null
  fi
}

last=""
while true; do
  if vg_names | grep -Fqw "${VG_NAME}"; then
    present="true"
  else
    present="false"
  fi
  echo "${present}" > "${STATUS_FILE}.tmp"
  mv -f "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  if [ "${present}" != "${last}" ]; then
    echo "volume group ${VG_NAME}: present=${present}"
    last="${present}"
  fi
  sleep "${INTERVAL_SECONDS}"
done
