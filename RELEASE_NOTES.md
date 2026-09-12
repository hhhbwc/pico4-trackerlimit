# PICO 4 Motion Tracker Unlock v2.2

v2.2 是 v2.1 的稳定增强版，当前最终包基于 v33 APK（源码含 v32 修复 + 本轮清理/版本修正 + SwiftImpl 版本锁死）。

## v2.2 新增

- 🧠 Ultra BODYPOSE 1.0.0.54 算法内置：2/3/5 点分装 NN 模型 + 足底接触 LSTM，CPU 后端
- 🔘 Magisk 模块页新增算法切换按钮（原厂 ⇄ Ultra，即时生效、重启保持）
- 💾 穿戴模式/配对上限选择持久化（重启不再回默认）
- 🐛 修复首次引导选择 3 点时，配对上限被旧代码覆盖回 5
- 🐛 清理 `SwiftRepo.getSwiftVersion()` 不可达旧代码，避免旧版本切换/验证路径混淆
- 🐛 `SwiftImpl.getSwiftVersion()` 也锁死返回 2，彻底切断所有 JNI 版本查询路径，消除 CoverFragment/SwiftToggleV2Opt 的 VerifyError 风险
- 🔖 修正 Magisk 模块元数据为 `version=v2.2` / `versionCode=6`

## v2.1 内容（保留）

- ✅ 解锁体感追踪器 2.0.5 应用（绕过 `ro.pxr.externalfunc` 产品档位门禁）
- ✅ 特权权限完整（SWIFT_ACCESS / BIND_TEA_TRACKER_SERVICE，priv-app overlay 方式）
- ✅ 2 / 3 / 5 点追踪模式切换可用（应用内 override）
- ✅ 设备列表基于系统状态回调（兼容 P4 缺失的枚举接口，无崩溃）
- ✅ 系统分区零修改，卸载模块即恢复原版
- ✅ 首次全新安装自动解绑旧设备；覆盖安装保留已有绑定关系

## 安装

1. 确认已 root（Magisk 27+）
2. Magisk → 模块 → 从本地安装 `PICO4_MotionTracker_2.0.5_v2.2.zip`
3. 重启
4. 打开「体感追踪器」应用，正常配对/校准 → 开追

## 卸载

Magisk 中删除本模块 → 重启。系统分区从未被修改，自动恢复原版。

## 校验（v2.2 最终包）

| 文件 | MD5 | SHA-256 |
|---|---|---|
| `PICO4_MotionTracker_2.0.5_v2.2.zip` | `0b9f480d89488d7f17d8afd503c47f92` | `df01ef754c21f66bbe2b33ce4cb07a05325908b1bc66529c675e23313a17408e` |
| `swift205_patched_v33.apk` | `e91c9647fcbf3a808ca22e842de8e013` | `cca149154ea7f5c0f3d161b9be6e459a883590c6e7799f3d31f6ea2889b82de7` |

ZIP 内的 `system/priv-app/PvrSwift/PvrSwift.apk` 已验证与 `swift205_patched_v33.apk` 哈希一致。

## 文档

- [FIX_NOTES.md](FIX_NOTES.md) — 完整逆向记录与踩坑记录
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — 本文件

仅供学习研究，请支持正版。
