#!/system/bin/sh
# v2.4 仅原版算法 (stock BODYPOSE 1.0.0.47)
# 不切换算法、不挂载库、不重启追踪服务，避免破坏手柄追踪

set -u

MOD=/data/adb/modules/pico4_swift_force_enable
RUNDIR=/data/adb/pico4_tracker
STATE=$RUNDIR/algo_state
LOCK=$RUNDIR/transition.lock
LOG=$RUNDIR/transition.log
UNBOND_FLAG=$RUNDIR/unbond_pending
UNBOND_RESULT=$RUNDIR/unbond_last_result
BOOT_STATUS=$RUNDIR/boot_transition.status
BOOT_DONE=$RUNDIR/boot_transition.done

SVC=pvrtrackingservice
APK_PKG=com.pvr.swift

umask 022
mkdir -p "$RUNDIR" 2>/dev/null

log() {
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$*" | tee -a "$LOG"
}

wait_service_ready() {
  n=0
  while [ $n -lt 60 ]; do
    if [ "$(getprop "init.svc.$SVC")" = "running" ] && pidof "$SVC" >/dev/null; then
      return 0
    fi
    sleep 1
    n=$((n + 1))
  done
  return 1
}

consume_unbond_pending() {
  [ -f "$UNBOND_FLAG" ] || return 0
  cmd=/system/bin/tracker_test
  [ -x "$cmd" ] || { log "ERROR: tracker_test missing"; return 1; }

  log "consuming unbond_pending"
  : > "$UNBOND_RESULT"
  chmod 644 "$UNBOND_RESULT" 2>/dev/null || true
  for t in tracker1 tracker2 tracker3; do
    rc=99
    n=0
    while [ $n -lt 6 ]; do
      "$cmd" unbond "$t" >>"$UNBOND_RESULT" 2>&1
      rc=$?
      [ $rc -eq 0 ] && break
      n=$((n + 1))
      sleep 3
    done
    [ $rc -eq 0 ] || { log "ERROR: unbond $t rc=$rc"; return 1; }
  done
  rm -f "$UNBOND_FLAG"
  log "unbond_pending completed"
  return 0
}

log "toggle start (stock only)"

# 等待追踪服务就绪（不重启它）
if ! wait_service_ready; then
  log "ERROR: service not ready"
  echo "error service_not_ready" > "$BOOT_STATUS"
  exit 73
fi

# 仅处理 fresh-install 的 unbond（如果有）
if [ -f "$UNBOND_FLAG" ]; then
  consume_unbond_pending || echo "error unbond_pending" > "$BOOT_STATUS"
fi

# 不切换算法、不挂载、不重启服务
echo "complete stock" > "$BOOT_STATUS"
log "complete: stock only (no algorithm switch, no service restart)"
echo "完成: 仅原版算法 (服务: $(getprop "init.svc.$SVC"))"

exit 0