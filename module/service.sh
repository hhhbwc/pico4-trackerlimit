#!/system/bin/sh
# v2.6 boot worker (stock only + compat fix)
# 不切换算法、不挂载库、不重启追踪服务

MOD=/data/adb/modules/pico4_swift_force_enable
RUNDIR=/data/adb/pico4_tracker
BOOT_STATUS=$RUNDIR/boot_transition.status
BOOT_DONE=$RUNDIR/boot_transition.done
TOGGLE=$MOD/toggle.sh

umask 022
mkdir -p "$RUNDIR"
rm -f "$BOOT_DONE"
: > "$BOOT_STATUS"
chmod 644 "$BOOT_STATUS"

# v2.6 兼容层自检
if [ -f /system/lib64/libswift205shim.so ]; then
  echo "compat: libswift205shim present" >> "$BOOT_STATUS"
else
  echo "compat: libswift205shim MISSING" >> "$BOOT_STATUS"
fi

# 等待 toggle.sh 出现（如果模块目录还没就绪）
n=0
while [ $n -lt 30 ]; do
  [ -f "$TOGGLE" ] && break
  sleep 2
  n=$((n + 1))
done

if [ ! -f "$TOGGLE" ]; then
  # toggle.sh 不存在时直接标记完成（仅原版，无需处理）
  echo "complete boot (no toggle script)" > "$BOOT_STATUS"
  exit 0
fi

chmod 755 "$TOGGLE"
"$TOGGLE" apply
rc=$?

if [ $rc -eq 0 ]; then
  : > "$BOOT_DONE"
  chmod 644 "$BOOT_DONE"
  echo "complete boot" >> "$BOOT_STATUS"
else
  echo "error rc=$rc" >> "$BOOT_STATUS"
fi

exit $rc