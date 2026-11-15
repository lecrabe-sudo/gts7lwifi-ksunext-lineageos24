#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common_props.sh"

harden_selinux_state
harden_shamiko_props

if [ ! -f /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh ] && [ -f "$MODDIR/cleanup.sh" ]; then
  mkdir -p /data/adb/post-fs-data.d
  cp -f "$MODDIR/cleanup.sh" /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh
  chmod 0755 /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh
fi
