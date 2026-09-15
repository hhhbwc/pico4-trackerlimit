#!/system/bin/sh
# PICO 4 Motion Tracker Unlock - post-fs-data (v2.6)
# 每次启动时先于 PackageManager 服务清掉 com.pvr.swift 的解析缓存，
# 确保系统重新解析（被模块挂载的）2.0.5 APK：
#   - 安装/升级后：版本号正确变为 2.0.5、权限/元数据正确
#   - 避免 PUI 5.13.x 上 package_cache 残留导致的“版本显示卡在旧版/应用打不开”问题

for f in /data/system/package_cache/*/PvrSwift-* /data/system/package_cache/*/com.pvr.swift-*; do
  [ -e "$f" ] && rm -f "$f"
done
exit 0
