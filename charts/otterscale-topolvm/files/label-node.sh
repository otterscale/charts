#!/bin/sh
# Reads the "true"/"false" status written by check-volume-group.sh and keeps
# the node label ${LABEL_KEY} in sync via kubectl (nodes get/patch). Labels
# are only patched on state changes; on success the applied state is cached
# so steady state costs no API writes.

set -eu

NODE_NAME="${NODE_NAME:?NODE_NAME is required}"
LABEL_KEY="${LABEL_KEY:?LABEL_KEY is required}"
STATUS_FILE="${STATUS_FILE:-/status/vg-present}"
INTERVAL_SECONDS="${INTERVAL_SECONDS:-60}"
REMOVE_WHEN_MISSING="${REMOVE_WHEN_MISSING:-true}"

applied=""
while true; do
  present="$(cat "${STATUS_FILE}" 2>/dev/null || true)"
  if [ "${present}" = "true" ] && [ "${applied}" != "true" ]; then
    if kubectl label node "${NODE_NAME}" "${LABEL_KEY}=true" --overwrite; then
      echo "labeled node ${NODE_NAME} with ${LABEL_KEY}=true"
      applied="true"
    fi
  elif [ "${present}" = "false" ] && [ "${applied}" != "false" ]; then
    if [ "${REMOVE_WHEN_MISSING}" = "true" ]; then
      # Removing an absent label fails; treat it as already converged.
      kubectl label node "${NODE_NAME}" "${LABEL_KEY}-" 2>/dev/null \
        && echo "removed label ${LABEL_KEY} from node ${NODE_NAME}" || true
    fi
    applied="false"
  fi
  sleep "${INTERVAL_SECONDS}"
done
