#!/system/bin/sh
# 开机按 algo_state 挂载对应算法 (ultra/stock)
# 同时确保 ultra/ 算法套件已从模块目录复制到 /data/adb/ultra/
STATE=/data/adb/pico4_tracker/algo_state
MOD=/data/adb/modules/pico4_swift_force_enable
ULTRA_LIB=/data/adb/ultra/libAlgSwiftBodyPose.so
STOCK_LIB=/data/adb/ultra/stock_lib.so
LIB_DST=/system/lib64/libAlgSwiftBodyPose.so
SVC=pvrtrackingservice

# 确保 ultra 套件存在（customize.sh 执行时文件可能尚未就绪，此处开机后补）
if [ -d "$MOD/ultra" ] && [ ! -f "$ULTRA_LIB" ]; then
  mkdir -p /data/adb/ultra /data/adb/pico4_tracker
  cp -rf "$MOD/ultra/." /data/adb/ultra/ 2>/dev/null || true
  cp -f "$MOD/toggle.sh" /data/adb/ultra/toggle.sh 2>/dev/null || true
  chmod 755 /data/adb/ultra/toggle.sh 2>/dev/null || true
fi

[ -z "$(cat $STATE 2>/dev/null)" ] && echo ultra > $STATE
MODE=$(cat $STATE)

(
  n=0
  while [ -z "$(pidof $SVC)" ] && [ $n -lt 90 ]; do sleep 2; n=$((n+1)); done
  stop $SVC
  n=0
  while [ -n "$(pidof $SVC)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done

  if [ "$MODE" = "ultra" ]; then
    mount -o bind $ULTRA_LIB $LIB_DST 2>/dev/null
    for f in /data/adb/ultra/cpu/*/*/model/*.bytenn; do
      d="/system/etc/AlgSwift/s2/cpu/${f#/data/adb/ultra/cpu/}"
      mkdir -p "$(dirname $d)" 2>/dev/null
      mount -o bind "$f" "$d" 2>/dev/null
    done
    chcon -R u:object_r:system_file:s0 /system/etc/AlgSwift/s2/cpu 2>/dev/null
  fi
  chcon u:object_r:system_lib_file:s0 $LIB_DST 2>/dev/null
  start $SVC
) &
exit 0
