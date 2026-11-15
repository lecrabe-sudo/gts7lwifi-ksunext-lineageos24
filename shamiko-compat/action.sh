#!/system/bin/sh
MODDIR=${0%/*}
. "$MODDIR/common_props.sh"

harden_selinux_state
harden_shamiko_props
check_zygisk_assistant_state

echo "=== Shamiko Compat (SM-T870) — Audit ==="
echo "SELinux        : $SELINUX_MODE"
echo "Zygisk Assistant: $ZA_STATE"
if [ -f "$MODDIR/sepolicy.rule" ]; then
  echo "sepolicy.rule  : present ($(wc -l < "$MODDIR/sepolicy.rule" 2>/dev/null) regles)"
else
  echo "sepolicy.rule  : ABSENT"
fi
echo "Props presentes: $PROP_PRESENT | corrigees: $PROP_FIXED | echecs: $PROP_FAILED"

echo ""
echo "--- Verification detaillee des proprietes ---"
for entry in $SHAMIKO_EXACT_PROPS; do
  [ -z "$entry" ] && continue
  name="${entry%%=*}"
  expected="${entry#*=}"
  cur="$(run_resetprop "$name")"
  if [ -z "$cur" ]; then
    continue
  elif [ "$cur" = "$expected" ]; then
    echo "[OK]   $name=$cur"
  else
    echo "[DIFF] $name=$cur (attendu=$expected)"
  fi
done
for name in $SHAMIKO_BOOTMODE_PROPS; do
  cur="$(run_resetprop "$name")"
  [ -z "$cur" ] && continue
  echo "[INFO] $name=$cur"
done

echo ""
echo "--- AVC zygote (dmesg) ---"
dmesg 2>/dev/null | grep -i 'avc:.*zygote' | tail -n 10 || true
