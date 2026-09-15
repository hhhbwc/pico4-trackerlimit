#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - install script (v2.6)
# 覆盖安装 v2.0-v2.6：自动清理旧版本残留（ultra 算法套件、旧挂载点、旧模块目录残留文件）。
# 注意：不要删除 modules_update 目录（Magisk 在其内部执行 customize.sh，删除会导致升级静默失败）。

MODDIR=$(dirname "$0")
INSTALL_LOG="/sdcard/pico4_install_$(date +%s).log"
exec 2>&1 | tee "$INSTALL_LOG"
set -x

echo "=== Pico4 Tracker Unlock v2.6 install log ==="
echo "Time: $(date)"
echo "MODPATH=$MODPATH"
echo "MODDIR=$MODDIR"
echo "id=$(id)"

MODID=pico4_swift_force_enable
RUNDIR=/data/adb/pico4_tracker
STATE=$RUNDIR/algo_state
UNBOND_FLAG=$RUNDIR/unbond_pending
UNBOND_RESULT=$RUNDIR/unbond_last_result
APKNAME=PvrSwift.apk
OLD_MOD=/data/adb/modules/$MODID

echo "[swift_force_enable] v2.6 install start"

# ------------------------------------------------------------------
# 1. 清理 v2.0-v2.3 旧版残留：
#    - /data/adb/ultra（ultra 算法套件）
#    - 旧版写入自己模块目录的 system 覆盖文件（若残留，会被 Magisk 继续挂载）
#    - 旧版运行时 bind mount 会在重启后消失，无需处理
# ------------------------------------------------------------------
rm -rf /data/adb/ultra
if [ -d "$OLD_MOD" ]; then
  rm -rf "$OLD_MOD/system/lib64/libAlgSwiftBodyPose.so"
  rm -rf "$OLD_MOD/system/etc/AlgSwift"
  rm -rf "$OLD_MOD/ultra"
fi

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
# 3. 全新安装 vs 升级：全新安装重启后自动解绑一次（清掉 2.0.4 时代旧绑定）
#    升级保留已有绑定关系。
# ------------------------------------------------------------------
if [ -s "$STATE" ]; then
  echo "[swift_force_enable] upgrade detected - bonds kept"
  rm -f "$UNBOND_FLAG" "$UNBOND_RESULT"
  echo stock > "$STATE"
else
  echo "[swift_force_enable] fresh install - tracker unbond will be queued"
  touch "$UNBOND_FLAG"
  chmod 644 "$UNBOND_FLAG"
  echo stock > "$STATE"
fi

# ------------------------------------------------------------------
# 4. 使 PackageManager 解析缓存失效 —— 这是「版本切换后版本号不更新/打不开」的修复：
#    让系统在下次启动时重新解析（已被模块挂载的）APK。
# ------------------------------------------------------------------
for f in /data/system/package_cache/*/PvrSwift-* /data/system/package_cache/*/com.pvr.swift-*; do
  [ -e "$f" ] && rm -f "$f"
done

# ------------------------------------------------------------------
# 5. 修复脚本可执行权限（ZIP 打包可能丢失权限）
# ------------------------------------------------------------------
chmod 755 "$MODPATH/service.sh" "$MODPATH/toggle.sh" "$MODPATH/action.sh" "$MODPATH/post-fs-data.sh" "$MODPATH/uninstall.sh" 2>/dev/null || true

echo "[swift_force_enable] state=$(cat "$STATE" 2>/dev/null)"
echo "[swift_force_enable] done, reboot to apply"
exit 0
