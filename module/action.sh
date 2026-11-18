#!/system/bin/sh
# PICO 4 Motion Tracker Unlock (2.0.5) v2.9.1 — Magisk "Action" button
# Runs the boundary/pointer rescue + diagnostics from rescue.sh.
# NOTE: 正常情况下无需手动执行 —— dt_compat.sh 监视器开机自动运行，
# 全自动处理 KarlVis(DirectTouch) 与体感追踪边界面板的冲突。
# 本按钮仅用于：手动立即救援 + 导出诊断包。

MODDIR=$(dirname "$0")
echo "=============================================="
echo " PICO 4 Motion Tracker Unlock (2.0.5) v2.9.1"
echo " Boundary / pointer rescue + diagnostics"
echo "=============================================="
echo ""
echo "[RU] Обычно вручную запускать НЕ нужно: с v2.9.1 совместимость"
echo "[RU] с KarlVis/DirectTouch обеспечивается автоматически при загрузке"
echo "[RU] (dt_compat watcher). Кнопка нужна только для немедленного"
echo "[RU] восстановления и выгрузки диагностики."
echo ""
echo "[ZH] 正常情况下无需手动执行：v2.9.1 起兼容监视器开机自动运行。"
echo "[ZH] 本按钮只用于立即救援 + 导出诊断包。"
echo ""

sh "$MODDIR/rescue.sh"
RC=$?

echo ""
echo "=============================================="
if [ "$RC" = 0 ]; then
  echo " Rescue finished. Game tracking data is unaffected"
  echo " (openxr_runtime -> pvrtrackingservice is a system"
  echo "  service, not part of this app)."
  echo ""
  echo " [RU] Готово. Трекинг в играх не прерывается."
  echo " [RU] Диагностика сохранена в /sdcard/pico4_diag_*.log"
  echo ""
  echo " [ZH] 完成。游戏内追踪不受影响。诊断日志在"
  echo " [ZH] /sdcard/pico4_diag_*.log。"
else
  echo " Rescue script failed (rc=$RC). Report /sdcard logs."
fi
echo "=============================================="
exit 0
