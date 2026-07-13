# `lunax.json` — JSON 编码与解码

JSON 序列化/反序列化工具。优先使用 [lua-cjson](https://github.com/mpx/lua-cjson)（需额外安装），回退到内置的 dkjson 2.5 实现。

## 导入

```lua
local json = require("lunax.json")
```

## 函数参考

### `.encode(value, [state])`

将 Lua 值编码为 JSON 字符串。支持 table、string、number、boolean、nil。`state` 可选配置：

| state 字段 | 类型 | 说明 |
|------------|------|------|
| `indent` | boolean | 启用缩进美化输出 |
| `level` | number | 初始缩进层级（默认 0） |
| `keyorder` | table | 指定键的输出顺序数组 |
| `buffer` | table | 可复用缓冲区，传入时直接追加到该表 |
| `bufferlen` | number | 当前缓冲区长度 |
| `tables` | table | 引用追踪表（循环检测） |
| `exception` | function | 自定义异常处理函数 `handler(reason, value, state, defaultmessage)` |

```lua
local str = json.encode({ name = "Lunax", version = 1.0 })
print(str)  -- {"name":"Lunax","version":1.0}

local pretty = json.encode({ a = 1, b = 2 }, { indent = true })
-- {
--   "a": 1,
--   "b": 2
-- }
```

支持元表控制序列化行为：
- `__tojson` — 自定义序列化函数 `function(value, state) return encoded_string end`
- `__jsonorder` — 指定键的输出顺序
- `__jsontype = 'object'` — 将空 table 强制编码为 `{}` 而非 `[]`

NaN / Inf 映射为 `"null"`。检测到循环引用时抛出错误。

### `.decode(str, [pos], [nullval], [objectmeta], [arraymeta])`

将 JSON 字符串解码为 Lua 值。

| 参数 | 类型 | 说明 |
|------|------|------|
| `str` | string | JSON 字符串 |
| `pos` | number | 起始解析位置（默认 1） |
| `nullval` | any | JSON `null` 的映射值（默认 `json.null`） |
| `objectmeta` | table | 解码后对象的元表（默认 `{ __jsontype = 'object' }`） |
| `arraymeta` | table | 解码后数组的元表（默认 `{ __jsontype = 'array' }`） |

返回解码后的值，失败时返回 `nil, pos, err_message`。

```lua
local t = json.decode('{"name":"Lunax","version":1.0}')
print(t.name)     -- Lunax
print(t.version)  -- 1.0
```

解码支持 C 风格注释（`//` 和 `/* */`）和 UTF-8 BOM。

### `.null`

JSON null 的表示值，可在编码/解码时识别。

```lua
local t = json.decode('{"a":null}', 1, json.null)
print(t.a == json.null)  -- true
```

### `.version`

字符串：`"dkjson 2.5"`

### `.use_lpeg()`

切换解码器使用 LPeg 加速（需安装 `lpeg` 库）。调用后 `json.using_lpeg = true`。  
LPeg 0.11 因已知 bug 不支持。

### `.quotestring(value)`

将字符串转义为 JSON 格式引号字符串（含 Unicode 转义）。

### `.addnewline(state)`

向 state.buffer 添加换行和缩进（用于自定义序列化）。

### `.encodeexception(reason, value, state, defaultmessage)`

默认的异常编码函数，将异常值编码为 `"<message>"` 格式的字符串。

## 完整示例

```lua
local json = require("lunax.json")

-- 编码
local data = {
    project = "Lunax",
    version = "0.1",
    modules = { "fs", "rl", "ansi", "logger", "util", "json" }
}
local str = json.encode(data, { indent = true })
print(str)

-- 解码
local decoded = json.decode(str)
print(decoded.project)  -- Lunax

-- 使用自定义 null 值
local with_null = json.decode('{"a":null,"b":1}', 1, json.null)
print(with_null.a == json.null)  -- true
```
