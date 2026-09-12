# PICO 4 Motion Tracker Unlock (2.0.5)

让 PICO 4 标准版（ROM 5.13.x）完整使用 PICO 体感追踪器 2.0.5 应用，
包含 2/3/5 点追踪模式切换。

## 原理

- 通过 Magisk overlay 将修改版 PvrSwift.apk 放入 priv-app，获得特权权限
  （com.picovr.permission.SWIFT_ACCESS / os.permission.BIND_TEA_TRACKER_SERVICE）
- 绕过 ro.pxr.externalfunc 门禁（P4 标准版为 0，Ultra 为 1）
- libswift.so 兼容补丁：禁用 P4 缺失符号的 native 枚举路径（防崩溃），
  设备列表改由系统状态回调驱动
- 2/3/5 点模式切换通过应用内 override 即时生效
  （系统配置服务拒绝写入，固件槽位实际支持 5 个）

## 安装

1. Magisk → 模块 → 从本地安装本 zip
2. 重启
3. 打开"体感追踪器"应用

## 卸载

Magisk 中移除模块并重启即可，系统分区未被修改，自动恢复原版。

## 已知事项

- 5 点模式需要 5 台追踪器（P4 标准版固件槽位支持 5 个，未实测满配）
- 对在线状态的追踪器执行解绑可能导致其固件状态异常（连接数秒后自动关机），
  放回充电座充电或恢复出厂后可恢复
