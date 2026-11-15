# shellcheck disable=SC2034
SKIPUNZIP=1

MODULE_MIN_MAGISK_VERSION=27005
MODULE_MIN_KSU_KERNEL_VERSION=10940
MODULE_MIN_KSUD_VERSION=11903

enforce_install_from_app() {
  if [ "$BOOTMODE" = true ]; then
    ui_print "- Installation depuis l'application KernelSU / Magisk"
  else
    ui_print "*********************************************************"
    ui_print "! Installation en recovery non prise en charge"
    ui_print "! Installe depuis KernelSU-Next Manager"
    abort    "*********************************************************"
  fi
}

check_root_impl() {
  if [ -n "$KSU" ]; then
    ui_print "- KernelSU / KernelSU-Next : kernel=${KSU_KERNEL_VER_CODE:-?} ksud=${KSU_VER_CODE:-?}"
    if [ -z "$KSU_KERNEL_VER_CODE" ] || [ "$KSU_KERNEL_VER_CODE" -lt "$MODULE_MIN_KSU_KERNEL_VERSION" ]; then
      abort "! Version KernelSU noyau trop ancienne (< $MODULE_MIN_KSU_KERNEL_VERSION)"
    fi
    if [ -z "$KSU_VER_CODE" ] || [ "$KSU_VER_CODE" -lt "$MODULE_MIN_KSUD_VERSION" ]; then
      abort "! Version ksud trop ancienne (< $MODULE_MIN_KSUD_VERSION)"
    fi
  else
    ui_print "- Magisk version : ${MAGISK_VER_CODE:-0}"
    if [ -z "$MAGISK_VER_CODE" ] || [ "$MAGISK_VER_CODE" -lt "$MODULE_MIN_MAGISK_VERSION" ]; then
      abort "! Magisk >= $MODULE_MIN_MAGISK_VERSION requis"
    fi
  fi
}

check_companion_stack() {
  if [ -d /data/adb/modules/zygisk-assistant ] && [ ! -f /data/adb/modules/zygisk-assistant/disable ]; then
    ui_print "- Zygisk Assistant detecte et actif (mode compagnon sans conflit)"
  elif [ -d /data/adb/modules/zygisk-assistant ]; then
    ui_print "! Attention : Zygisk Assistant est desactive — pense a le reactiver"
  else
    ui_print "! Info : Zygisk Assistant absent (ce module applique uniquement sepolicy/resetprop)"
  fi
}

VERSION=$(grep_prop version "${TMPDIR}/module.prop")
ui_print "- Shamiko Compat ${VERSION}"
ui_print "- Verification SHA-256 de l'archive"

unzip -o "$ZIPFILE" 'verify.sh' -d "$TMPDIR" >&2
[ -f "$TMPDIR/verify.sh" ] || abort "! Impossible d'extraire verify.sh"
. "$TMPDIR/verify.sh"

extract "$ZIPFILE" 'customize.sh' "$TMPDIR"
extract "$ZIPFILE" 'verify.sh' "$TMPDIR"

enforce_install_from_app
check_root_impl
check_companion_stack

if [ "${API:-0}" -lt 27 ]; then
  abort "! Android 8.1+ (API >= 27) requis"
fi
ui_print "- Architecture : $ARCH (API $API)"

for f in \
  module.prop \
  sepolicy.rule \
  common_props.sh \
  post-fs-data.sh \
  service.sh \
  action.sh \
  cleanup.sh \
  uninstall.sh; do
  extract "$ZIPFILE" "$f" "$MODPATH"
done

set_perm_recursive "$MODPATH" 0 0 0755 0644
for exec_file in post-fs-data.sh service.sh action.sh cleanup.sh uninstall.sh; do
  set_perm "$MODPATH/$exec_file" 0 0 0755
done

mkdir -p /data/adb/post-fs-data.d
cp -f "$MODPATH/cleanup.sh" /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh
chmod 0755 /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh

ui_print "- Pret : redemarre pour activer sepolicy.rule et le durcissement boot"
