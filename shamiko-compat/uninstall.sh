#!/system/bin/sh
MODDIR=${0%/*}
if [ -f "$MODDIR/whitelist.sh" ]; then
  . "$MODDIR/whitelist.sh"
  restore_shamiko_whitelist
fi
rm -rf /data/adb/shamiko_compat
rm -f /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh
