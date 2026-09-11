# PICO 4 Motion Tracker Unlock v2.0

让 PICO 4 标准版（A8110, ROM 5.13.x）完整运行 PICO 体感追踪器 2.0.5 应用，
支持 2/3/5 点追踪模式切换。基于 Magisk 模块，不修改系统分区。

> 适用: PICO 4 标准版 (Phoenix / A8110) + Magisk 27+
> 理论上同样适用于被相同门禁限制的其他 PICO 4 系列 ROM

## 功能

- ✅ 解锁体感追踪器 2.0.5 应用（绕过 ro.pxr.externalfunc 产品档位门禁）
- ✅ 特权权限完整（SWIFT_ACCESS / BIND_TEA_TRACKER_SERVICE，priv-app overlay 方式）
- ✅ 2 / 3 / 5 点追踪模式切换可用（应用内 override，不依赖可写的系统配置服务）
- ✅ 设备列表基于系统状态回调（兼容 P4 缺失的枚举接口，无崩溃）
- ✅ 系统分区零修改，卸载模块即恢复原版

## 安装

1. 确认已 root（Magisk 27+）
2. Magisk → 模块 → 从本地安装 `PICO4_MotionTracker_2.0.5_v2.0.zip`
3. 重启
4. 打开「体感追踪器」应用，正常配对/校准

## 卸载

Magisk 中删除本模块 → 重启 → 完全恢复原版。

## 技术说明（给想了解原理的人）

| 层 | 问题 | 处理 |
|---|---|---|
| Java/Smali | externalfunc 门禁 + 版本检查 | 强制放行（feature/featureV2/isVersionSupported） |
| Native (libswift.so) | P4 缺少 getSwiftTrackerInfoVector 导出 | 禁用对应 vtable 调用路径，防止垃圾数据导致 JNI abort |
| 数据源 | 设备枚举接口不可用 | 改用系统 statusChangedCallback 缓存设备列表 |
| 模式切换 | PICO 配置服务拒绝应用写入系统键 | 应用内 override（upper limit / wear mode） |
| 配对 | discovery 开关被电源/可见性检查 ignore | 强制开启 |

完整逆向与踩坑记录见仓库内 `FIX_NOTES.md`。

## 已知限制

- **5 点模式需要 5 台追踪器**。P4 标准版固件实际有 5 个配对槽位
  （MCU tracker_num=5），满配 5 点理论上可行但未实测
- 对**在线状态**的追踪器解绑可能导致其固件异常（连接数秒后自动关机），
  放回充电座充电或恢复出厂设置后可恢复
- 系统 OTA 后模块可能失效，需重新安装
- 修改版 APK 使用测试签名，请勿覆盖安装原版（走模块 overlay 无此问题）

## 校验

```
MD5:    3f8c378bc7e705e28fb1551a4789dd44
SHA256: 42be4bb94919cfa5ea8db4549c14bd8966df363e82020331222993c1c9f81fe5
```

## 致谢

基于 PICO Motion Tracker com.pvr.swift 2.0.5 (versionCode 200005045)。
仅供学习研究，请支持正版。
