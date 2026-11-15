MODDIR="/data/adb/modules/shamiko_compat"
if [ -f "$MODDIR/disable" ] && [ -f "$MODDIR/module.prop" ]; then
  sed -i 's|^description=.*|description=Compagnon Shamiko sans doublon Zygisk pour Zygisk Assistant (sepolicy, resetprop, audit SELinux/props).|' "$MODDIR/module.prop" 2>/dev/null || true
  rm -f /data/adb/post-fs-data.d/.shamiko_compat_cleanup.sh
fi
