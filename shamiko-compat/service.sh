#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common_props.sh"
. "$MODDIR/whitelist.sh"

# Attendre la fin du demarrage et des scripts tardifs (Zygisk Assistant / vbmeta-fixer)
i=0
while [ "$(getprop sys.boot_completed)" != "1" ] && [ "$i" -lt 60 ]; do
  sleep 1
  i=$((i + 1))
done
sleep 3

harden_selinux_state
harden_shamiko_props
check_zygisk_assistant_state
sync_shamiko_whitelist

if [ "$WL_MODE" = "ON" ]; then
  WL_STATUS="Whitelist ON (${WL_COUNT})"
else
  WL_STATUS="Whitelist OFF"
fi


if [ "$PROP_FAILED" -eq 0 ]; then
  STATUS="Actif ✅ | ${WL_STATUS} | ${PROP_PRESENT} props (${PROP_FIXED} corrigees) | SELinux: ${SELINUX_MODE} | Zygisk Assistant: ${ZA_STATE}"
else
  STATUS="Partiel ⚠️ | ${WL_STATUS} | ${PROP_FAILED} echec(s) resetprop | Zygisk Assistant: ${ZA_STATE}"
fi
update_module_description "$MODDIR" "$STATUS"
