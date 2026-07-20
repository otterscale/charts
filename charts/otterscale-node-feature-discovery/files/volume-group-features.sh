#!/bin/sh
# Emits otterscale.io/aidaptiv=true for the NFD local source when the LVM volume
# group "vg_aidaptiv" is defined on the host — detected even when no logical
# volume is active. POSIX sh (Alpine-friendly).
#
# vgs(8) must read the PVs, so it runs against the host: inside the pod via the
# host mount namespace (nsenter -t 1 -m, needs a privileged pod with hostPID);
# on a plain host it falls back to vgs on PATH (run with sudo).

set -eu

VG="vg_aidaptiv"

vg_names() {
  if command -v nsenter >/dev/null 2>&1 && nsenter -t 1 -m -- vgs --version >/dev/null 2>&1; then
    nsenter -t 1 -m -- vgs --noheadings -o vg_name 2>/dev/null
  elif command -v vgs >/dev/null 2>&1; then
    vgs --noheadings -o vg_name 2>/dev/null
  fi
}

if vg_names | grep -Fqw "$VG"; then
  echo "otterscale.io/aidaptiv=true"
fi
