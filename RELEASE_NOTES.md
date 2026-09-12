# PICO 4 Motion Tracker Unlock v2.3

v2.3 是 v2.2 的修复版，全部改动在模块脚本侧（APK 与 v2.2 相同，仍为 v33）。
已在 PICO 4 标准版（A8110 / ROM 5.13.7 / Magisk 27）真机验证：
v2.0 → v2.2 → v2.3 覆盖升级、Ultra ⇄ 原厂双向切换、应用无崩溃。

## v2.3 修复

- 🐛 **修复 NN 模型挂载（重要）**：stock 与 Ultra 的模型文件名不同（`initpose_*.bytenn` vs `tracker*_20250429.bytenn`），旧版逐文件 bind mount 必然失败——Ultra 模式一直只换了算法库、没带模型在跑。改为**整目录 bind mount**，真机验证 `BODYPOSE version` 随切换正确变为 1.0.0.54 / 1.0.0.47
- 🐛 恢复 `service.sh` 消费 `unbond_pending` 标记：首次全新安装自动解绑一次（tracker1/2/3，官方 `tracker_test`，等服务就绪 +15s 规避在线解绑掉电坑）；该功能此前在 service.sh 改写时丢失
- 🐛 修复 `customize.sh` 删除 `modules_update` 导致 Magisk 覆盖升级静默失败（v2.0 → v2.2 升级后仍是旧版的根因之一）
- 🐛 修复 shell 脚本 CRLF 行尾导致设备上 `sh` 解析失败（执行按钮无法切换算法）
- 🐛 `service.sh` 开机自动补全 `ultra/` 算法套件（customize.sh 执行阶段模块文件可能尚未解压完）
- 🐛 stock 模式开机不再无谓重启追踪服务
- 🐛 `SwiftRepo` / `SwiftImpl` 的 `getSwiftVersion()` 双重锁死返回 2，彻底消除版本查询相关 VerifyError
- 🐛 清理 `SwiftRepo.getSwiftVersion()` 不可达死代码
- 🔖 模块元数据 `version=v2.3` / `versionCode=7`

## v2.2 功能（全部保留）

- 🧠 Ultra BODYPOSE 1.0.0.54 算法内置：2/3/5 点分装 NN 模型 + 足底接触 LSTM（CPU 后端）
- 🔘 Magisk 模块页「执行」按钮一键切换算法（原厂 ⇄ Ultra，即时生效、重启保持）
- 💾 穿戴模式/配对上限选择持久化（重启不再回默认）
- 🐛 首次引导选择 3 点时配对上限不再被覆盖回 5
- ✅ 解锁体感追踪器 2.0.5（绕过 `ro.pxr.externalfunc` 门禁，priv-app overlay，系统分区零修改）
- ✅ 2 / 3 / 5 点追踪模式切换、设备列表状态回调兼容
- ✅ 覆盖安装保留已有绑定；全新安装自动解绑一次

## 安装

1. 确认已 root（Magisk 27+）
2. Magisk → 模块 → 从本地安装 `PICO4_MotionTracker_2.0.5_v2.3.zip`
3. 重启
4. 打开「体感追踪器」应用，正常配对/校准 → 开追

## 从旧版升级

v2.0 / v2.1 / v2.2 直接安装本 ZIP 即可，**无需先卸载**，重启后生效；已配对追踪器的绑定关系保留。

## 卸载

Magisk 中删除本模块 → 重启。系统分区从未被修改，自动恢复原版。

## 校验（v2.3）

| 文件 | MD5 | SHA-256 |
|---|---|---|
| `PICO4_MotionTracker_2.0.5_v2.3.zip` | `410ba8e7c564f82189215d5abd40df2e` | `8d0b23b57397f43b10c607c0209baab7e487421b6598a8bc0549fa08490ab23a` |
| `swift205_patched_v33.apk` | `e91c9647fcbf3a808ca22e842de8e013` | `cca149154ea7f5c0f3d161b9be6e459a883590c6e7799f3d31f6ea2889b82de7` |

ZIP 内的 `system/priv-app/PvrSwift/PvrSwift.apk` 已验证与 `swift205_patched_v33.apk` 哈希一致。

## 文档

- [FIX_NOTES.md](FIX_NOTES.md) — 完整逆向记录与踩坑记录
- [RELEASE_NOTES.md](RELEASE_NOTES.md) — 本文件

仅供学习研究，请支持正版。
