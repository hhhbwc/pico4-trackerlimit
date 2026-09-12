#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - Magisk module install script
# ============================================================
# 详细安装日志，失败自动落盘 /sdcard/pico4_install_<timestamp>.log
# ============================================================
INSTALL_LOG="/sdcard/pico4_install_$(date +%s).log"
exec 3>&1  # 保存原始 stdout 到 fd 3
exec 1>>"$INSTALL_LOG" 2>&1  # stdout/stderr 同时写文件和终端
set -x  # 开启 xtrace，每条命令执行前打印

echo "=== Pico4 Tracker Unlock 安装日志 ==="
echo "Time: $(date)"
echo "MODPATH=$MODPATH"
echo "PWD=$(pwd)"
echo "id=$(id)"
echo "MAGISK_VER=$MAGISK_VER"
echo "=== 环境信息 ==="
echo "PATH=$PATH"
echo "=== /proc/mounts 相关 ==="
grep -E 'pico4|pvr|AlgSwift' /proc/mounts
echo "=== /data/adb/modules 目录 ==="
ls -la /data/adb/modules/
echo "=== 模块目录 ==="
ls -la "$MODPATH" 2>/dev/null || echo "MODPATH 不存在: $MODPATH"
echo "=== /proc/mounts 相关 ==="
grep -E 'pico4|pvr|AlgSwift' /proc/mounts
echo "=== 开始安装 ==="

# 关键步骤封装
check_step() {
    local step_name="$1"
    if [ $? -ne 0 ]; then
        echo "[ERROR] $step_name 失败" >&2
        echo "=== 安装失败，详见日志: $INSTALL_LOG ===" >&2
        exit 1
    else
        echo "[OK] $step_name 成功"
    fi
}

# ============================================================
# 兼容覆盖安装：清理旧版本残留（幂等，升级/全新安装均安全）
# 注意：不能删除 /data/adb/modules/ 下的当前模块目录，
# 因为 Magisk 在 customize.sh 执行后才把 modules_update 复制过去。
# 只清理挂载点和 modules_update 残留即可。
# ============================================================

# 1. 卸载可能残留的挂载点（幂等，失败不报错）
umount /system/priv-app/PvrSwift/PvrSwift.apk 2>/dev/null
umount /system/lib64/libAlgSwiftBodyPose.so 2>/dev/null
for m in $(grep '/system/etc/AlgSwift' /proc/mounts 2>/dev/null | awk '{print $2}'); do
    umount "$m" 2>/dev/null
done

# 2. 只清理 modules_update 残留（不删 modules 下的当前目录）
rm -rf /data/adb/modules_update/pico4_swift_force_enable

echo "[swift_force_enable] 旧挂载已清理（覆盖安装模式）"
echo "--------------------------------------------------------"

MODID="pico4_swift_force_enable"
OLDDIR="/data/adb/modules/$MODID"
FLAGDIR="/data/adb/pico4_tracker"
APKNAME="PvrSwift.apk"

echo "[swift_force_enable] install start"

# backup stock apk (first install only)
ORIG_APK="/system/priv-app/PvrSwift/$APKNAME"
BACKUP="/data/adb/modules_backup/picoswift_orig_$APKNAME"
mkdir -p "/data/adb/modules_backup"

if [ -f "$ORIG_APK" ] && [ ! -f "$BACKUP" ]; then
    cp "$ORIG_APK" "$BACKUP" 2>/dev/null         && echo "[swift_force_enable] stock apk backed up"         || echo "[swift_force_enable] backup failed (non-fatal)"
fi

# ---------------------------------------------------------------
# One-time auto-unbind for FRESH installs only.
# Stock 2.0.4-era bonds are unusable by the 2.0-mode app and leave
# users stuck on the 1.0 pairing screen. Unbonding once at flash
# time gives every new user a clean slate; upgrades from our own
# module keep bonds untouched.
# ---------------------------------------------------------------
if [ -f "$OLDDIR/system/priv-app/PvrSwift/$APKNAME" ]; then
    echo "[swift_force_enable] upgrade detected - bonds kept"
else
    mkdir -p "$FLAGDIR"
    touch "$FLAGDIR/unbond_pending"
    echo "[swift_force_enable] fresh install - trackers will be unbonded once after reboot"
fi

# ---------------------------------------------------------------
# 算法切换套件: 安装 ultra/stock 算法库 + 模型 + 切换脚本
# (首次安装默认 ultra; 升级保留用户已选状态)
# ---------------------------------------------------------------
set -e
mkdir -p /data/adb/ultra /data/adb/pico4_tracker
# 复制算法库和模型 (使用 $MODPATH 获取模块文件实际路径)
cp -rf "$MODPATH/ultra/." /data/adb/ultra/ 2>/dev/null || true
cp -f "$MODPATH/toggle.sh" /data/adb/ultra/toggle.sh 2>/dev/null || true
chmod 755 /data/adb/ultra/toggle.sh 2>/dev/null || true
if [ ! -f /data/adb/pico4_tracker/algo_state ]; then
  echo ultra > /data/adb/pico4_tracker/algo_state
fi
echo "[swift_force_enable] 算法切换套件已安装 (Magisk 模块页点'执行'切换算法)"
echo "[swift_force_enable] done, reboot to apply"
exit 0