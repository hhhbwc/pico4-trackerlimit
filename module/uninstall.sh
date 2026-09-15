#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - uninstall cleanup (v2.6)
# 1) 使 PMS 解析缓存失效 -> 下次启动重新解析并恢复系统原版应用 (2.0.4)
# 2) 恢复被旧版性能包持久化写入的系统属性（best-effort，仅在值确实被改过时写回）
# 3) 保留 /data/adb/pico4_tracker（记忆此前安装，避免重装时重复解绑）
#    保留 /data/adb/modules_backup 中的原版 APK 备份（应急恢复用）

for f in /data/system/package_cache/*/PvrSwift-* /data/system/package_cache/*/com.pvr.swift-*; do
  [ -e "$f" ] && rm -f "$f"
done

# 立即清掉内存中的性能模式值（旧版 setprop 曾写入）
resetprop -d persist.pvr.performance_mode 2>/dev/null

# 一次性脚本：在本次启动后期（property_service 就绪后）把可能被改过的属性写回出厂值，
# 仅在当前值与出厂值不同时才写入（避免为原本未设置的属性新增持久化条目）。然后自删除。
mkdir -p /data/adb/service.d
cat > /data/adb/service.d/pico4_prop_cleanup.sh << 'EOS'
#!/system/bin/sh
v=$(getprop persist.pvr.performance_mode); [ -n "$v" ] && setprop persist.pvr.performance_mode ""
v=$(getprop persist.psensor.screenoff.delay); [ "$v" != "10" ] && setprop persist.psensor.screenoff.delay 10
v=$(getprop persist.psensor.sleep.delay); [ "$v" != "15" ] && setprop persist.psensor.sleep.delay 15
rm -f /data/adb/service.d/pico4_prop_cleanup.sh
EOS
chmod 755 /data/adb/service.d/pico4_prop_cleanup.sh

echo "PICO 4 Motion Tracker Unlock removed - stock app restored on next boot."
exit 0
