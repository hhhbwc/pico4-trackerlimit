#!/system/bin/sh
# v2.9.1 boot worker (single build, stock scheduling)
# 兼容库通过 priv-app 私有 nativeLibraryDir 生效（模块预置，Magisk 内核层挂载
# 早于 PMS 扫描），openxr_runtime 等其他进程不可见 —— 这是 v2.7 黑屏问题的修复。
# v2.9.1：自检同时记录边界/指针相关状态，并自动拉起 DirectTouch(KarlVis)
# 兼容监视器（dt_compat.sh）—— 全自动处理"边界确认按钮点不了"，
# 不需要用户手动执行任何动作。

LIB=/system/priv-app/PvrSwift/lib/arm64
LOG=/data/local/tmp/swift205_libpreload.log
MODDIR=$(dirname "$0")
RUNDIR=/data/adb/pico4_tracker

# ---------- 自检记录 ----------
{
  echo "--- $(date '+%F %T') ---"
  echo "PvrSwift version : $(dumpsys package com.pvr.swift 2>/dev/null | grep -m1 versionName | tr -d ' ')"
  for f in libswift.so libtrackingclient.pxr.so libswift205shim.so; do
    if [ -f "$LIB/$f" ]; then
      echo "$f : $(stat -c %s "$LIB/$f") bytes"
    else
      echo "$f : MISSING"
    fi
  done
  echo "shim in /system/lib64 : $([ -f /system/lib64/libswift205shim.so ] && echo PRESENT_BAD || echo absent_good)"
  echo "system trackingclient  : $(stat -c %s /system/lib64/libtrackingclient.pxr.so 2>/dev/null)"
  echo "swift processes        : $(pidof com.pvr.swift com.pvr.swift.service com.pvr.swift:avatar 2>/dev/null || echo none)"
  echo "swiftVersion prop      : $(getprop persist.pxr.tracking.swiftVersion 2>/dev/null)"
  if [ -f /data/data/com.pvr.swift/shared_prefs/swift_state.xml ] \
     && grep -qE "key_mod_wear_mode|key_mod_upper_limit" /data/data/com.pvr.swift/shared_prefs/swift_state.xml 2>/dev/null; then
    echo "mod-era prefs          : PRESENT_BAD (run rescue_pointer.sh)"
  else
    echo "mod-era prefs          : absent_good"
  fi
  echo "DirectTouch installed  : $(pm path com.picodirecttouch.lsposed >/dev/null 2>&1 && echo yes || echo no)"
} >> "$LOG"

# ---------- 自动拉起 DirectTouch 兼容监视器 ----------
# 只在 KarlVis 存在时才会常驻（dt_compat.sh 自身检测到无 DirectTouch 即退出）。
WATCHER=""
[ -f "$RUNDIR/dt_compat_watch.sh" ] && WATCHER="$RUNDIR/dt_compat_watch.sh"
[ -z "$WATCHER" ] && [ -f "$MODDIR/dt_compat.sh" ] && WATCHER="$MODDIR/dt_compat.sh"
if [ -n "$WATCHER" ]; then
  if [ -f "$RUNDIR/dt_compat_watch.pid" ] && kill -0 "$(cat "$RUNDIR/dt_compat_watch.pid" 2>/dev/null)" 2>/dev/null; then
    echo "dt compat watcher already running" >> "$LOG"
  else
    nohup sh "$WATCHER" >/dev/null 2>&1 &
    echo "dt compat watcher started ($WATCHER)" >> "$LOG"
  fi
fi

exit 0
