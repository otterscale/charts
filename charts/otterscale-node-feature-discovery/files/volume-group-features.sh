#!/bin/sh
# Emits otterscale.io/aidaptiv=true for the NFD local source when the LVM
# volume group "vg_aidaptiv" exists on the host. POSIX sh (Alpine-friendly).
# Reads host sysfs via SYS_ROOT (e.g. /host/sys); no block device is opened.

set -eu

SYS_ROOT="${SYS_ROOT:-/sys}"

# LVM logical volumes show up as dm-* devices whose dm/name is "<vg>-<lv>"
# ("vg_aidaptiv" has no hyphen, so the prefix is literal).
for _d in "${SYS_ROOT}/block/dm-"*/; do
  [ -r "${_d}dm/name" ] || continue
  case "$(cat "${_d}dm/name" 2>/dev/null)" in
    vg_aidaptiv-*)
      echo "otterscale.io/aidaptiv=true"
      exit 0
      ;;
  esac
done

# Fallback: vgs(8) if installed — catches a VG with no active logical volumes.
if command -v vgs >/dev/null 2>&1 && vgs --noheadings -o vg_name 2>/dev/null | grep -Fqw vg_aidaptiv; then
  echo "otterscale.io/aidaptiv=true"
fi
