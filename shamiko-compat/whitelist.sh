#!/system/bin/sh
# Gestion de la liste blanche (whitelist) KernelSU-Next pour Shamiko Compat.
# Lorsqu'un paquet est present dans /data/adb/shamiko_compat/whitelist (et n'a pas
# deja allow_su=true), son profil non-root passe en use_default=false / umount_modules=false
# afin d'exempter ce paquet du masquage tout en gardant le masquage actif partout ailleurs.

WHITELIST_DIR="/data/adb/shamiko_compat"
WHITELIST_FILE="${WHITELIST_DIR}/whitelist"
MANAGED_FILE="${WHITELIST_DIR}/.managed_whitelist"

find_ksud() {
  for candidate in /data/adb/ksud /data/adb/ksu/bin/ksud /system/bin/ksud; do
    if [ -x "$candidate" ]; then
      echo "$candidate"
      return 0
    fi
  done
  command -v ksud 2>/dev/null || true
}

# Parse /data/adb/shamiko_compat/whitelist (ignore commentaires '#' et espaces/CR).
parse_whitelist_packages() {
  [ -f "$WHITELIST_FILE" ] || return 0
  tr -d '\r' < "$WHITELIST_FILE" | while IFS= read -r line || [ -n "$line" ]; do
    line="${line%%#*}"
    line="$(echo "$line" | tr -d ' \t')"
    [ -n "$line" ] && echo "$line"
  done | awk '!seen[$0]++'
}

# Applique umount_modules=false (mode=whitelist) ou restaure use_default=true (mode=default)
# Codes de retour: 0 = mis a jour ou deja conforme, 2 = paquet absent/erreur, 3 = allow_su actif
set_nonroot_umount() {
  _ksud="$1"
  _pkg="$2"
  _target_umount="$3"

  _json="$("$_ksud" profile get "$_pkg" 2>/dev/null)" || return 2
  [ -n "$_json" ] || return 2

  if echo "$_json" | grep -q '"allow_su":[[:space:]]*true'; then
    return 3
  fi
  if ! echo "$_json" | grep -q '"non_root"'; then
    return 2
  fi

  if [ "$_target_umount" = "false" ]; then
    if echo "$_json" | grep -q '"use_default":[[:space:]]*false' && echo "$_json" | grep -q '"umount_modules":[[:space:]]*false'; then
      return 0
    fi
    _updated="$(printf '%s\n' "$_json" | sed \
      -e 's/"use_default":[[:space:]]*true/"use_default": false/' \
      -e 's/"umount_modules":[[:space:]]*true/"umount_modules": false/')"
  else
    if echo "$_json" | grep -q '"use_default":[[:space:]]*true' && echo "$_json" | grep -q '"umount_modules":[[:space:]]*true'; then
      return 0
    fi
    _updated="$(printf '%s\n' "$_json" | sed \
      -e 's/"use_default":[[:space:]]*false/"use_default": true/' \
      -e 's/"umount_modules":[[:space:]]*false/"umount_modules": true/')"
  fi

  printf '%s\n' "$_updated" | "$_ksud" profile set - >/dev/null 2>&1 || return 2
  return 0
}

sync_shamiko_whitelist() {
  WL_MODE="OFF"
  WL_COUNT=0
  WL_RESTORED=0
  WL_SKIPPED=0
  WL_FAILED=0

  KSUD_BIN="$(find_ksud)"
  if [ -z "$KSUD_BIN" ]; then
    WL_FAILED=1
    return 1
  fi

  mkdir -p "$WHITELIST_DIR"
  NEW_MANAGED="${WHITELIST_DIR}/.managed_whitelist.tmp"
  : > "$NEW_MANAGED"

  DESIRED=""
  if [ -f "$WHITELIST_FILE" ]; then
    WL_MODE="ON"
    DESIRED="$(parse_whitelist_packages)"
  fi

  if [ -f "$MANAGED_FILE" ]; then
    while IFS= read -r prev || [ -n "$prev" ]; do
      [ -z "$prev" ] && continue
      still_present=0
      for wanted in $DESIRED; do
        if [ "$wanted" = "$prev" ]; then
          still_present=1
          break
        fi
      done
      if [ "$still_present" -eq 0 ]; then
        set_nonroot_umount "$KSUD_BIN" "$prev" "true"
        rc=$?
        if [ "$rc" -eq 0 ]; then
          WL_RESTORED=$((WL_RESTORED + 1))
        elif [ "$rc" -eq 2 ]; then
          WL_FAILED=$((WL_FAILED + 1))
        fi
      fi
    done < "$MANAGED_FILE"
  fi

  for pkg in $DESIRED; do
    set_nonroot_umount "$KSUD_BIN" "$pkg" "false"
    rc=$?
    if [ "$rc" -eq 0 ]; then
      echo "$pkg" >> "$NEW_MANAGED"
      WL_COUNT=$((WL_COUNT + 1))
    elif [ "$rc" -eq 3 ]; then
      WL_SKIPPED=$((WL_SKIPPED + 1))
    else
      WL_SKIPPED=$((WL_SKIPPED + 1))
    fi
  done

  if [ -s "$NEW_MANAGED" ]; then
    mv -f "$NEW_MANAGED" "$MANAGED_FILE"
  else
    rm -f "$NEW_MANAGED" "$MANAGED_FILE"
  fi
  return 0
}

restore_shamiko_whitelist() {
  KSUD_BIN="$(find_ksud)"
  [ -n "$KSUD_BIN" ] || return 0
  [ -f "$MANAGED_FILE" ] || return 0
  while IFS= read -r prev || [ -n "$prev" ]; do
    [ -z "$prev" ] && continue
    set_nonroot_umount "$KSUD_BIN" "$prev" "true" || true
  done < "$MANAGED_FILE"
  rm -f "$MANAGED_FILE"
}
