#!/bin/sh
# Writes otterscale.io/* lines for NFD local source (POSIX sh — Alpine-friendly).
# Uses host sysfs via SYS_ROOT (e.g. /host/sys).

set -eu

DOMAIN_PREFIX="otterscale.io"
SYS_ROOT="${SYS_ROOT:-/sys}"
DEV_ROOT="${DEV_ROOT:-/dev}"
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
