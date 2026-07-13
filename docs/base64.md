# `lunax.base64` — Base64 编解码

Base64 编码/解码模块，提供文件和字符串两种操作方式。

- **文件操作**：Unix 调用系统 `base64` 命令，Windows 调用 `certutil` 命令
- **字符串操作**：纯 Lua 实现，兼容 Lua 5.4 和 LuaJIT

## 导入

```lua
local b64 = require("lunax.base64")
```

## 函数参考

### `b64.encode_file(input, output)`

Base64 编码文件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `input` | string | 输入文件路径 |
| `output` | string | 输出文件路径 |

返回 `true` 成功，或 `nil, err` 失败。

```lua
local ok, err = b64.encode_file("photo.png", "photo.b64")
if not ok then print("编码失败:", err) end
```

### `b64.decode_file(input, output)`

Base64 解码文件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `input` | string | Base64 编码文件路径 |
| `output` | string | 解码输出路径 |

返回 `true` 成功，或 `nil, err` 失败。

```lua
local ok, err = b64.decode_file("photo.b64", "photo_decoded.png")
if not ok then print("解码失败:", err) end
```

### `b64.encode_str(input)`

Base64 编码字符串（纯 Lua）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `input` | string | 原始字节串 |

返回 Base64 编码后的字符串。

```lua
local encoded = b64.encode_str("Hello, World!")
print(encoded)  -- SGVsbG8sIFdvcmxkIQ==
```

### `b64.decode_str(input)`

Base64 解码字符串（纯 Lua）。自动去除空白字符。

| 参数 | 类型 | 说明 |
|------|------|------|
| `input` | string | Base64 编码字符串 |

返回解码后的原始字节串。

```lua
local decoded = b64.decode_str("SGVsbG8sIFdvcmxkIQ==")
print(decoded)  -- Hello, World!
```

## 跨平台实现

| 平台 | 文件编解码 | 字符串编解码 |
|------|-----------|-------------|
| Unix/Linux/macOS | `base64` / `base64 -d` 命令 | 纯 Lua |
| Windows | `certutil -encode` / `certutil -decode` 命令 | 纯 Lua |

## 内部实现

- **位运算兼容层**：LuaJIT 使用 `bit`（或 `bit32`）模块，Lua 5.4 通过 `load()` 在运行时编译原生 `&` `|` `<<` `>>` 运算符，避免 LuaJIT 解析错误
- **字符串编解码**：标准 Base64 字母表 `A-Za-z0-9+/`，`=` 填充

## 依赖

- `lunax.popen` — 文件操作通过 popen 调用系统命令
- `lunax.os_prober` — 检测操作系统类型
- `lunax.util` — 类型错误格式化
