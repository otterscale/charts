#!/bin/sh
# Writes otterscale.io/gpu-* lines for NFD local source (POSIX sh — Alpine-friendly).
# Scans PCI devices via host sysfs for NVIDIA GPUs (vendor 0x10de, class 0x03xx).
# Outputs:
#   otterscale.io/gpu-count=<total>
#   otterscale.io/gpu=true                       (only when at least one GPU is present)
#   otterscale.io/gpu-pci-<device_id>=<count>   (one line per unique PCI device ID)
#
# Requires SYS_ROOT to be set to host sysfs mount point (e.g. /host/sys).

set -eu

SYS_ROOT="${SYS_ROOT:-/sys}"
PCI_DIR="${SYS_ROOT}/bus/pci/devices"

if [ ! -d "${PCI_DIR}" ]; then
  echo "otterscale.io/gpu-count=0"
  exit 0
fi

# Collect all NVIDIA display-class device IDs into a temp file.
# Class 0x03xxxx = Display controller (VGA-compatible, XGA, 3D, etc.)
TMP_IDS=""
total=0

for dev in "${PCI_DIR}"/*/; do
  vendor_file="${dev}vendor"
  [ -r "${vendor_file}" ] || continue
  vendor="$(cat "${vendor_file}" 2>/dev/null || true)"
  [ "${vendor}" = "0x10de" ] || continue

  class_file="${dev}class"
  class="$(cat "${class_file}" 2>/dev/null || true)"
  # Must be display class: 0x03xxxx
  case "${class}" in
    0x03*) ;;
    *) continue ;;
  esac

  device_file="${dev}device"
  [ -r "${device_file}" ] || continue
  device="$(cat "${device_file}" 2>/dev/null || true)"
  [ -n "${device}" ] || continue

  # Normalize: strip leading "0x" and lowercase → e.g. "2684"
  did="$(printf '%s' "${device#0x}" | tr 'A-F' 'a-f')"
  [ -n "${did}" ] || continue

  TMP_IDS="${TMP_IDS}${did}
"
  total=$((total + 1))
done

echo "otterscale.io/gpu-count=${total}"

[ "${total}" -gt 0 ] || exit 0

echo "otterscale.io/gpu=true"

# Count per device ID and emit one label per unique ID.
printf '%s' "${TMP_IDS}" | grep -v '^$' | sort | uniq -c | while read -r count did; do
  [ -n "${did}" ] || continue
  echo "otterscale.io/gpu-pci-${did}=${count}"
done
