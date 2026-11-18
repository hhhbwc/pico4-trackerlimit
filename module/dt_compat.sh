#!/system/bin/sh
# ==================================================================
# PICO 4 Motion Tracker Unlock - DirectTouch (KarlVis) compat watcher
# v2.9.1 — 全自动，无需任何手动点击
# ==================================================================
#
# 冲突机制（源自对用户提供的 KarlVis O1.13.7S 的逆向）：
#   KarlVis 的 DirectTouch 是 LSPosed 模块（com.picodirecttouch.lsposed），
#   作用于 com.picoxr.xrshell 进程：
#     - Java 层 hook com.picoxr.xrshell.event.EventWindowProvider.updateWindow
#       （把窗口几何记入自己的注册表 dt_window_sizes）；
#     - 注入 native 库 libdirecttouch.so，内联代理（proxy/orig 模式）：
#         rayProxy/origRayUpdate       —— XRShell 引擎的"射线更新"
#         cursorProxy/origCursorUpdate —— "光标（悬停圆圈）更新"
#         syncProxy                    —— 面板管理器同步（PanelVector）
#         InputManager::InjectMotionEvent —— 给"自己的"面板注入触摸事件
#   即：指针射线命中判定与悬停圆圈绘制被 DirectTouch 接管，只有它注册
#   表里的面板被正常处理。体感追踪器的边界确认/重标定面板（PvrSwift
#   VSTPanel，经 native shell 服务创建的应用层，不走 EventWindowProvider）
#   不在注册表里 → 悬停圆圈消失、手柄与手势都无法点击。
#   没有 KarlVis 时引擎原版命中逻辑覆盖所有层，一切正常；没有追踪器
#   模块时该面板根本不会出现 —— 表现为"装了追踪器模块才坏"，实为叠加。
#
# 自动兼容策略（无用户交互）：
#   监听 logcat 中 VSTPanel 的 show/hide 生命周期：
#     面板弹出 → 临时 setprop persist.dt.enable 0（DirectTouch 总开关；
#                游戏内 2D 直触本就无用），面板消失后自动还原；
#     面板弹出超过 120s 且前台不是 PICO 自家界面（用户被卡住）→
#         自动 force-stop com.pvr.swift 解除卡死（不影响游戏内追踪
#         数据流——数据走 openxr_runtime → pvrtrackingservice 系统服务），
#         每次开机最多 3 次；前台是 com.pvr.swift（正常校准中）绝不干预。
#
# 开关（调试用，缺省 mode=1）：
#   setprop persist.pvr.dt_compat_mode 0   只记录不动手
#   setprop persist.pvr.dt_compat_mode 1   属性让位（缺省）
#   setprop persist.pvr.dt_compat_mode 2   属性让位 + 卡死自动解锁
# ==================================================================

DT_PKG=com.picodirecttouch.lsposed
PANEL_PKG=com.pvr.swift
RUNDIR=/data/adb/pico4_tracker
LOG=/data/local/tmp/pico4_dt_compat.log
PIDF=$RUNDIR/dt_compat_watch.pid
MODE_PROP=persist.pvr.dt_compat_mode
STUCK_SECS=120
FAILSAFE_SECS=900
MAX_STOPS=3
POLL=8
BUF_LINES=2000

log() {
  echo "$(date '+%F %T') $*" >> "$LOG" 2>/dev/null
  sz=$(stat -c %s "$LOG" 2>/dev/null || echo 0)
  [ "$sz" -gt 204800 ] && tail -c 102400 "$LOG" > "$LOG.t" 2>/dev/null && mv "$LOG.t" "$LOG" 2>/dev/null
  return 0
}

dt_installed() { pm path "$DT_PKG" >/dev/null 2>&1; }

panel_alive() {
  [ -n "$(pidof "$PANEL_PKG" 2>/dev/null)" ] || [ -n "$(pidof "$PANEL_PKG.service" 2>/dev/null)" ]
}

foreground_pkg() {
  # PUI 5.13.x 的输出行格式（实测真机）：
  #  " ResumedActivity:ActivityRecord{67524f3 u0 app.pkg/.MainActivity t2029}"
  # 多显示器会有多行，第一行 = 主屏（默认显示屏）。经文件中转避免
  # grep -m1 触发 dumpsys SIGPIPE 导致输出丢失（实机踩坑）。
  # 用纯 sh 字符串操作解析（toybox sed 对字符类+转义的处理不可靠，实机踩坑）。
  dumpsys activity activities > /data/local/tmp/.pico4_act_fg 2>/dev/null
  line=$(grep 'ResumedActivity:ActivityRecord{' /data/local/tmp/.pico4_act_fg 2>/dev/null | head -1)
  [ -z "$line" ] && return 0
  f=${line#*u0 }              # 截掉 "u0 " 及之前
  f=${f%%/*}                  # 截掉第一个 "/" 之后（".Activity t2029}"）
  f=${f%% *}                  # 兜底：无 "/" 格式时取首词
  case "$f" in
    *ResumedActivity*|*ActivityRecord*|*\{*) return 0 ;;  # 解析失败 → 视为 PICO 界面，不干预
  esac
  echo "$f"
}

# 0 = 前台是 PICO 自家界面（应用内校准/设置/桌面）→ 不干预
foreground_is_pico() {
  fg=$(foreground_pkg)
  case "$fg" in
    com.pvr.*|com.picovr.*|com.pico.*) return 0 ;;
    "") return 0 ;;
    *) return 1 ;;
  esac
}

restore_dt() {
  if [ -n "$OLD_DT" ]; then
    setprop persist.dt.enable "$OLD_DT" 2>/dev/null
    log "dt enable restored to '$OLD_DT'"
  elif [ "$OLD_DT_WAS_UNSET" = "1" ]; then
    resetprop -d persist.dt.enable >/dev/null 2>&1
    log "dt enable prop removed (was unset)"
  fi
  OLD_DT=""; OLD_DT_WAS_UNSET=0; DT_DOWN=0
  return 0
}

stand_down_dt() {
  [ "$DT_DOWN" = "1" ] && return 0
  cur=$(getprop persist.dt.enable 2>/dev/null)
  if [ "$cur" = "0" ]; then
    return 0            # 用户本来就是关的；不动、也不还原
  fi
  if [ -z "$cur" ]; then
    OLD_DT=""; OLD_DT_WAS_UNSET=1
  else
    OLD_DT="$cur"; OLD_DT_WAS_UNSET=0
  fi
  setprop persist.dt.enable 0 2>/dev/null
  DT_DOWN=1
  log "panel up -> persist.dt.enable 0 (was '${OLD_DT:-<unset>}')"
  return 0
}

panel_hidden() {
  SHOWN_SINCE=0
  STOPS=0
  [ "$DT_DOWN" = "1" ] && restore_dt
  return 0
}

mode() { getprop "$MODE_PROP" 2>/dev/null; }

# ---------------- init ----------------
touch "$LOG" 2>/dev/null
echo $$ > "$PIDF" 2>/dev/null
if ! dt_installed; then
  log "DirectTouch not installed; watcher exits"
  rm -f "$PIDF" 2>/dev/null
  exit 0
fi
log "watcher start pid=$$ (module v2.9.1, default mode 1)"

SHOWN_SINCE=0
STOPS=0
OLD_DT=""
OLD_DT_WAS_UNSET=0
DT_DOWN=0
LAST_EVT=""

while true; do
  sleep "$POLL"

  [ -e /data/adb/modules/pico4_swift_force_enable/remove ] && { log "module removed; exit"; rm -f "$PIDF" 2>/dev/null; exit 0; }
  [ -f /data/adb/modules/pico4_swift_force_enable/disable ] && continue

  # 面板进程已死 → 面板必已随之销毁（force-stop / 正常退出），复位。
  # 注意：不清 LAST_EVT —— 进程被系统重拉后，缓冲区里的旧 showVST 行
  # 时间戳相同，幂等键相等就不会重新武装（否则会震荡出无限 force-stop）。
  if ! panel_alive; then
    if [ "$DT_DOWN" = "1" ] || [ "$SHOWN_SINCE" != "0" ]; then
      panel_hidden
    fi
    continue
  fi

  evt=$(logcat -d -t "$BUF_LINES" 2>/dev/null | grep -a 'VSTPanel' | grep -aE 'showVST|hideVST' | tail -1)
  if [ -n "$evt" ] && [ "$evt" != "$LAST_EVT" ]; then
    LAST_EVT="$evt"
    case "$evt" in
      *hideVST*)
        log "event: panel hide"
        panel_hidden
        ;;
      *showVST*)
        SHOWN_SINCE=$(date +%s)
        m=$(mode); m=${m:-1}
        if [ "$m" != "0" ]; then
          stand_down_dt
        else
          log "panel shown (mode=0, watch only)"
        fi
        ;;
    esac
  fi

  # ---- 卡死检查（不依赖事件行是否仍在缓冲区里） ----
  if [ "$SHOWN_SINCE" != "0" ]; then
    m=$(mode); m=${m:-1}
    now=$(date +%s)
    age=$((now - SHOWN_SINCE))

    if [ "$m" = "2" ] && [ "$age" -ge "$STUCK_SECS" ] && [ "$STOPS" -lt "$MAX_STOPS" ] \
       && ! foreground_is_pico; then
      STOPS=$((STOPS + 1))
      log "stuck ${age}s (fg=$(foreground_pkg)) -> force-stop $PANEL_PKG (auto-dismiss #$STOPS)"
      am force-stop "$PANEL_PKG" >/dev/null 2>&1
      panel_hidden
      # LAST_EVT 保留（幂等键）：重拉后的进程看到同一行旧日志不会重新武装
      continue
    fi

    # 失效保护：hide 事件可能被日志滚动吞掉，15 分钟后按"已结束"复位
    if [ "$m" != "0" ] && [ "$DT_DOWN" = "1" ] && [ "$age" -ge "$FAILSAFE_SECS" ]; then
      log "failsafe: panel state stale (${age}s) -> restore dt"
      panel_hidden
      LAST_EVT=""
    fi
  fi
done
