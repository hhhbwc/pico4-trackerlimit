#!/system/bin/sh
echo "=============================================="
echo " PICO 4 Motion Tracker Unlock (2.0.5) v2.8"
echo " Single build | STOCK scheduling (as-is)"
echo "=============================================="
echo "v2.8 fix: compat libs moved out of /system/lib64"
echo "into the priv-app private lib dir - fixes the"
echo "openxr_runtime crash-loop / black screen of v2.7."
LIB=/system/priv-app/PvrSwift/lib/arm64
for f in libswift.so libtrackingclient.pxr.so libswift205shim.so; do
  if [ -f "$LIB/$f" ]; then
    echo "  [ok] $f ($(stat -c %s "$LIB/$f") bytes)"
  else
    echo "  [!!] $f MISSING"
  fi
done
[ -f /system/lib64/libswift205shim.so ] && echo "  [!!] global shim still mounted (reboot needed)" || echo "  [ok] no global shim"
echo ""
echo "Tracker pairing kept as-is. No auto-unbond."
echo "Perf tuning lives in pico4-power-mode."
echo ""
echo "[RU] v2.8: библиотеки перенесены из /system/lib64 в"
echo "     приватный каталог приложения - исправлены"
echo "     краши openxr_runtime и чёрный экран v2.7."
echo ""
echo "[ZH] v2.8：兼容库迁出 /system/lib64，修复 v2.7 的"
echo "     openxr 崩溃循环与黑屏问题。保留绑定，不自动解绑。"
echo "=============================================="
exit 0
