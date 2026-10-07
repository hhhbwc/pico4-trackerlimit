# PICO 4 Motion Tracker Unlock (2.0.5) v2.8.1 — 小版本更新

> 主模块无代码变更（v2.8 结构稳定，0 崩溃基线保持）。本次为**可选实验性调参附加模块** + **.cpt 格式规范文档**。

## 新增

### 🎛️ `pico4_algo_tuning_v0.1.1.zip`（可选附加模块，EXPERIMENTAL）

把 BODYPOSE / 追踪器运行时配置（`.cpt`）改为激进档：

| 配置 | 参数 |
|---|---|
| 全身解算（swift_body_online） | 解算线程绑核 `cpu[4,5,6,7]`、RT 优先级 `8`、解算频率 `200Hz`（输入+输出） |
| 追踪器预测（swift_tracker_online） | 线程绑核 `cpu[4,5,6,7]`、RT 优先级 `5`、优化迭代 `n_iter 20`、`verbose off` |
| 手柄（hawk_controller_online） | **原样未动** |

- 与 v2.8 主模块共存，独立回滚：`touch /data/adb/modules/pico4_algo_tuning/disable && reboot`
- 内置**安装时格式守卫**：检测到 CRLF 的 .cpt 直接拒绝安装（崩循环防线）
- ⚠️ EXPERIMENTAL：已验证"不崩"，调参收益待实际佩戴验证

### 📄 `CPT_FORMAT.md`

.cpt 二进制格式规范（AES-128-ECB / PKCS7 / **LF-only base64** / **尾部 NUL**）+ 一次真实崩循环事故的完整记录。要点：**服务失败模式是崩循环，不是报错也不是降级 stock** —— 所有要写 .cpt 工具的先读这个。

## 安装

- 主模块：已在 v2.8 的无需重装
- 调参模块（可选）：Magisk → 从存储安装 ZIP → 重启 → 60 秒内观察 `init.svc.pvrtrackingservice` 与 tombstone 计数

## 校验

| 文件 | MD5 | SHA-256 |
|---|---|---|
| `pico4_algo_tuning_v0.1.1.zip` | `134fd4bb887d4082bb210e1a5fd3845d` | 见 release 资产 |

（主模块 ZIP 沿用 v2.8：`PICO4_MotionTracker_v2.8.zip`，MD5 `830604bd1e1ea59e8679b096500f6084`）

## 5 点模式说明（沿用 v2.8）

连接层支持（tracker_num=5 / upper.limit=5 / swiftversion=3）；stock 解算缺 tracker5 forearm/knee 模型，需 Ultra 算法（未随本仓库分发）；仅 3 台实机，未做满配验证。

---

仅供学习研究，请支持正版。
