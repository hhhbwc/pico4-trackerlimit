#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - install script (v2.8)
# ============================================================
# v2.8 核心修复：兼容库从 /system/lib64（全局挂载）迁到
#   /system/priv-app/PvrSwift/lib/arm64/（priv-app 私有 nativeLibraryDir）。
#   v2.7 的全局挂载会让 openxr_runtime 等所有加载 trackingclient 的进程
#   拉入 shim，导致 SIGBUS 崩溃循环 -> tombstone 累积 -> 黑屏（实测 447 个）。
#   v2.8 与 libpreload v2.0.0 方案同构，真机验证 0 崩溃、3 台追踪器正常枚举。
#
# 同时保留 v2.7 成果：旧版残留清理、性能属性还原、PMS 解析缓存失效、APK 备份。
# 变更：不再自动解绑追踪器（unbond 需 root 且有风险，改为安装日志提示手动命令）。
# ============================================================

MODDIR=$(dirname "$0")
INSTALL_LOG="/sdcard/pico4_install_$(date +%s).log"
exec 2>&1 | tee "$INSTALL_LOG"
set -x

echo "=== Pico4 Tracker Unlock v2.8 install log ==="
echo "Time: $(date)"
echo "MODPATH=$MODPATH"
echo "MODDIR=$MODDIR"
echo "id=$(id)"

MODID=pico4_swift_force_enable
RUNDIR=/data/adb/pico4_tracker
STATE=$RUNDIR/algo_state
APKNAME=PvrSwift.apk
OLD_MOD=/data/adb/modules/$MODID

echo "[swift_force_enable] v2.8 install start"

# ------------------------------------------------------------------
# 1. 清理 v2.0-v2.7 旧版残留
#    - /data/adb/ultra（ultra 算法套件）
#    - 旧版写进自己模块目录的覆盖文件
#    - 旧版（v2.6/v2.7）挂在 system/lib64 的全局兼容库
#      （Magisk 覆盖安装会替换整个模块目录，这里做防御性清理）
# ------------------------------------------------------------------
rm -rf /data/adb/ultra
if [ -d "$OLD_MOD" ]; then
  rm -rf "$OLD_MOD/system/lib64/libAlgSwiftBodyPose.so"
  rm -rf "$OLD_MOD/system/lib64/libswift205shim.so"
  rm -rf "$OLD_MOD/system/lib64/libtrackingclient.pxr.so"
  rm -rf "$OLD_MOD/system/etc/AlgSwift"
  rm -rf "$OLD_MOD/ultra"
fi
# 当前内存中若已挂载旧全局库，尝试卸载（重启后自然消失，best-effort）
umount /system/lib64/libswift205shim.so 2>/dev/null
umount /system/lib64/libtrackingclient.pxr.so 2>/dev/null

# ------------------------------------------------------------------
# 1b. 单档 = 原厂调度：还原旧性能档（v2.4-v2.6 performance/extreme）
#     写过的持久化属性（立即 best-effort + 下次开机兜底）
# ------------------------------------------------------------------
resetprop -d persist.pvr.performance_mode 2>/dev/null || true
mkdir -p /data/adb/service.d
cat > /data/adb/service.d/pico4_v28_prop_cleanup.sh << 'EOS'
#!/system/bin/sh
v=$(getprop persist.pvr.performance_mode); [ -n "$v" ] && setprop persist.pvr.performance_mode ""
v=$(getprop af.fast_track_multiplier); [ -n "$v" ] && setprop persist.af.fast_track_multiplier "" 2>/dev/null; [ -n "$v" ] && setprop af.fast_track_multiplier ""
v=$(getprop persist.psensor.screenoff.delay); [ "$v" = "60" ] && setprop persist.psensor.screenoff.delay 10
v=$(getprop persist.psensor.sleep.delay); [ "$v" = "60" ] && setprop persist.psensor.sleep.delay 15
rm -f /data/adb/service.d/pico4_v28_prop_cleanup.sh
EOS
chmod 755 /data/adb/service.d/pico4_v28_prop_cleanup.sh

# ------------------------------------------------------------------
# 2. 备份原版 APK（仅首次）
# ------------------------------------------------------------------
ORIG_APK=/system/priv-app/PvrSwift/$APKNAME
BACKUP=/data/adb/modules_backup/picoswift_orig_$APKNAME
mkdir -p /data/adb/modules_backup "$RUNDIR"
if [ -f "$ORIG_APK" ] && [ ! -f "$BACKUP" ]; then
  cp "$ORIG_APK" "$BACKUP" 2>/dev/null || echo "[swift_force_enable] backup failed (non-fatal)"
fi

# ------------------------------------------------------------------
# 3. 绑定关系：一律保留，绝不自动解绑。
#    （v2.2-v2.7 的 fresh-install 自动 unbond 已移除——解绑需要 root 且有固件掉电风险）
#    如果你在原厂 2.0.4 上配对过追踪器、装完模块后应用卡在旧版配对界面，
#    可手动逐一清理旧绑定后重新配对：
#      su -c "/system/bin/tracker_test unbond tracker1"
#      su -c "/system/bin/tracker_test unbond tracker2"
#      su -c "/system/bin/tracker_test unbond tracker3"
# ------------------------------------------------------------------
echo "stock" > "$STATE"
chmod 644 "$STATE"
echo "[swift_force_enable] bonds kept (no auto-unbond in v2.8)"

# ------------------------------------------------------------------
# 4. 使 PackageManager 解析缓存失效 —— 版本号不更新/应用打不开的修复：
#    让系统在下次启动时重新解析（已被模块挂载的）APK。
# ------------------------------------------------------------------
for f in /data/system/package_cache/*/PvrSwift-* /data/system/package_cache/*/com.pvr.swift-*; do
  [ -e "$f" ] && rm -f "$f"
done

# ------------------------------------------------------------------
# 5. 修复脚本可执行权限（ZIP 打包可能丢失权限）
# ------------------------------------------------------------------
chmod 755 "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/post-fs-data.sh" "$MODPATH/uninstall.sh" 2>/dev/null || true

echo "[swift_force_enable] state=$(cat "$STATE" 2>/dev/null)"
echo "[swift_force_enable] done, reboot to apply"
exit 0
