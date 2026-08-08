# Pico 4 Tracker Limit Unlock (LSPosed Module)

针对 **Pico 4 (A8110, 国行, Android 10 / API 29 / 固件 5.13.7)** 的 Swift 追踪器配对数量上限解除模块。

把系统对 **Swift 腿追配对数量** 的硬编码限制从 **2 个** 提升到 **2 / 3 / 5 应用内可切换**，通过 Zygisk Vector (LSPosed 兼容框架) 注入实现。

---

✅ **已在 Pico 4 5.13.7 CN 版本上实测通过，2/3/5 开关切换成功。**

⚠️ **注意：手上只有 3 个追踪器，无法实测配对第 4/5 个。**
配置值写入/读回 5 已验证通过（日志可确认），但实际连接 5 个追踪器的场景未验证。
若你遇到配对第 3 个以上时搜不到设备而非被提示拦截，请提 issue 反馈。

## 一、效果

| 项目 | 原厂 | 解锁后 |
|---|---|---|
| 追踪器配对数量 | 2 个 | **2 / 3 / 5 个，设置页下拉可切换** |

---

## 二、技术架构

```
Pico 4 (Android 10, API 29, 固件 5.13.7)
└─ Magisk 30.7 (已修补 boot.img 提权)
   └─ Zygisk Vector v2.2 (LSPosed 兼容框架 + 管理器)
      └─ 本模块 com.picoxr.trackerlimit  (mid=16)
           scope: com.pvr.swift
```

---

## 三、限制原理（根因分析）

`com.pvr.swift` 中追踪器上限受**多层控制**：

| 层 | 位置 | 原厂值 | 处理方式 |
|---|---|---|---|
| Java 常量 | `SwiftDataSource.MAX_TRACKER_SIZE = 2` | 2 | `setStaticIntField` → 动态取上限 |
| native 配置 | `SwiftImpl.getSwiftUpperLimit()` → native | 2 | afterHook 只做范围钳制，真实值透传 |
| 配置存储 | `Utils.setConfig("com.pvr.swift.upper.limit", ...)` | — | 走 PICO 私有的 `ConfigurationClientService` AIDL 服务 |
| 适配器 UI | `ConnectableTrackerAdapter` 内联 `>= 2` | 2 | 3 处 hook 绕过 |
| 设置页 UI | `SwiftSettingFragment.showLimitTogglePopup()` | 2 选项(2/3) | **整体替换为 3 选项(2/3/5)** |

### 关键发现：`setSwiftUpperLimit()` 没有 native 钳制

```java
setSwiftUpperLimit(int i) {
    return Utils.setConfig("com.pvr.swift.upper.limit", String.valueOf(i)) ? 0 : -1;
}
```

所以只要让 UI 能写进 5 就行，**不用强制改返回值**。默认 `SWIFT_UPPER_LIMIT_DEFAULT = 2`。

---

## 四、配置项（system property，实时可调）

| 属性 | 默认 | 范围 | 作用 |
|---|---|---|---|
| `persist.pico.tracker.limit` | 5 | 2–10 | 追踪器上限钳制 |
| `persist.pico.tracker.options` | `2,3,5` | — | 设置页下拉菜单有哪几项（逗号分隔） |

钳制范围是**保命**用的，防止填个离谱值进崩溃循环。

---

## 五、Hook 实现详解

### 5.1 `ShowLimitPopup` — 设置页下拉整体替换（核心）

用 `XC_MethodReplacement` 完全替换 `SwiftSettingFragment.showLimitTogglePopup()`。
菜单从 2 项变 **2/3/5**，使用 `getIdentifier()` 按资源名查 id（`swift2_setting_limit_count` plurals / `ic_swift_right` / `color_bfffffff`）。

**为什么必须整体替换？**
- 原版 lambda 监听器 `f0` 的 switch 只认两个分支（0 → 版本弹窗，default → 限制弹窗），塞第三项进不去。
- 改用 `java.lang.reflect.Proxy` 自己实现 `AdapterView$OnItemClickListener`。

**保留的原版保护逻辑：**
- `isFastClick()` 防连点
- 若选相同值，`togglePopup.dismiss()` 直接返回
- 若 `repo.getDevices().size() == 3` 弹"先解绑多余追踪器" Toast
- 选完后刷新 `binding.swiftSettingLimitText` 文案
- 调用 `devicesSizeChanged.k(size)` 通知

### 5.2 `SwiftUpperLimit` — 真实值透传+范围钳制

`getSwiftUpperLimit()` afterHook：不再强制返回 5，只做 `min(max(val, 2), 上限)` 钳制并缓存。

### 5.3 `BindLambda3Hook` — 绕过"已达上限"拦截

`ConnectableTrackerAdapter$ConnectableTrackerViewHolder.bind$lambda-3` 遇到 `>= 2` 就弹 Toast 拦截。
改成：还在上限内就调 `bind$lambda-0`（真正配对入口），只有真的满了才弹原版 Toast。

### 5.4 `DlgBindLambda2Hook` — 绕过对话框配对拦截

`ConnectDlgTrackerAdapter$ConnectableTrackerViewHolder.bind$lambda-2` 遇到 `>= 2` 就走拦截分支。
改成：在限制内就把 `args[0]` 改 0，强制走 `createBindTracker` 分支。

### 5.5 `CreateBindTrackerHook` — 绕过内联 `< 2` 检查

`createBindTracker()` 内部还有一道 `if (bondedDevices.size() < 2)` 内联检查（Xposed 改不了方法体内常量）。
before 里临时把 data source 的 bonded 列表字段换成空 `ArrayList`，让 `< 2` 判断通过，after 立刻换回来（用 ThreadLocal 保存）。

### 5.6 `DeviceSizeChangedHook` — 修复配满 3 个后按钮消失

`SwiftMainFragment.updateDeviceSizeChanged()` 中有一个硬编码的字面量 `3`，导致当配对设备数达到 3 个时，
即使上限已被提高，`startPair` 按钮也会被无条件隐藏。
afterHook 检查 `size >= 3 && size < limit && !isPairing` 时，手动把按钮设为可见并绑定点击事件。

---

## 六、目录结构

```
pico4-trackerlimit/
├── build_mod.bat                   # 构建脚本
│                                   #   build_mod.bat mod_tracker com\picoxr\trackerlimit trackerlimit
├── mod_tracker/                    # 模块源码
│   ├── AndroidManifest.xml
│   ├── apktool.yml
│   ├── assets/xposed_init          # 入口类声明
│   ├── res/values/arrays.xml       # xposedscope
│   └── src/com/picoxr/trackerlimit/
│       ├── TrackerLimit.java       # 入口（配置解析、hook 安装、上限决定）
│       └── hook/
│           ├── ShowLimitPopup.java      # 设置页下拉替换（核心）
│           ├── SwiftUpperLimit.java     # 真实值透传+钳制
│           ├── BindLambda3Hook.java     # 绕过"已达上限"拦截
│           ├── DlgBindLambda2Hook.java  # 绕过对话框配对拦截
│           ├── CreateBindTrackerHook.java  # 绕过内联 < 2 检查
│           └── DeviceSizeChangedHook.java  # 修复按钮消失
└── lsp_mod/                        # 数据库运维脚本
    ├── db_syncpath.py              #   同步 apk_path（重装后必跑）
    ├── db_restore.sh               #   推回数据库
    ├── db_scope.py                 #   改 scope
    ├── logs.sh / logs_full.sh      #   抓 Vector 日志
    └── check_tracker.sh
```

---

## 七、构建环境（无 Android SDK 纯命令行）

这台机器**没有安装 Android SDK / android.jar**，平台类要手写 stub（仅编译用，不打进 dex）。

- **JDK 26**：`C:\Program Files\Java\jdk-26.0.1`
- **javac 必须 `--release 8`**（Java 26 默认出 class v52，d8 拒绝）
- **r8.jar**（含 d8）：`java -cp r8.jar com.android.tools.r8.D8 --min-api 29 --output <dir> <classes>`
- **Xposed API 用自写 stub**（`stub/de/robv/android/xposed/*`），d8 只 dex 模块自己的 class
- **apktool** 打包 + **jarsigner** 自签（无 native lib 的模块 APK 不需要 zipalign）

### ⚠️ 混淆版 Vector 框架的真实 Xposed API 签名
Vector 对 Xposed API 做了混淆（类名如 `J.LWAmWX.cJwqEr.pds.yD.XposedHelpers`）。
- `findAndHookMethod` 真实签名：**返回 `XC_MethodHook.Unhook`，不是 void！**
- 必须用 `XposedHelpers.findAndHookMethod`，且 stub 要声明返回 `XC_MethodHook.Unhook`，否则运行时 `NoSuchMethodError`。

### ⚠️ 混淆类（s5.* / r5.* / n5.*）字段/枚举名不可信
jadx 打印的 `TYPE_TITLE_CHECK`、`f9351b` 等是它反混淆猜的名字，**真实 dex 里已被 R8 改掉**。
只有**非混淆类**（如 `com.pvr.swift.fragment.SwiftSettingFragment`）的字段名才是真的。
识别混淆枚举常量/字段用**资源 id 反查**或**按类型+默认值**匹配：
- `s5.b` 枚举：按 `osui_item_title_check` 布局资源 id 反查（资源名不会被 R8 改）
- `s5.a` 字段：title 是唯一 `CharSequence`；color 是 `int` 默认 0；iconRes 是 `int` 默认 **-1**

---

## 八、部署流程

1. **构建**：`cmd /c "build_mod.bat mod_tracker com\picoxr\trackerlimit trackerlimit 2>&1"`
2. **安装**：`adb install -r build\apk\trackerlimit.apk`
3. **同步 apk_path**（重装后必跑，否则 Vector 加载旧 dex）：`python lsp_mod\db_syncpath.py`
4. **推回数据库**：`adb push` 后跑 `lsp_mod\db_restore.sh`（自动 chown/chmod + 清 wal/shm）
5. **重启**：`adb reboot`

### ⚠️ 崩溃循环止血
`handleLoadPackage` 阶段**一行宿主类代码都不能执行**（会触发 `ClassLoader` 重入 → `ExceptionInInitializerError` → 无限崩溃重启）。
止血：先在数据库把模块 `enabled=0`，重启，再改代码重建。

---

## 九、已知残留风险

- **追踪器扫描阶段**：`SwiftDataSource.startScan()` / `startScanImmediately()` 方法体内还有硬编码
  `if (size < 2)`（Xposed 改不了方法体内常量）。
  **判断依据**：如果配第 3 个时是"搜不到设备"（而非被提示拦），就是这里，需补 startScan hook。
- **硬件验证**：用户手上只有 3 个追踪器，无法实测配对第 4/5 个。配置值写入/读回 5 已验证通过。

---

## 十、验证状态

- ✅ 设置页下拉显示 **2个 / 3个 / 5个** 三项，可选中并写回
- ✅ 日志证据：
  ```
  PicoTrackerLimit: upper limit 3 -> 5
  SwiftRepo:  swiftUpperLimit: 5
  SwiftUtils: getConfig, com.pvr.swift.upper.limit 5
  SwiftRepo:  setSwiftUpperLimit: 3 -> 0   (0 = success)
  ```
- ✅ 干净重启后模块注入一次、零崩溃、进程稳定

---

## 十一、日志与诊断

- Vector 日志：`/data/adb/lspd/log/{verbose_*,modules_*,kmsg}.log`
- 崩溃：`adb logcat -d -b crash`
- 追踪器配置：`adb logcat -d -s SwiftUtils:I | grep upper.limit`

---

## 十二、网络环境备注（下载依赖时）

- **GitHub release 资源被墙**：直连 + `ghfast.top` + `gh-proxy.com` + `mirror.ghproxy.com` 都返回 9 字节 "Not Found"
- ✅ **`ghproxy.net` 可用**（唯一能下 GitHub release 的镜像）
- F-Droid / IzzyOnDroid 不通，GitHub API 被限流

---

## 十三、致谢

- **more-picohaxx** (typlo) — bootloader 解锁工具
- **FallenAngel** — 解锁流程社区指导
- **Zygisk Vector** (JingMatrix) — LSPosed 兼容框架