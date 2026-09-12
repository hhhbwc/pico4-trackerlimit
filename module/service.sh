#!/system/bin/sh
# 开机按 algo_state 挂载对应算法 (ultra/stock)
STATE=/data/adb/pico4_tracker/algo_state
ULTRA_LIB=/data/adb/ultra/libAlgSwiftBodyPose.so
STOCK_LIB=/data/adb/ultra/stock_lib.so
LIB_DST=/system/lib64/libAlgSwiftBodyPose.so
SVC=pvrtrackingservice

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
