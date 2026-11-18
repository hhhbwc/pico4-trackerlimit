#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - install script (v2.9)
# ============================================================
# v2.9：v2.0-v2.2 改装 APK 路线的残留状态清理 + 边界/指针救援工具。
#   背景（"边界确认按钮点不了"冲突的模块侧根因）：
#   v2.0-v2.2 的补丁 APK 把 SwiftRepo.setSwiftDiscoverySwitch 的全部前置
#   条件（swiftVersion/powerMode/batteryLow/size<limit/isAppVisible）nop
#   成空操作，而后台 SwiftService（SCREEN_ON/OFF、BATTERY_LOW/OKAY 驱动）
#   会持续调用它 → 追踪站点 discovery/配对状态长期无条件驻留。
#   边界重确认/重标定走 VSTPanel（pvr.intent.action.swift.vst → XR 系统
#   层），卡死的面板层拦截指针射线 → 按钮可见、悬停圆圈消失、手柄与手势
#   均无法点击。原版 APK 守卫齐全，不存在该副作用。
#   v2.9 做两件事：升级时清掉改装 APK 写入的 mod 状态；提供 rescue.sh
#   （Magisk"执行"按钮 / adb 可调用）用于发作时解除卡死并采集诊断。
#
# v2.8 核心修复（保留）：兼容库在 /system/priv-app/PvrSwift/lib/arm64/
#   （priv-app 私有 nativeLibraryDir），openxr_runtime 等其他进程不可见。
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

# v2.0.0 shipped under pico4_swift205_libpreload. Installing both leaves two
# modules overlaying the same PvrSwift APK/libs; uninstalling either would
# delete the other's nativeLibraryDir. Refuse instead of stacking them.
for other in pico4_swift205_libpreload pico4_swift_force_enable; do
  if [ "$other" != "$MODID" ] && [ -d "/data/adb/modules/$other" ] \
     && [ ! -e "/data/adb/modules/$other/remove" ]; then
    abort "! Another Motion Tracker module is installed: $other" \
          "! Remove it first (touch /data/adb/modules/$other/remove, reboot), then flash this build."
  fi
done

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
# 4b. v2.9: v2.0-v2.2 改装 APK 时代的应用内状态清理
#     - swift_state.xml 里的 mod override 键（原版 APK 从不读，留着只会
#       在装回改装 APK 时复活旧行为）；其余键（隐私授权/绑定数/校准计数）
#       一律不动。
#     - 该步骤 best-effort：文件不存在或 sed 失败都不阻塞安装。
# ------------------------------------------------------------------
PREFS_XML=/data/data/com.pvr.swift/shared_prefs/swift_state.xml
if [ -f "$PREFS_XML" ]; then
  if grep -qE "key_mod_wear_mode|key_mod_upper_limit" "$PREFS_XML" 2>/dev/null; then
    cp "$PREFS_XML" "$PREFS_XML.bak_v29" 2>/dev/null
    sed -i '/key_mod_wear_mode/d; /key_mod_upper_limit/d' "$PREFS_XML" 2>/dev/null \
      && echo "[swift_force_enable] v2.0-era mod override prefs stripped (backup: swift_state.xml.bak_v29)"
  else
    echo "[swift_force_enable] no v2.0-era mod prefs (clean)"
  fi
fi

# ------------------------------------------------------------------
# 4c. v2.9: 安装边界/指针救援脚本（发作时可由 Magisk"执行"按钮或 adb 调用）
#     v2.9.1: 同时安装 DirectTouch(KarlVis) 自动兼容监视器 —— 开机由
#     service.sh 拉起，全自动处理"边界确认按钮点不了"，无需手动执行。
# ------------------------------------------------------------------
mkdir -p "$RUNDIR" 2>/dev/null
if [ -f "$MODPATH/rescue.sh" ]; then
  cp "$MODPATH/rescue.sh" "$RUNDIR/rescue_pointer.sh" 2>/dev/null \
    && chmod 755 "$RUNDIR/rescue_pointer.sh" 2>/dev/null \
    && echo "[swift_force_enable] rescue script -> $RUNDIR/rescue_pointer.sh"
fi
if [ -f "$MODPATH/dt_compat.sh" ]; then
  cp "$MODPATH/dt_compat.sh" "$RUNDIR/dt_compat_watch.sh" 2>/dev/null \
    && chmod 755 "$RUNDIR/dt_compat_watch.sh" 2>/dev/null \
    && echo "[swift_force_enable] DirectTouch compat watcher -> $RUNDIR/dt_compat_watch.sh (auto-start via service.sh)"
  rm -f "$RUNDIR/dt_compat_watch.pid" 2>/dev/null
fi

# ------------------------------------------------------------------
# 5. 修复脚本可执行权限（ZIP 打包可能丢失权限）
# ------------------------------------------------------------------
chmod 755 "$MODPATH/service.sh" "$MODPATH/action.sh" "$MODPATH/rescue.sh" "$MODPATH/post-fs-data.sh" "$MODPATH/uninstall.sh" 2>/dev/null || true

echo "[swift_force_enable] state=$(cat "$STATE" 2>/dev/null)"
echo "[swift_force_enable] done, reboot to apply"
exit 0
