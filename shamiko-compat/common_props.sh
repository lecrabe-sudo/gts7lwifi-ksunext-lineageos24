BASE_DESCRIPTION="Compagnon Shamiko sans doublon Zygisk pour Zygisk Assistant (sepolicy, resetprop, audit SELinux/props)."

RESETPROP_BIN="$(command -v resetprop 2>/dev/null || echo /data/adb/ksu/bin/resetprop)"

run_resetprop() {
  "$RESETPROP_BIN" "$@" 2>/dev/null
}

# Table des proprietes Shamiko : nom=valeur_attendue
# (applique uniquement si la propriete existe deja sur l'appareil).
SHAMIKO_EXACT_PROPS="
ro.boot.vbmeta.device_state=locked
ro.boot.verifiedbootstate=green
ro.boot.flash.locked=1
ro.boot.veritymode=enforcing
ro.boot.warranty_bit=0
ro.warranty_bit=0
ro.vendor.boot.warranty_bit=0
ro.vendor.warranty_bit=0
vendor.boot.vbmeta.device_state=locked
vendor.boot.verifiedbootstate=green
sys.oem_unlock_allowed=0
ro.debuggable=0
ro.force.debuggable=0
ro.secure=1
ro.adb.secure=1
ro.build.type=user
ro.build.tags=release-keys
ro.system.build.type=user
ro.system.build.tags=release-keys
ro.system_ext.build.type=user
ro.system_ext.build.tags=release-keys
ro.vendor.build.type=user
ro.vendor.build.tags=release-keys
ro.product.build.type=user
ro.product.build.tags=release-keys
ro.odm.build.type=user
ro.odm.build.tags=release-keys
ro.vendor_dlkm.build.type=user
ro.vendor_dlkm.build.tags=release-keys
ro.secureboot.lockstate=locked
ro.boot.realmebootstate=green
ro.boot.realme.lockstate=1
"

SHAMIKO_BOOTMODE_PROPS="ro.bootmode ro.boot.bootmode vendor.boot.bootmode"

set_prop_stealth() {
  local name="$1"
  local val="$2"
  run_resetprop -n "$name" "$val" || run_resetprop "$name" "$val"
}

check_reset_prop() {
  local name="$1"
  local expected="$2"
  local current
  current="$(run_resetprop "$name")"
  [ -z "$current" ] && return 0
  PROP_PRESENT=$((PROP_PRESENT + 1))
  if [ "$current" != "$expected" ]; then
    if set_prop_stealth "$name" "$expected"; then
      PROP_FIXED=$((PROP_FIXED + 1))
    else
      PROP_FAILED=$((PROP_FAILED + 1))
    fi
  fi
}

contains_reset_prop() {
  local name="$1"
  local needle="$2"
  local replacement="$3"
  local current
  current="$(run_resetprop "$name")"
  [ -z "$current" ] && return 0
  PROP_PRESENT=$((PROP_PRESENT + 1))
  case "$current" in
    *"$needle"*)
      if set_prop_stealth "$name" "$replacement"; then
        PROP_FIXED=$((PROP_FIXED + 1))
      else
        PROP_FAILED=$((PROP_FAILED + 1))
      fi
      ;;
  esac
}

harden_shamiko_props() {
  PROP_PRESENT=0
  PROP_FIXED=0
  PROP_FAILED=0

  local entry name expected
  for entry in $SHAMIKO_EXACT_PROPS; do
    [ -z "$entry" ] && continue
    name="${entry%%=*}"
    expected="${entry#*=}"
    check_reset_prop "$name" "$expected"
  done

  for name in $SHAMIKO_BOOTMODE_PROPS; do
    contains_reset_prop "$name" "recovery" "unknown"
  done
}

harden_selinux_state() {
  local enforce_val
  enforce_val="$(cat /sys/fs/selinux/enforce 2>/dev/null || true)"
  if [ "$enforce_val" = "0" ]; then
    chmod 640 /sys/fs/selinux/enforce 2>/dev/null || true
    chmod 440 /sys/fs/selinux/policy 2>/dev/null || true
  fi
  SELINUX_MODE="$(getenforce 2>/dev/null || echo unknown)"
}

check_zygisk_assistant_state() {
  local mod="/data/adb/modules/zygisk-assistant"
  if [ ! -d "$mod" ]; then
    ZA_STATE="absent"
  elif [ -f "$mod/disable" ]; then
    ZA_STATE="desactive"
  else
    ZA_STATE="actif"
  fi
}

update_module_description() {
  local moddir="$1"
  local status="$2"
  local prop_file="$moddir/module.prop"
  local safe_status
  [ -f "$prop_file" ] || return 0
  safe_status="$(printf '%s' "$status" | sed 's/[&|\\]/\\&/g')"
  sed -i "s|^description=.*|description=[${safe_status}] ${BASE_DESCRIPTION}|" "$prop_file" 2>/dev/null || true
}
