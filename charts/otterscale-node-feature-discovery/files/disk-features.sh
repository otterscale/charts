#!/bin/sh
# Writes otterscale.io/* lines for NFD local source (POSIX sh — Alpine-friendly).
# Uses host sysfs via SYS_ROOT (e.g. /host/sys).

set -eu

DOMAIN_PREFIX="otterscale.io"
SYS_ROOT="${SYS_ROOT:-/sys}"
DEV_ROOT="${DEV_ROOT:-/dev}"
# If set (e.g. /host), read ${PROC_ROOT}/proc/1/mountinfo (preferred) for FS types without opening block devices.
PROC_ROOT="${PROC_ROOT:-}"
# If set (e.g. /host/run), read ${RUN_ROOT}/udev/data/bM:m for ID_FS_TYPE (host udev probe; works unmounted, no blkid open).
RUN_ROOT="${RUN_ROOT:-}"
DATA_DISK_INCLUDE_NBD="${DATA_DISK_INCLUDE_NBD:-0}"

sanitize_label_name() {
  _s="$1"
  _s=$(printf '%s' "$_s" | tr '[:upper:]' '[:lower:]')
  _s=$(printf '%s' "$_s" | sed 's/[^a-z0-9_.-]/-/g')
  _s=$(printf '%s' "$_s" | sed 's/-\{2,\}/-/g')
  _s=$(printf '%s' "$_s" | sed 's/^[^a-z0-9]*//;s/[^a-z0-9]*$//')
  [ -z "$_s" ] && _s="unknown"
  _s=$(printf '%s' "$_s" | cut -c1-63)
  _s=$(printf '%s' "$_s" | sed 's/[^a-z0-9]*$//')
  _s=$(printf '%s' "$_s" | sed 's/^[^a-z0-9]*//')
  [ -z "$_s" ] && _s="x"
  printf '%s' "$_s"
}

sanitize_label_value() {
  _s="$1"
  _s=$(printf '%s' "$_s" | sed 's/[[:space:]]\+/-/g')
  _s=$(printf '%s' "$_s" | sed 's/[^A-Za-z0-9_.-]//g')
  _s=$(printf '%s' "$_s" | cut -c1-63)
  _s=$(printf '%s' "$_s" | sed 's/^[^A-Za-z0-9]*//;s/[^A-Za-z0-9]*$//')
  [ -z "$_s" ] && return 1
  printf '%s' "$_s"
}

emit_pair() {
  _key_suffix="$1"
  _value="$2"
  _name=$(sanitize_label_name "$_key_suffix")
  _val=$(sanitize_label_value "$_value") || return 0
  printf '%s/%s=%s\n' "$DOMAIN_PREFIX" "$_name" "$_val"
}

emit_raw_value() {
  _key_suffix="$1"
  _value="$2"
  _name=$(sanitize_label_name "$_key_suffix")
  _val=$(printf '%s' "$_value" | sed 's/[^A-Za-z0-9_.-]//g' | cut -c1-63)
  _val=$(printf '%s' "$_val" | sed 's/^[^A-Za-z0-9]*//;s/[^A-Za-z0-9]*$//')
  [ -z "$_val" ] && return 0
  printf '%s/%s=%s\n' "$DOMAIN_PREFIX" "$_name" "$_val"
}

read_sysfs_trim() {
  _f="$1"
  [ -f "$_f" ] || return 1
  # Some sysfs attrs are odd devices; tr may warn — stderr discarded.
  tr -d '\0' < "$_f" 2>/dev/null | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

is_empty_field() {
  _x="$1"
  [ -z "$_x" ] || [ "$_x" = "-" ]
}

is_data_disk_candidate() {
  _base="$1"
  case "$_base" in
    dm-*|loop*|ram*|zram*|fd*) return 1 ;;
  esac
  case "$_base" in
    nbd*)
      [ "$DATA_DISK_INCLUDE_NBD" = "1" ] || return 1
      ;;
  esac
  return 0
}

list_disk_bases() {
  for _d in "${SYS_ROOT}/block"/*/; do
    [ -d "$_d" ] || continue
    _base=$(basename "$_d")
    [ -f "${_d}partition" ] && continue
    [ -d "${_d}queue" ] || continue
    is_data_disk_candidate "$_base" || continue
    printf '%s\n' "$_base"
  done | sort -u
}

disk_size_bytes() {
  _disk="$1"
  if [ -f "${SYS_ROOT}/block/${_disk}/size" ]; then
    _sectors=$(read_sysfs_trim "${SYS_ROOT}/block/${_disk}/size" || true)
    if [ -n "$_sectors" ] && [ "$_sectors" -gt 0 ] 2>/dev/null; then
      printf '%s' "$((_sectors * 512))"
      return 0
    fi
  fi
  _devpath="${DEV_ROOT}/${_disk}"
  if command -v blockdev >/dev/null 2>&1 && [ -b "$_devpath" ]; then
    _b=$(blockdev --getsize64 "$_devpath" 2>/dev/null || true)
    if [ -n "$_b" ] && [ "$_b" -gt 0 ] 2>/dev/null; then
      printf '%s' "$_b"
      return 0
    fi
  fi
  return 1
}

disk_model() {
  _disk="$1"
  _m=""
  if [ -f "${SYS_ROOT}/block/${_disk}/device/model" ]; then
    _m=$(read_sysfs_trim "${SYS_ROOT}/block/${_disk}/device/model" || true)
  fi
  _v=""
  if [ -f "${SYS_ROOT}/block/${_disk}/device/vendor" ]; then
    _v=$(read_sysfs_trim "${SYS_ROOT}/block/${_disk}/device/vendor" || true)
  fi
  _out=""
  [ -n "$_v" ] && _out="${_v} "
  _out="${_out}${_m}"
  _out=$(printf '%s' "$_out" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
  if ! is_empty_field "$_out"; then
    printf '%s' "$_out"
    return 0
  fi
  return 1
}

disk_serial() {
  _disk="$1"
  for _f in \
    "${SYS_ROOT}/block/${_disk}/device/serial" \
    "${SYS_ROOT}/block/${_disk}/device/wwn" \
    "${SYS_ROOT}/block/${_disk}/device/wwid"
  do
    [ -f "$_f" ] || continue
    _s=$(read_sysfs_trim "$_f" || true)
    if ! is_empty_field "$_s"; then
      printf '%s' "$_s"
      return 0
    fi
  done
  return 1
}

disk_fw() {
  _disk="$1"
  if [ -f "${SYS_ROOT}/block/${_disk}/device/rev" ]; then
    _r=$(read_sysfs_trim "${SYS_ROOT}/block/${_disk}/device/rev" || true)
    if ! is_empty_field "$_r"; then
      printf '%s' "$_r"
      return 0
    fi
  fi
  # NVMe namespace device (SCSI uses rev; NVMe exposes firmware_rev)
  if [ -f "${SYS_ROOT}/block/${_disk}/device/firmware_rev" ]; then
    _r=$(read_sysfs_trim "${SYS_ROOT}/block/${_disk}/device/firmware_rev" || true)
    if ! is_empty_field "$_r"; then
      printf '%s' "$_r"
      return 0
    fi
  fi
  # Controller-level sysfs (some kernels only publish fw here)
  case "$_disk" in
    nvme*n*)
      _ctrl=$(printf '%s' "$_disk" | sed -n 's/^\(nvme[0-9][0-9]*\)n[0-9][0-9]*$/\1/p')
      if [ -n "$_ctrl" ] && [ -f "${SYS_ROOT}/class/nvme/${_ctrl}/firmware_rev" ]; then
        _r=$(read_sysfs_trim "${SYS_ROOT}/class/nvme/${_ctrl}/firmware_rev" || true)
        if ! is_empty_field "$_r"; then
          printf '%s' "$_r"
          return 0
        fi
      fi
      ;;
  esac
  return 1
}

# sysfs block name is this disk or one of its partitions (nvme0n11 must not match disk nvme0n1).
block_belongs_to_disk() {
  _b="$1"
  _disk="$2"
  [ "$_b" = "$_disk" ] && return 0
  case "$_disk" in
    nvme*n*)
      case "$_b" in
        "${_disk}p"*) return 0 ;;
      esac
      return 1
      ;;
  esac
  case "$_b" in
    "${_disk}p"*|"${_disk}"[0-9]*) return 0 ;;
  esac
  return 1
}

# sysfs maj:min for this disk and its partitions. Mountinfo SOURCE is often /dev/disk/by-uuid/…;
# matching only /dev/sd* misses those — use kernel mountinfo field 3 + sysfs dev.
disk_majmin_list_for_disk() {
  _disk="$1"
  for _d in "${SYS_ROOT}/block"/*/; do
    [ -d "$_d" ] || continue
    _b=$(basename "$_d")
    block_belongs_to_disk "$_b" "$_disk" || continue
    [ -f "${_d}dev" ] || continue
    _mm=$(read_sysfs_trim "${_d}dev" || true)
    _mm=$(printf '%s' "$_mm" | tr -d '[:space:]')
    [ -n "$_mm" ] && printf '%s\n' "$_mm"
  done | sort -u
}

# Host mount table (no block device open — works under Kubernetes device cgroup when host /proc is mounted).
# Prefer /proc/1/mountinfo: /proc/mounts resolves to the reader's namespace (pod). PID 1 on host procfs
# matches real host mounts.
#
# Important: if findmnt(1) exists, do NOT use it for mountinfo with SOURCE-only matching — mounts
# often show SOURCE=/dev/disk/by-uuid/… which fails ok(/dev/sd*). Parse mountinfo lines instead and
# match sysfs maj:min (field 3) to this disk and its partitions.
disk_fstypes_append_proc_mounts() {
  _disk="$1"
  [ -n "${PROC_ROOT}" ] || return 1
  _tab=""
  if [ -r "${PROC_ROOT}/proc/1/mountinfo" ]; then
    _tab="${PROC_ROOT}/proc/1/mountinfo"
  elif [ -r "${PROC_ROOT}/proc/mounts" ]; then
    _tab="${PROC_ROOT}/proc/mounts"
  else
    return 1
  fi
  _mountinfo=0
  case "$_tab" in
    */proc/1/mountinfo) _mountinfo=1 ;;
  esac

  _mmallow=$(disk_majmin_list_for_disk "$_disk" | tr '\n' ' ')

  if [ "$_mountinfo" -eq 1 ]; then
    awk -v d="$_disk" -v mmallow="$_mmallow" '
    function is_nvme_ns(x) { return (x ~ /^nvme[0-9]+n[0-9]+$/) }
    function ok(dev, disk) {
      if (dev == "" || dev == "none" || dev ~ /^\[[^]]*\]$/) return 0
      if (dev == "/dev/" disk) return 1
      if (is_nvme_ns(disk)) return (dev ~ "^/dev/" disk "p")
      return (dev ~ "^/dev/" disk "p" || dev ~ "^/dev/" disk "[0-9]")
    }
    function unesc(s) {
      gsub(/\\040/, " ", s)
      gsub(/\\011/, "\t", s)
      return s
    }
    function mm_from_line(line,   rest) {
      if (match(line, /^[0-9]+[[:space:]]+[0-9]+[[:space:]]+/)) {
        rest = substr(line, RLENGTH + 1)
        if (match(rest, /^[0-9]+:[0-9]+/))
          return substr(rest, RSTART, RLENGTH)
      }
      return ""
    }
    BEGIN {
      n = split(mmallow, _a, /[[:space:]]+/)
      for (i = 1; i <= n; i++)
        if (_a[i] != "") allow[_a[i]] = 1
    }
    {
      mm = mm_from_line($0)
      if (index($0, " - ") == 0) next
      rest = $0
      sub(/^.* - /, "", rest)
      n = split(rest, a, /[[:space:]]+/)
      if (n < 2) next
      fstype = a[1]
      source = unesc(a[2])
      if (mm != "" && (mm in allow)) { print fstype; next }
      if (ok(source, d)) print fstype
    }
  ' "$_tab" 2>/dev/null
  elif command -v findmnt >/dev/null 2>&1; then
    findmnt -n -r -o SOURCE,FSTYPE --tab-file "$_tab" 2>/dev/null |
      awk -v d="$_disk" '
        function is_nvme_ns(x) { return (x ~ /^nvme[0-9]+n[0-9]+$/) }
        function ok(dev, disk) {
          if (dev == "" || dev == "none" || dev ~ /^\[[^]]*\]$/) return 0
          if (dev == "/dev/" disk) return 1
          if (is_nvme_ns(disk)) return (dev ~ "^/dev/" disk "p")
          return (dev ~ "^/dev/" disk "p" || dev ~ "^/dev/" disk "[0-9]")
        }
        BEGIN { FS = "\t" }
        NF >= 2 && ok($1, d) { print $2 }
      '
  else
    awk -v d="$_disk" '
    function is_nvme_ns(x) { return (x ~ /^nvme[0-9]+n[0-9]+$/) }
    function ok(dev, disk) {
      if (dev == "/dev/" disk) return 1
      if (is_nvme_ns(disk)) return (dev ~ "^/dev/" disk "p")
      return (dev ~ "^/dev/" disk "p" || dev ~ "^/dev/" disk "[0-9]")
    }
    NF >= 3 && ok($1, d) { print $3 }
  ' "$_tab" 2>/dev/null
  fi
}

# Host udev database (ID_FS_TYPE) — no mount required if udev probed the device; no block device open.
disk_fstypes_append_udev() {
  _disk="$1"
  [ -n "${RUN_ROOT}" ] || return 1
  _udev="${RUN_ROOT}/udev/data"
  [ -d "$_udev" ] || return 1

  for _d in "${SYS_ROOT}/block"/*/; do
    [ -d "$_d" ] || continue
    _b=$(basename "$_d")
    block_belongs_to_disk "$_b" "$_disk" || continue
    [ -f "${_d}dev" ] || continue
    read -r _mm < "${_d}dev" || continue
    _mm=$(printf '%s' "$_mm" | tr -d '[:space:]')
    [ -n "$_mm" ] || continue
    _uf="${_udev}/b${_mm}"
    if [ ! -r "$_uf" ]; then
      _uf="${_udev}/+block:b${_mm}"
    fi
    [ -r "$_uf" ] || continue
    _t=$(awk '/^E:ID_FS_TYPE=/ { sub(/^E:ID_FS_TYPE=/, ""); print; exit }' "$_uf" 2>/dev/null)
    [ -z "$_t" ] && _t=$(awk '/^ID_FS_TYPE=/ { sub(/^ID_FS_TYPE=/, ""); print; exit }' "$_uf" 2>/dev/null)
    is_empty_field "$_t" && continue
    printf '%s\n' "$_t"
  done
}

# Unique non-empty FSTYPE values for this disk and its partitions (hyphen-joined).
# 1) Host /proc/1/mountinfo (preferred) or /proc/mounts — mounted filesystems only.
# 2) Host udev — ID_FS_TYPE (often includes unmounted partitions already probed on the host).
# 3) lsblk / blkid — opens devices (often needs privileged in Kubernetes).
disk_fstypes() {
  _disk="$1"
  _devpath="${DEV_ROOT}/${_disk}"
  _raw=""

  if [ -n "${PROC_ROOT}" ] && {
    [ -r "${PROC_ROOT}/proc/1/mountinfo" ] || [ -r "${PROC_ROOT}/proc/mounts" ]
  }; then
    _raw=$(disk_fstypes_append_proc_mounts "$_disk")
  fi

  if [ -n "${RUN_ROOT}" ] && [ -d "${RUN_ROOT}/udev/data" ]; then
    _from_udev=$(disk_fstypes_append_udev "$_disk")
    _raw=$(printf '%s\n%s\n' "$_raw" "$_from_udev")
  fi

  if command -v lsblk >/dev/null 2>&1 && [ -b "$_devpath" ]; then
    _from_lsblk=$(lsblk -n -r -o FSTYPE "$_devpath" 2>/dev/null | sed '/^[[:space:]]*$/d')
    _raw=$(printf '%s\n%s\n' "$_raw" "$_from_lsblk")
  fi

  if command -v blkid >/dev/null 2>&1; then
    if [ -b "$_devpath" ]; then
      _t=$(blkid -o value -s TYPE "$_devpath" 2>/dev/null || true)
      if ! is_empty_field "$_t"; then
        _raw=$(printf '%s\n%s\n' "$_raw" "$_t")
      fi
    fi
    for _d in "${SYS_ROOT}/block"/*/; do
      [ -d "$_d" ] || continue
      _b=$(basename "$_d")
      block_belongs_to_disk "$_b" "$_disk" || continue
      [ "$_b" = "$_disk" ] && continue
      _bd="${DEV_ROOT}/${_b}"
      [ -b "$_bd" ] || continue
      _t=$(blkid -o value -s TYPE "$_bd" 2>/dev/null || true)
      is_empty_field "$_t" && continue
      _raw=$(printf '%s\n%s\n' "$_raw" "$_t")
    done
  fi

  _list=$(printf '%s\n' "$_raw" | sed '/^[[:space:]]*$/d' | sort -u)
  [ -z "$_list" ] && return 1

  _out=""
  _first=1
  for _t in $(printf '%s\n' "$_list"); do
    [ -z "$_t" ] && continue
    is_empty_field "$_t" && continue
    if [ "$_first" -eq 1 ]; then
      _out="$_t"
      _first=0
    else
      _out="${_out}-${_t}"
    fi
  done
  [ -z "$_out" ] && return 1
  printf '%s' "$_out"
  return 0
}

has_nvidia_gpu() {
  # Check ${SYS_ROOT}/bus/pci/devices for NVIDIA GPUs (vendor ID 0x10de)
  for dev_path in "${SYS_ROOT}"/bus/pci/devices/*/; do
    [ -f "$dev_path/vendor" ] || continue
    vendor=$(cat "$dev_path/vendor" 2>/dev/null || true)
    # NVIDIA vendor ID is 0x10de
    [ "$vendor" = "0x10de" ] && return 0
  done
  return 1
}

DISK_COUNT=$(list_disk_bases | wc -l | tr -d ' \t')
emit_raw_value "disk-count" "$DISK_COUNT"

# Avoid `| while` (subshell); POSIX `for` keeps functions in the same shell.
for disk in $(list_disk_bases); do
  [ -n "$disk" ] || continue
  safe=$(sanitize_label_name "disk.${disk}")

  emit_raw_value "$safe" "present"

  if size_bytes=$(disk_size_bytes "$disk"); then
    size_gb=$((size_bytes / 1024 / 1024 / 1024))
    emit_raw_value "${safe}-size-gb" "$size_gb"
  fi

  if model_raw=$(disk_model "$disk"); then
    emit_pair "${safe}-model" "$model_raw"
  fi

  if serial_raw=$(disk_serial "$disk"); then
    emit_pair "${safe}-sn" "$serial_raw"
  fi

  if rev_raw=$(disk_fw "$disk"); then
    emit_pair "${safe}-fw" "$rev_raw"
  fi

  if fs_raw=$(disk_fstypes "$disk"); then
    emit_pair "${safe}-fs" "$fs_raw"
  fi

  case "$disk" in
    nvme*)
      emit_raw_value "${safe}-type" "nvme"
      ;;
    *)
      rota=""
      if [ -f "${SYS_ROOT}/block/${disk}/queue/rotational" ]; then
        rota=$(read_sysfs_trim "${SYS_ROOT}/block/${disk}/queue/rotational" || true)
      fi
      if [ "$rota" = "0" ]; then
        emit_raw_value "${safe}-type" "ssd"
      elif [ "$rota" = "1" ]; then
        emit_raw_value "${safe}-type" "hdd"
      fi
      ;;
  esac
done

# Check for NVIDIA GPU and emit label
if has_nvidia_gpu; then
  emit_pair "gpu" "on"
fi
