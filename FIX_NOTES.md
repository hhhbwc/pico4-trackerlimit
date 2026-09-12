# PICO 4 标准版 体感追踪器 修复记录

日期: 2026-09-11
设备: PA8110MGGB070328G (A8110 / Phoenix), ROM 5.13.7
原始版本: PvrSwift 2.0.4 (出厂)
目标: 让 P4 标准版能使用 PICO 体感追踪器 (含 5 点全身动捕)

---

## 一、根因

App 有双层门禁, 都基于 ROM 系统属性:

```
ro.pxr.externalfunc = 0        ← 总闸, 要求 ==1
ro.pui.build.version = 5.13.7  ← 版本闸, 要求 >= 5.5.0 (0x226)
```

判定代码 (com.pvr.swift.feature.Features.isSwiftVersion):
```
puiBuildVersion >= 550  ||  ro.pxr.externalfunc == 1  →  放行
```

P4 标准版两项都不满足 → swiftSupport() == false → MainV1Activity 跳 SystemUpdateFragment
("你的一体机目前不支持使用体感追踪器, 请升级系统版本")

P4 Ultra 是 5.14.x 以上, externalfunc=1, 所以能用。P4 标准版停在 5.13.7 升不上去。

## 二、附加障碍 (权限)

App 在 /system/priv-app/PvrSwift, 持有两个特权权限, protectionLevel 是 signature|privileged:

  com.picovr.permission.SWIFT_ACCESS        (定义于 com.pvr.btperipheral, uid=1000)
  os.permission.BIND_TEA_TRACKER_SERVICE    (定义于 os.teatracker, uid=1000)
  android.permission.READ_PRIVILEGED_PHONE_STATE
  com.picoxr.xrshell.permission

测试签名装在 /data/app 拿不到这些权限 → 即使绕过门禁也连不上追踪服务。

## 三、方案

利用已有的 Magisk 27 root, 把改装 APK 通过 Magisk 模块 overlay 到 /system/priv-app/PvrSwift/。
Magisk 用 bind mount 覆盖, 系统按 priv-app 身份加载 → privileged 分支满足 → 权限授予。

(注: signature 分支不满足, 但 Android 权限判定是「或」逻辑, privileged 满足即可)

已验证先例: com.wzy.picomultitouch 用同样手法拿到 SYSTEM 身份。

## 四、改动点 (3 处, 基于 2.0.4)

1. smali/com/pvr/swift/feature/Features.smali :: swiftSupport()
   → 直接 return 0x1 (保留 FEAT_SWIFT 日志)

2. smali/com/pvr/swift/sdk/SwiftImpl.smali :: <init>()
   → feature/featureV2 初始化为 0x1
   → try 块开头 goto :cond_4, 跳过 ProductConfig 反射 + externalfunc + pui.build.version 判定

3. smali/com/pvr/swift/MainActivity.smali :: onCreate()
   → isVersionSupported(1) 结果强制 const/4 v1, 0x1

## 五、验证结果

[OK] overlay 生效:
  /dev/block/sda16 on /system/priv-app/PvrSwift/PvrSwift.apk type f2fs
  文件大小 113448663 (与改装包一致)

[OK] 特权权限全部授予:
  com.picovr.permission.SWIFT_ACCESS: granted=true
  os.permission.BIND_TEA_TRACKER_SERVICE: granted=true
  android.permission.READ_PRIVILEGED_PHONE_STATE: granted=true
  com.picoxr.xrshell.permission: granted=true
  privateFlags 含 PRIVILEGED, flags 含 SYSTEM

[OK] 门禁绕过:
  SwiftImpl: feature: true featureV2: true
  (原版会是 feature: false featureV2: false)

[OK] 进入主界面 (非 SystemUpdateFragment):
  mResumedActivity: com.pvr.swift/.SwiftActivity
  界面控件: swift_main_discover_start_pair_btn, swift_main_device_calibrate,
            swift_item_battery_mark, swift_item_status, swift_game_list,
            connect_setting_button, device_help_btn

[OK] 追踪器被系统枚举:
  PvrTrackingService-MCUTracker: tracker1, sn PC2310MLJC120430G bond_status 1

## 六、文件

改装 APK:   C:\tmp\swift204\swift204_signed.apk
模块 zip:   C:\tmp\swift204\pico4_swift_force_enable.zip
原 APK 备份: C:\Users\wzy\Downloads\apk_backup\Pico_Motion_Tracker_com.pvr.swift.ORIGINAL.apk
           C:\tmp\swift204\PvrSwift_2.0.4.apk (设备上原 2.0.4)
           /data/adb/modules_backup/picoswift_orig_PvrSwift.apk (设备上自动备份)
模块目录:   /data/adb/modules/pico4_swift_force_enable/

## 七、回滚

方法 A (卸载模块, 重启):
  adb shell su -c 'rm -rf /data/adb/modules/pico4_swift_force_enable && reboot'

方法 B (恢复原 APK 到 /data, 但 system 只读无法直接写回):
  原 APK 备份在 /data/adb/modules_backup/picoswift_orig_PvrSwift.apk
  卸载模块后 Magisk 不再 overlay, 系统自动用原 system 分区里的 APK

## 八、注意

- 系统 OTA 升级后 Magisk 模块可能失效, 需重新安装
- 2.0.5 的 externalfunc 阈值是 0x23a (570), 2.0.4 是 0x226 (550)
  本次基于 2.0.4 改装, 阈值更宽松
- 5 点动捕取决于 ro.pxr.support.swiftversion=3 和 persist.pxr.tracking.swiftVersion=2
  本机底层已支持, 改装后应可用 (待实机操作验证)

---

## 六、2.0.5 升级后的第三个障碍: getSwiftTrackerInfoVector 缺失 (已修复)

### 根因 (二进制层)

2.0.5 的 `libswift.so` 在 `PvrSwift` 构造函数里 `dlopen("libtrackingclient.pxr.so")`,
然后用 `dlsym` 按名称逐个拉接口, 填入一张虚函数表 (vtable, 步长 8 字节)。

vtable 构建顺序 (smali 无关, 纯二进制):
```
str x0,[x19,#0x270] <- dlsym("getSwiftTrackerInfo")        ✅ P4 有
str x0,[x19,#0x278] <- dlsym("getSwiftTrackerInfo")        ✅ P4 有 (单数)
str x0,[x19,#0x280] <- dlsym("getSwiftTrackerInfoVector")  ❌ P4 没有
```

2.0.5 新增的 `getTrackerDevices()` (支持多点) 读取 **slot 0x278**, 但传的是 `vector`
出参并按 `0x48` 步进遍历 —— 也就是它本来该读 **slot 0x280** (Vector 版)。
而 slot 0x280 在 P4 上 `dlsym` 返回 NULL → `getTrackerDevices()` 返回 null → 设备列表为空。

P4 系统库 `/system/lib64/libtrackingclient.pxr.so` 实际导出:
```
getSwiftTrackerInfo            @0x4fa34   (单数, 一次 1 个)
getSwiftTrackerConnectState    @0x4fa44   (返回 std::vector<TrackerInfo>&)  ← 等价替身
getSwiftTrackerInfoVector      ❌ 不存在
```
`getSwiftTrackerConnectState` 的签名与 `getSwiftTrackerInfoVector` 一致
(`int (handle, std::vector<TrackerInfo>*)`), 且内部填充同一个 0x48 字节的 `TrackerInfo`。

### 修复: 3 处 libswift.so 二进制补丁

```
A. rodata 0x2cf6c (30 字节全 0 的未引用空隙)
   写入 "getSwiftTrackerConnectState\0" (28 字节)

B. vtable 构建器 0xf074/0xf078 (原指向 getSwiftTrackerInfoVector @0x2bf94)
   adrp x1,#0x2b000 -> #0x2c000    word 900000e1 -> b00000e1
   add  x1,x1,#0xf94 -> #0xf6c     word 913e5021 -> 913db021
   => slot 0x280 现在 dlsym("getSwiftTrackerConnectState")

C. getTrackerDevices 0x10bdc / 0x10bf8 (两处, 正常路径 + 重试路径)
   ldr x8,[x0,#0x278] -> ldr x8,[x0,#0x280]
   word f9413c08 -> f9414008
   => 改为读取 Vector 版槽位
```

### 踩坑记录

1. **字符串槽位选择**: 最初把新串写进 `0x2c793`("swiftVersionChangedCallback"),
   导致 `NoSuchMethodError: no static method JniCallbacks.getSwiftTrackerConnectState(I)V`
   崩溃。教训: 那个区段是 JNI 回调方法名表, 被 `GetMethodID` 引用。
   必须用**全量引用扫描** (所有寄存器的 adrp+add) 确认无引用;
   早期只扫 `adrp x1` 的判定是错的, 把一堆实际在用的小日志串误判成"未引用"。

2. **ADRP 编码**: keystone 汇编 `adrp x1,#0x2c000` 输出 `0x90000161` 是错的。
   正确做法是取库内**已知正确**的同寄存器 ADRP 指令做参照:
   `0xf074`(page 0x2b000) word=0x900000e1, `0xf12c`(page 0x2c000) word=0xb00000e1,
   只差 **bit 29**。capstone 对 ADRP 的相对地址渲染在库内会混淆 0x2b/0x2c, 不可靠。

3. **capstone 无 detail 模式**: 本机的 capstone 5.0.7 不支持 `.detail`, 无法读 op.imm。

### 修复后状态

- 不再有 `dlError: getSwiftTrackerInfoVector undefined symbol`
- App 不再 SIGABRT, `SwiftActivity` 正常启动, `dlError` 不再出现
- `SwiftImpl: devices: []` 仍为空
- 系统日志显示 3 个追踪器存在绑定记录
  (PC2310MLJC120430G / PC2310MLJB250516G / PC2310MLJB250506G)
- 但这些追踪器当前 `online 0`, `TrackerConnectCount: 0`

### 更正: 空设备列表不是正常 2.0.5 流程

实测确认: 只有在设备列表中有追踪器时, 才能进行校准。
因此 `SwiftImpl: devices: []` 不是“等待穿戴校准”的正常状态,
而是设备枚举/配对链路仍未完成的故障状态。

当前已确认补丁解决了 `getSwiftTrackerInfoVector` 符号缺失导致的崩溃/空指针风险,
也确认真实点击“扫描设备/配对设备”后 pairing 调用已触发且返回 0。

当前新的主要阻塞点不是 pairing 调用失败, 而是 Stationservice 拒绝 pairing:

```
please disconnect 2 before pairing
please disconnect 3 before pairing
```

同时应用查询列表仍为空:

```
SwiftImpl: devices: []
```

后续需要继续确认:

1. 为什么 Stationservice 认为已绑定追踪器仍需先断开;
2. `getSwiftTrackerConnectState` 是否只返回已连接且 body tracking 有效的追踪器;
3. 是否需要把 `bindStatus=1 / online=0` 的已绑定设备合入 `getTrackerDevices()`;
4. `stationServiceReady=0` / `mSwiftBodyTrackingStateChange=0` 是否导致接口过滤为空;
5. `SwiftRepo: setSwiftDiscoverySwitch: 1 ignore` 是否阻止 discovery 开关为 1。

### 注意

- `libtracking.so` 已恢复为 2.0.5 原版 (md5 56aa44c9db237d5093df4517a029fc93)。
  之前误换成 2.0.4 版是走错了路, 真正的问题在 `libswift.so`。
- 模块版本 v1.2, APK md5 `cc8a9530742959e83ce2ba7c63a963ef`,
  libswift.so md5 `f0469811d0782a426c2c8e98d2b66326`。

### 更正: 第一节的版本号换算

`isSwiftVersion()` 里 `"5.13.7".replace(".","")` = `"5137"` → 整数 **5137**,
不是 513.7。阈值 0x226 = 550。5137 >= 550 恒成立。
所以版本闸**从来不是障碍**, 真正的门槛只有 `ro.pxr.externalfunc == 0` 这一项,
且代码是 **AND** 逻辑 (两条 if 串联), 不是 OR。

### 更正: 不能把空设备列表解释为正常等待校准

- 实测结论: 只有列表里有设备时才能校准。
- `SwiftImpl: devices: []` 是当前故障, 不是 2.0.5 正常流程。
- 系统里有 `mBindTrackerCount 3`, 但三个追踪器 `online 0`,
  `TrackerConnectCount: 0`, 说明“系统存在绑定记录”不等于“应用可枚举设备”。

### v16-v19: unBond 修复与 getTrackerDevices 崩溃链 (2026-09-11 深夜)

#### unBond 修复 (SwiftRepo.startPair, smali)

v15 起在 `SwiftRepo.startPair()` 里加入 pairing 前置动作:
`unBond(1)`/`unBond(2)`(v19 扩展到 `unBond(3)`), 再 `setSwiftDiscoverySwitch(1)`,
再 `startPair(0)`。

- 效果: unBond 全部返回 0, 系统 `mBindTrackerCount` 从 3 降到 2,
  tracker1 SN 变为占位符 `PC00000000000000W`, tracker2 变空白,
  Stationservice 的 `please disconnect 2/3 before pairing` 阻碍被清除。
- 注意: 每次点击“扫描设备”都会解绑 1/2/3 槽位, 之后需要重新配对所有追踪器。

#### libswift.so getTrackerDevices 崩溃链 (关键教训)

v15 实测: unBond 成功后, 系统 tracker 状态变化导致
`getSwiftTrackerConnectState(TrackingClient, vector&)` 返回损坏数据:

1. v15 崩溃: `JNI DETECTED ERROR: negative array length: -954437177`
   `in call to NewObjectArray from JniWrapper.getTrackerDevices()`
   (tombstone: `Java_com_pvr_swift_sdk_JniWrapper_getTrackerDevices+276`)
2. v16 (数量钳制 0-5, 代码洞 0x34310): 仍崩, `Log.i` 里 `GetStringUTFChars` SEGV,
   因为垃圾 count(1-5) 仍会把垃圾 vector 条目转成含垃圾字符串的 SwiftDevice。
3. v17 (count 强制 0): 仍崩, 证明崩溃与返回数据无关,
   是 unBond 后系统状态下 native 调用过程本身破坏内存。
4. v18/v19 (最终方案): 0x10bdc `ldr x8,[x0,#0x280]` 改为 `mov x8,xzr`,
   跳过该 native 调用, getTrackerDevices 恒返回 null (Java 侧安全处理)。
   同时移除 getDevices/getDevicesVector 里的 [MOD] setBodyTrackingMode。
   部署后应用与服务稳定, 无崩溃。

结论: P4 上 slot 0x280 绑定 getSwiftTrackerConnectState 只能应急,
tracker 状态变化后不可靠。设备枚举改由 statusChangedCallback 回调路径提供
(系统在服务连接和状态变化时主动推送完整 SwiftDevice)。

#### 代码洞 (libswift.so)

- 可执行段 0xecf0-0x2bdec 无 nop/零填充; RX LOAD 覆盖 0x0-0x3438c (含字符串区)。
- 最终使用段尾 0x34310 (60B 零区, 位于 PT_NOTE 范围内, 运行时无害)。
- v19 中该洞已成死代码 (0x10bdc 直接返回 null), 保留不影响。

#### ARM64 补丁记录

- `mov x8,xzr` = 0xaa1f03e8
- `b` 编码: 0x14000000 | ((to-from)>>2 & 0x3FFFFFF), 注意 from 必须是 b 指令自身地址
  (v17 曾因用洞首地址算偏移导致目标偏 4 字节)。

### 当前产物 (v20)

- APK: C:\tmp\swift_mod\swift205_patched_v20.apk, md5 a359f61d01a9867900a43f5ef5a01f4d
- 模块: C:\tmp\swift_mod\pico4_swift_force_enable_205.zip (version=1.3)
- libswift.so md5: cbc6fe1ee6a0cdb02e4ce1e53f0fc5a9 (同 v18/v19)

### v20: 移除 pre-pair unBond, 强制开启 discovery

每次配对都解绑其他追踪器, 这不可接受。

重新分析 v15 点击日志后确认: `StartTrackerPairing re=0` 说明配对模式进入成功,
真正的阻塞是 `setSwiftDiscoverySwitch: 1 ignore` —— SwiftRepo.setSwiftDiscoverySwitch(IZ)
在 enable=1 时要求 swiftVersion==2 且 powerMode==1 且 !batteryLow 且 size<limit
且 (force || isAppVisible), 不满足就 ignore, 导致 discovery 扫描从未开启,
配对模式的追踪器自然无法被发现。

改动:

1. `SwiftRepo.startPair()` 恢复原样 (无任何 unBond/强制开关)。
2. `SwiftRepo.setSwiftDiscoverySwitch(IZ)`: 将 5 处跳向 :cond_3(ignore) 的条件跳转
   (`if-ne v3,v7` / `if-ne v4,v1` / `if-nez v6` / `if-ge v1,v3` / `if-nez p2`)
   全部替换为 nop, enable=1 恒定落到 :cond_2 直接调用 adapter。
   实测日志: `setDevDiscoverySwitch enable 1 tracker_num 5`, `re=0`,
   `setSwiftDiscoverySwitch: 1 -> 0` (不再 ignore)。

副作用: discovery 开关在应用任何 enable=1 请求时都会强制打开, 包括
isAppVisible=false 的后台场景。禁用路径 (enable=0) 未改动。

### v20 实测: 配对成功 + 新问题 (2026-09-12 00:12)

实测配对 PC2310MLJB250506G 成功进入槽位 1, 但连接 3-4 秒后断链:

```
tracker1 connected -> lose_connect_tracker_station
"reason": "tracker_power_off", "actual_battery": 92
disconnect reason 5, 两次循环
```

- HMD 侧一切正常: bodyTrackingMode=1 已设置, workmode 3 (频率已升),
  `mTrackerEnterPowerOffWaitTime reset to -1` (关机定时器已禁用)。
- 应用未调用 setTrackerPowerOff (仅校准界面调用)。
- 追踪器连接时上报 `reset_flag 1 reset_reason 16` (固件复位)。
- 该追踪器 (250506G) 被解绑时处于在线状态 (v19 unBond(3)),
  固件可能处于半解绑坏状态, 属设备侧问题。
- 处置建议: 充电座充电 / 追踪器恢复出厂 (长按) 后重配;
  或先配对另外两台离线解绑的追踪器 (JC120430G / JB250516G) 对照。

### v21: 设备列表改由状态回调缓存驱动

getTrackerDevices (native) 已永久禁用, 主界面设备列表无法枚举。
系统在服务连接/状态变化时会通过 statusChangedCallback 主动推送完整
SwiftDevice (含 bindState/connectState/sn/电量), 据此实现缓存:

1. SwiftRepo 新增字段 `mModDevices:Ljava/util/Hashtable;`, <init> 初始化。
2. `onStatusChanged(SwiftDevice,I)` 顶部插入缓存维护:
   bindState==1 → put(id, device); 否则 remove(id)。
3. `SwiftRepo.getDevices()` 改为返回缓存快照 (ArrayList(values)),
   map 未初始化时返回 null。不再调用 adapter.getDevicesVector()。

效果: 已配对/已连接的追踪器会出现在应用列表中, 校准流程可达。
SwiftImpl.getDevicesVector 的 "devices: null" 日志为预期行为 (native 路径不再使用)。

当前产物: swift205_patched_v21.apk, md5 2c9016924b880482c2fd6539df38fa6a

### v22: 3 点模式 override

根因: PICO 配置服务 (PxrConfigService) 拒绝应用写入系统键,
`sys_tracking_tracker_wear_mode` 卡在 "3"(5tk_thigh),
`com.pvr.swift.upper.limit` 卡在 5, UI 里选择 3 点无法落盘
(会话日志中 setSwiftUpperLimit 从未被调用, 疑被弹窗/选项过滤拦截)。

穿戴模式原始值映射 (SwiftV2Event$Companion.getWearMode):
```
"0"=2tk_basic  "1"=2tk_gesture  "2"=3tk_waist(3点)  "3"=5tk_thigh(5点)
"4"=5tk_forearm "5"=5tk_bigarm  "6"=5tk_upperlimb
```

修复 (应用内 override, 不依赖配置服务):

1. SwiftImpl 新增静态 `sUpperLimitOverride:I = 0x3` (默认 3 点);
   `getSwiftUpperLimit()` 优先返回 override (负值回退读配置);
   `setSwiftUpperLimit(I)` 先写 override 再尝试写配置。
2. Utils 新增静态 `sWearModeOverride:Ljava/lang/String; = "2"` (默认 3tk_waist);
   `getWearMode()` 优先返回 override; `setWearMode(String)` 先记 override。

验证: 启动日志 `swiftUpperLimit: 3`。
之后在应用内切换 3 点/5 点 (穿戴模式页/设置数量上限) 均会即时生效。

当前产物: swift205_patched_v22.apk, md5 0e0e36c87f5b97f1601e2cecd038e26a

### v23: 穿戴模式切换联动配对上限

背景: PICO 4 标准版官方只支持 3 点, 5 点为 Ultra 能力; 现移植 Ultra 的
2.0.5 应用, 目标是让 2/3/5 点切换按钮真正可用。
系统层证据: MCU 配置 tracker_num 5 (5 个配对槽位), Stationservice 按 5 槽位
工作, 5 点限制大概率是产品档位软件门 (已绕过), 但手上只有 3 台追踪器,
5 点物理上配不满, 待有 5 台后再验证。

发现的 UI 缺陷: WearModeFragment 确认回调 (onViewCreated$lambda-2) 只在
from=cover 的首次引导分支设置 setSwiftUpperLimit (0→2, 其他→5),
从设置页进入的常规切换分支只调 setWearMode 不设上限 —— 切到 3 点后
上限仍是 5, 主页继续要求 5 个。

修复: Utils 新增 setWearModeWithLimit(String):
```
wearMode "2"(3tk_waist) -> limit 3
wearMode "0"/"1"(2tk)    -> limit 2
其他("3"~"6", 5tk)       -> limit 5
```
写入 sWearModeOverride + SwiftImpl.sUpperLimitOverride + 尝试写系统配置 +
SwiftStateManager。WearModeFragment 确认按钮改为调用该方法。

设置页的"数量上限"选择器 (3/5) 与增强模式开关走的 setSwiftUpperLimit /
setWearMode 已被 v22 override 覆盖, 均即时生效。
注意: 设置页降上限时若已绑定数 > 目标值会弹"先解绑"确认框 (工厂逻辑, 保留)。

构建教训: Python 三引号字符串首部误带引号, smali 报
"Unterminated character literal" — 插入文本务必检查首字符。

当前产物: swift205_patched_v23.apk, md5 fff13444db4f79603a7e613177be23ea

### Release v2.0 (发布)

- 仓库: https://github.com/hhhbwc/pico4-trackerlimit (LSPosed 旧方案已移除)
- 模块包: PICO4_MotionTracker_2.0.5_v2.0.zip
  - md5 3f8c378bc7e705e28fb1551a4789dd44
  - sha256 42be4bb94919cfa5ea8db4549c14bd8966df363e82020331222993c1c9f81fe5
  - module.prop version=v2.0 (versionCode 4), 内含 README
- 附件: 模块 zip + swift205_patched_v23.apk (118MB 超 git 单文件限制, 只放 Release)
- 文档: README 三语 (中/EN/RU) + RELEASE_NOTES + 本记录

### v2.1: Ultra BODYPOSE 算法移植成功 (2026-09-12)

Ubuntu_User 从 Ultra 固件 (5.15.7 sparrow) 提取了完整算法栈, 关键修正:
getSwiftTrackerInfoVector 在 /system_ext/lib64/libtrackingclient.pxr.so
(客户端库), 服务端算法在 pvrtrackingservice + libAlgSwiftBodyPose.so,
模型为 /system/etc/AlgSwift/s2/cpu/ 下的外部 .bytenn 文件 (CPU 后端, 按
点数分装: tracker2/3/5_forearm/tracker5_knee + 足底 LSTM)。

符号级 diff 结论:
- 两版 libAlgSwiftBodyPose.so 导出集完全一致 (各 5642, 差集为零) → ABI 兼容
- DT_NEEDED 完全一致 (libbytenn/libSNPE 等, 标准 ROM 全有)
- 共享 .cpt 配置字节级相同 (swift_tracker_online.json.cpt md5 一致)

真机验证 (bind mount + 重启追踪服务, 不重启设备):
- 旧算法 BODYPOSE 1.0.0.47 → **1.0.0.54** (Ultra 新算法在标准版运行)
- 中途重启服务的坑: 新服务实例错过座子 wakeUp 状态推送,
  stationServiceReady 卡 0 / 绑定显示为空; 唤醒头显后自动重握手恢复,
  三台绑定记录全部自动恢复 (绑定存在座子侧, 不会丢)
- 用户实测: "The port was successful, and it feels even more accurate than before"

v2.1 模块内容: libAlgSwiftBodyPose.so (Ultra) + /system/etc/AlgSwift 模型
以 Magisk overlay 方式打包, 开机自动生效, 无需 bind mount。

同时修复: WearModeFragment 首次引导 (from=cover) 分支会用
`setSwiftUpperLimit(0/2/5)` 覆盖掉 setWearModeWithLimit 刚设置的上限
(选 3 点被改回 5), 已移除该分支的三处调用。

用户报告汇总 (群): VirtualDJ 5.13.8 (abl 重刷修复 root 后模块生效),
卡 1.0 模式问题 = 应用默认 2.0 模式等待 DK (Developer Kit, 2.0 追踪器
产品名) 追踪器, 一代用户需在设置里切 1.0; PICO 商店弹
"illegal signature" 购买框 = 测试签名的预期现象。

当前产物: swift205_patched_v24.apk, md5 703757d2b2078b46a47f34b911a523db
模块: PICO4_MotionTracker_2.0.5_v2.1.zip, md5 0fa4732fcd8ff6cd3d362e6f210b716b
  (sha256 b3f16ac82e13dbf2a2d2af486bcd2cc3be93001131008102ccbdea5418a0b3d1)

新增: 仅首次安装自动解绑一次 (用户需求)
- customize.sh 检测 /data/adb/modules/<id>/system/priv-app/PvrSwift/PvrSwift.apk:
  存在 = 从旧版模块升级, 保留绑定; 不存在 = 原厂首装, 写
  /data/adb/pico4_tracker/unbond_pending 标记
- service.sh 开机检测标记, 等追踪服务起来 (+15s, 此时追踪器通常离线,
  规避在线解绑的固件掉电坑), tracker_test unbond tracker1/2/3, 清标记
- 解绑动作用官方测试程序 /system/bin/tracker_test (strings 确认支持
  "unbond [tracker1/tracker2/tracker3]"), root 下调用
- 升级用户 (v2.0 -> v2.1) 绑定不受影响

### v2.2 (暂存, 未发布)

- Swift 版本/上限 override 持久化: SwiftStateManager 新增
  getModWearMode/setModWearMode (key_mod_wear_mode) 与
  getModUpperLimit/setModUpperLimit (key_mod_upper_limit), 默认 -1;
  Utils.getWearMode / SwiftImpl.getSwiftUpperLimit 优先级改为
  内存 override -> 持久 prefs -> 内置默认 (wear="2"/3点, limit=3),
  不再读卡死的系统配置。用户切换后跨应用重启生效。
- keystore 轮换: 新专用 release keystore 签名 (pico4tracker),
  旧 test.keystore 密码已从文档移除 (git 历史仍在, 作废该密钥即可)
- 状态: 本地暂存, 未发布 release (攒批次)
- 产物: swift205_patched_v25.apk md5 d2eee0594f5ce6ef5c5e348eef802a8c,
  PICO4_MotionTracker_2.0.5_v2.2.zip md5 f62398a7100462b099b1e9b48d5bf329
