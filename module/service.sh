#!/system/bin/sh
# v2.8 boot worker (single build, stock scheduling)
# 兼容库通过 priv-app 私有 nativeLibraryDir 生效（模块预置，Magisk 内核层挂载
# 早于 PMS 扫描），openxr_runtime 等其他进程不可见 —— 这是 v2.7 黑屏问题的修复。
# 本脚本只做自检并记录日志，不做任何挂载/调优/重启。

LIB=/system/priv-app/PvrSwift/lib/arm64
LOG=/data/local/tmp/swift205_libpreload.log

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
} >> "$LOG"

exit 0
