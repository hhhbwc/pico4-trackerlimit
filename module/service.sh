#!/system/bin/sh
# 开机初始化:
#  1) 补齐 /data/adb/ultra 算法套件 (customize.sh 阶段模块文件可能尚未就绪)
#  2) 消费 unbond_pending 标记: 首次安装自动解绑一次 (tracker1/2/3)
#  3) 按 algo_state 挂载对应算法: ultra = 整目录 bind mount 模型 + 算法库
MOD=/data/adb/modules/pico4_swift_force_enable
STATE=/data/adb/pico4_tracker/algo_state
UNBOND_FLAG=/data/adb/pico4_tracker/unbond_pending
ULTRA_DIR=/data/adb/ultra
ULTRA_LIB=$ULTRA_DIR/libAlgSwiftBodyPose.so
LIB_DST=/system/lib64/libAlgSwiftBodyPose.so
MODEL_SRC=$ULTRA_DIR/cpu
MODEL_DST=/system/etc/AlgSwift/s2/cpu
SVC=pvrtrackingservice

# 1) ultra 套件补齐 (仅缺失时)
if [ -d "$MOD/ultra" ] && [ ! -f "$ULTRA_LIB" ]; then
  mkdir -p /data/adb/ultra /data/adb/pico4_tracker
  cp -rf "$MOD/ultra/." "$ULTRA_DIR/" 2>/dev/null
  cp -f "$MOD/toggle.sh" "$ULTRA_DIR/toggle.sh" 2>/dev/null
  chmod 755 "$ULTRA_DIR/toggle.sh" 2>/dev/null
fi

[ -s "$STATE" ] || echo ultra > "$STATE"
MODE=$(cat "$STATE")

(
  # 2) 首次安装自动解绑: 等服务起来 +15s (此时追踪器通常已离线,
  #    规避在线解绑导致固件掉电的坑), 用官方 tracker_test 解绑后清标记
  if [ -f "$UNBOND_FLAG" ]; then
    n=0
    while [ -z "$(pidof $SVC)" ] && [ $n -lt 90 ]; do sleep 2; n=$((n+1)); done
    sleep 15
    /system/bin/tracker_test unbond tracker1 2>/dev/null
    /system/bin/tracker_test unbond tracker2 2>/dev/null
    /system/bin/tracker_test unbond tracker3 2>/dev/null
    rm -f "$UNBOND_FLAG"
  fi

  # 3) Ultra 模式: 停服务 -> 挂载算法库与模型目录 -> 起服务。
  #    模型必须整目录 mount (stock 的模型文件名与 ultra 不同,
  #    逐文件挂载会因目标不存在而静默失败)。
  #    Stock 模式无需任何挂载, 不重启服务。
  if [ "$MODE" = "ultra" ] && [ -f "$ULTRA_LIB" ]; then
    n=0
    while [ -z "$(pidof $SVC)" ] && [ $n -lt 90 ]; do sleep 2; n=$((n+1)); done
    stop $SVC
    n=0
    while [ -n "$(pidof $SVC)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done

    mount -o bind $ULTRA_LIB $LIB_DST 2>/dev/null
    if [ -d "$MODEL_SRC" ] && [ -d "$MODEL_DST" ]; then
      mount -o bind "$MODEL_SRC" "$MODEL_DST" 2>/dev/null
      chcon -R u:object_r:system_file:s0 "$MODEL_DST" 2>/dev/null
    fi
    chcon u:object_r:system_lib_file:s0 $LIB_DST 2>/dev/null
    start $SVC
  fi
) &
exit 0
