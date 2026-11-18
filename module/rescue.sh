#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - boundary/pointer rescue & diagnostics (v2.9)
# ==================================================================
# 用途：修复"边界确认按钮点不了 / 指针上没有确认圆圈"的卡死状态，
#       并在问题复现时采集证据（窗口层归属 / 属性 / 日志）。
#
# 背景：v2.0-v2.2 时代的补丁 APK 把 SwiftRepo.setSwiftDiscoverySwitch 的
#       全部前置条件（isAppVisible / powerMode / batteryLow / size<limit）
#       nop 成了空操作。SwiftService（后台进程 com.pvr.swift.service）在
#       SCREEN_ON/OFF、BATTERY_LOW/OKAY 时无条件调用它 → 追踪站点长期处于
#       discovery/配对状态。边界重确认/重标定流程恰好走 VSTPanel
#       （pvr.intent.action.swift.vst → TYPE_ERROR_IN_WORLD 系统层），
#       卡死的面板层会拦截指针射线：按钮可见、悬停圆圈消失、手柄和手势都
#       无法点击。原版 APK（v2.4+ 路线）没有这些 nop，守卫齐全。
#
# 运行方式（任选其一）：
#   - Magisk 应用 → 模块 → 本模块的"执行"按钮（action.sh 会调用本脚本）
#   - adb shell su -c "sh /data/adb/pico4_tracker/rescue_pointer.sh"
#
# 说明：强停 com.pvr.swift 不会中断游戏内的追踪数据流 —— VRChat 拿数据走
#       openxr_runtime -> pvrtrackingservice（系统原生服务），不经过本应用；
#       被杀掉的只是应用自己的 UI / 通知 / VST 面板窗口层。
# ==================================================================

RUNDIR=/data/adb/pico4_tracker
DIAG=/sdcard/pico4_diag_$(date +%s).log
PREFS=/data/data/com.pvr.swift/shared_prefs/swift_state.xml

echo "=== PvrSwift pointer rescue (v2.9) ==="

# ------------------------------------------------------------------
# 0. 现场：应用版本 / 存活进程
# ------------------------------------------------------------------
echo "[state] versionName: $(dumpsys package com.pvr.swift 2>/dev/null | grep -m1 versionName | tr -d ' ')"
for p in $(pidof com.pvr.swift) $(pidof com.pvr.swift:avatar) $(pidof com.pvr.swift.service); do
  echo "[state] alive pid=$p ($(cat /proc/$p/cmdline 2>/dev/null))"
done

# 最近是否弹出过 VST 面板（证据：面板层被武装过）
VST_LOG=$(logcat -d -t 300 2>/dev/null | grep -cE "VSTPanel.*(showVST|init view|onAddView)|PvrApi.*onAddView")
echo "[state] recent VST panel log hits (last 300 lines): $VST_LOG"

# ------------------------------------------------------------------
# 0b. DirectTouch (KarlVis) 状态 —— "边界确认按钮点不了"的另一半冲突方
#     DirectTouch 用 native 代理接管了 xrshell 的射线/光标更新
#     （rayProxy/cursorProxy），只处理自己注册表里的面板；
#     PvrSwift 的 VST 边界面板不在其中 → 悬停圆圈消失、无法点击。
# ------------------------------------------------------------------
if pm path com.picodirecttouch.lsposed >/dev/null 2>&1; then
  echo "[karlvis] DirectTouch module: INSTALLED"
  echo "[karlvis] persist.dt.enable = '$(getprop persist.dt.enable)'"
  echo "[karlvis] compat mode      = '$(getprop persist.pvr.dt_compat_mode)' (default 1)"
  echo "[karlvis] compat watcher   = $(cat /data/adb/pico4_tracker/dt_compat_watch.pid 2>/dev/null || echo 'not running')"
  echo "[karlvis] watcher log      = $(tail -3 /data/local/tmp/pico4_dt_compat.log 2>/dev/null | tr '\n' ' | ')"
  if [ -x /data/adb/lspd/cli ]; then
    echo "[karlvis] lspd scope (xrshell/shortcut):"
    /data/adb/lspd/cli scope ls com.picodirecttouch.lsposed 2>/dev/null | grep -E "xrshell|shortcut|systemext|settings" | sed 's/^/    /'
  fi
else
  echo "[karlvis] DirectTouch module: not installed"
fi

# ------------------------------------------------------------------
# 1. 救援：强停 com.pvr.swift 全部进程
#    窗口层随进程死亡被系统回收，卡死的 VST 面板立即消失。
#    系统下次需要时会按原版守卫重新拉起服务。
#    若装了 KarlVis/DirectTouch：救援期间临时关闭其总开关
#    （persist.dt.enable 0），防止面板重弹时再次失去指针；
#    兼容监视器在面板消失后会自动还原该属性。
# ------------------------------------------------------------------
if pm path com.picodirecttouch.lsposed >/dev/null 2>&1; then
  echo "[rescue] DirectTouch present -> standing down (persist.dt.enable 0) during rescue"
  if [ "$(getprop persist.dt.enable)" != "0" ]; then
    setprop persist.dt.enable 0
    DT_WAS=1
  fi
fi
echo "[rescue] force-stop com.pvr.swift ..."
am force-stop com.pvr.swift 2>/dev/null || echo "[rescue] am force-stop failed (non-fatal)"
sleep 1
ALIVE=$(pidof com.pvr.swift com.pvr.swift.service com.pvr.swift:avatar 2>/dev/null)
if [ -n "$ALIVE" ]; then
  echo "[rescue] still alive ($ALIVE), killing via killall ..."
  killall com.pvr.swift com.pvr.swift.service 2>/dev/null
fi
echo "[rescue] done. overlay processes stopped: $(pidof com.pvr.swift com.pvr.swift.service 2>/dev/null || echo none)"
if [ "${DT_WAS:-0}" = "1" ]; then
  echo "[rescue] note: persist.dt.enable left at 0; the compat watcher restores it"
  echo "[rescue] automatically when the tracker panel is gone (or setprop persist.dt.enable 1)."
fi

# ------------------------------------------------------------------
# 2. 清理 v2.0-v2.2 改装 APK 留下的 mod override 键
#    （原版 APK 从不读这两个键；其他状态一律不动，
#    避免误清隐私授权/校准计数/绑定数）
# ------------------------------------------------------------------
if [ -f "$PREFS" ]; then
  if grep -qE "key_mod_wear_mode|key_mod_upper_limit" "$PREFS" 2>/dev/null; then
    cp "$PREFS" "$PREFS.bak_rescue" 2>/dev/null
    sed -i '/key_mod_wear_mode/d; /key_mod_upper_limit/d' "$PREFS" 2>/dev/null
    echo "[rescue] stripped mod-era override keys from swift_state.xml (backup: swift_state.xml.bak_rescue)"
  else
    echo "[rescue] no mod-era override keys found (already clean)"
  fi
else
  echo "[rescue] swift_state.xml not found (app never fully started?)"
fi

# ------------------------------------------------------------------
# 3. 诊断采集（写入 $DIAG，问题复发时把该文件发给开发者）
# ------------------------------------------------------------------
{
  echo "--- pico4 pointer diag $(date '+%F %T') ---"
  echo "== module =="; ls /data/adb/modules/pico4_swift_force_enable 2>/dev/null
  echo "== props (swift/pxr/pui) =="; getprop | grep -iE "swift|pxr|pui\.|externalfunc"
  echo "== DirectTouch/KarlVis props =="; getprop | grep -iE "dt\.|karlvis|directtouch"
  echo "== DirectTouch module =="; pm path com.picodirecttouch.lsposed 2>/dev/null || echo "not installed"
  echo "== lspd scopes =="; [ -x /data/adb/lspd/cli ] && /data/adb/lspd/cli scope ls com.picodirecttouch.lsposed 2>/dev/null || echo "cli unavailable"
  echo "== compat watcher log =="; cat /data/local/tmp/pico4_dt_compat.log 2>/dev/null | tail -40
  echo "== PvrSwift parse =="; dumpsys package com.pvr.swift 2>/dev/null | grep -E "versionName|flags=|privateFlags=|SWIFT_ACCESS|BIND_TEA"
  echo "== processes =="; ps -A 2>/dev/null | grep -E "pvr|pico"
  echo "== windows (pvr/pui/xr) =="; dumpsys window 2>/dev/null | grep -iE "Window #|mOwnerUid|com\.pvr\.swift|com\.pvr\.pui|com\.pico|typeExt|isFocusable|flags=0x" | head -80
  echo "== surfaceflinger layers =="; dumpsys SurfaceFlinger --list 2>/dev/null | grep -iE "swift|pvr|pui|xr" | head -60
  echo "== tracking service =="; dumpsys activity services com.pvr.swift 2>/dev/null | head -60
  echo "== logcat (swift/vst/pui related) =="; logcat -d -t 1200 2>/dev/null | grep -aiE "VSTPanel|PvrApi|SwiftService|SwiftReceiver|SwiftImpl|swift205|Calibration|boundary|Boundary|guardian|pvr\.intent|pxr\.intent" | tail -300
  echo "== logcat (DirectTouch related) =="; logcat -d -t 1200 2>/dev/null | grep -aiE "DirectTouch|picodirecttouch|rayProxy|cursorProxy|EventWindowProvider" | tail -120
} > "$DIAG" 2>&1
chmod 644 "$DIAG" 2>/dev/null

echo ""
echo "[done] rescue applied."
echo "[done] diag saved: $DIAG"
echo "[RU]   Восстановление применено. Диагностика: $DIAG"
echo "[ZH]   救援已执行。诊断文件：$DIAG"
echo ""
echo "If the boundary confirm button still fails after this,"
echo "send the diag file + ROM version to the developer."
echo "[RU] Если после этого кнопка подтверждения границы всё ещё"
echo "[RU] не нажимается — отправьте разработчику этот diag-файл."
exit 0
