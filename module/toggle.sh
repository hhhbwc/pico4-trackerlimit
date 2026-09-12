#!/system/bin/sh
# 算法切换开关: 原厂 1.0.0.47 <-> Ultra 1.0.0.54
# 模型挂载使用整目录 bind mount (stock 模型文件名与 ultra 不同, 逐文件挂载必失败)
MOD=/data/adb/modules/pico4_swift_force_enable
STATE=/data/adb/pico4_tracker/algo_state
ULTRA_LIB=/data/adb/ultra/libAlgSwiftBodyPose.so
STOCK_LIB=/data/adb/ultra/stock_lib.so
LIB_DST=/system/lib64/libAlgSwiftBodyPose.so
MODEL_SRC=/data/adb/ultra/cpu
MODEL_DST=/system/etc/AlgSwift/s2/cpu
SVC=pvrtrackingservice

CUR=$(cat $STATE 2>/dev/null)
if [ -z "$CUR" ]; then
  if [ -f "$MOD/system/lib64/libAlgSwiftBodyPose.so" ]; then CUR=ultra; else CUR=stock; fi
fi

echo "当前算法: $CUR"
echo "停止追踪服务..."
stop $SVC
n=0
while [ -n "$(pidof $SVC)" ] && [ $n -lt 20 ]; do sleep 1; n=$((n+1)); done

echo "清理旧挂载..."
while [ -n "$(grep " $LIB_DST" /proc/mounts | grep -v dm-4)" ]; do
  m=$(grep " $LIB_DST" /proc/mounts | grep -v dm-4 | head -1 | awk '{print $2}')
  [ -z "$m" ] && break
  umount "$m" 2>/dev/null || break
done
for m in $(grep '/system/etc/AlgSwift' /proc/mounts | grep -v 'dm-4' | cut -d' ' -f2); do
  umount "$m" 2>/dev/null
done
rm -f "$MOD/system/lib64/libAlgSwiftBodyPose.so"
rm -rf "$MOD/system/etc/AlgSwift"
mkdir -p "$MOD/system/lib64" "$MOD/system/etc/AlgSwift/s2/cpu"

if [ "$CUR" = "ultra" ]; then
  NEW=stock
  echo "切换到: 原厂算法 1.0.0.47"
  mount -o bind $STOCK_LIB $LIB_DST
  chcon u:object_r:system_lib_file:s0 $LIB_DST 2>/dev/null
else
  NEW=ultra
  echo "切换到: Ultra 算法 1.0.0.54"
  mount -o bind $ULTRA_LIB $LIB_DST
  chcon u:object_r:system_lib_file:s0 $LIB_DST 2>/dev/null
  if [ -d "$MODEL_SRC" ] && [ -d "$MODEL_DST" ]; then
    mount -o bind "$MODEL_SRC" "$MODEL_DST"
    chcon -R u:object_r:system_file:s0 "$MODEL_DST" 2>/dev/null
  fi
  cp $ULTRA_LIB "$MOD/system/lib64/libAlgSwiftBodyPose.so"
  cp -r $MODEL_SRC/. "$MOD/system/etc/AlgSwift/s2/cpu/"
fi

echo "$NEW" > $STATE
echo "启动追踪服务..."
start $SVC
sleep 8
echo "完成: 当前算法 = $NEW (服务: $(getprop init.svc.$SVC))"
