# .cpt 二进制格式规范（BODYPOSE / 追踪器运行时配置）

> 适用文件：`/system/etc/pxr/sensor/config/*.cpt`
> 本文来自一次真实的崩循环事故（2026-10-07），写给所有需要生成/修改 .cpt 的工具作者。
> **服务端失败模式是崩循环，不是报错、也不是降级 stock。** 格式错一点 = pvrtrackingservice 反复 abort。

## 二进制格式（逐层）

```
文件 = Base64(76列/行, LF-only) ( AES-128-ECB ( PKCS7( plaintext ) ) )
plaintext = JSON(UTF-8) + "\n" + "\x00"
```

| 层 | 规范 | 违反后果 |
|---|---|---|
| 明文尾部 | **必须**以 `}\n\x00` 结束（NUL 是内容字节，不是垃圾） | 服务端解码器**悄悄截短明文** → `nlohmann::json parse_error.101` → abort → init 反复拉起 |
| PKCS7 | 标准 16 字节块填充 | 解密失败 |
| AES | 128-bit **ECB**；key 内嵌于 `libAlgSwiftBodyPose.so`（`strings` 可见） | 解密失败 |
| Base64 | **76 字符/行，LF-only**（无 `\r`，文件尾一个 `\n`） | CR 被服务端解码器扰动 → 同样产生截短明文 → 崩循环 |

## 解密（读）

```python
import base64, json
from Crypto.Cipher import AES
KEY = b'ZkIzO3ytSX5Bbe5Z'
raw = open(path,'rb').read()
dec = AES.new(KEY, AES.MODE_ECB).decrypt(base64.b64decode(raw))
pad = dec[-1]
if 1 <= pad <= 16 and dec[-pad:] == bytes([pad])*pad: dec = dec[:-pad]
obj = json.loads(dec.rstrip(b'\x00').decode('utf-8'))   # 剥 NUL 仅用于解析
```

## 加密（写）——两处致命点都已标 ★

```python
data = (json.dumps(obj, indent=4) + '\n\x00').encode()   # ★ 必须补尾部 NUL
pad = 16 - len(data) % 16
enc = AES.new(KEY, AES.MODE_ECB).encrypt(data + bytes([pad])*pad)
b64 = base64.b64encode(enc).decode()
open(path,'wb').write(('\n'.join(b64[i:i+76] for i in range(0,len(b64),76)) + '\n').encode())
#                                                        ★ 二进制写：Windows 'w' 文本模式会注入 CRLF
```

## 出厂自检（交付前三条必须全过）

```bash
# A. CR 计数 = 0
tr -dc '\r' < your.cpt | wc -c

# B. roundtrip 尾部 = } \n \0
tr -d '\r\n ' < your.cpt | base64 -d | openssl enc -d -aes-128-ecb -K <key_hex> | tail -c 3 | od -c

# C. JSON 合法（剥 NUL 后过解析器）
... | tr -d '\0' | python -m json.tool
```

## 上机验收（写入/挂载后）

1. 重启后 60 秒内：`getprop init.svc.pvrtrackingservice` 保持 `running` 且 PID 不变
2. `ls /data/tombstones/tombstone_* | wc -l` 无增长
3. `grep -c "pxr/sensor/config" /proc/mounts` = 预期挂载数

## 事故记录（2026-10-07）

v0.1-aggressive 首版 .cpt 存在 CRLF base64 + 缺尾部 NUL 两处缺陷（JSON 本身合法）。
重启生效时 `pvrtrackingservice` 崩循环，`tombstone_05~09` 连续 5 个，调用栈：

```
nlohmann::json::parse (parse_error.101, "unexpected end of input; expected '}'")
  ← alg_controller_init_aicontainer ← pvr::swift::MCUTracker::mainLoop
```

修复（补 NUL + LF-only）后同一份 JSON、同一把 key、同参数稳定运行 → 证明 JSON 内容无罪，
格式即生死。完整时间线与证据链见 `HANDOVER-2026-10-07-algo-tuning-cpt-format.md`。
