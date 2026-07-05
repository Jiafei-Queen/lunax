# `lunax.json` — JSON 编码与解码

JSON 序列化/反序列化工具。优先使用 [lua-cjson](https://github.com/mpx/lua-cjson)（需额外安装），回退到内置的 dkjson 实现。

## 导入

```lua
local json = require("lunax.json")
```

## 函数参考

### `.encode(value, [state])`

将 Lua 值编码为 JSON 字符串。支持 table、string、number、boolean、nil。  
`state` 可选，可设置 `indent` 缩进、`keyorder` 键序等。

```lua
local str = json.encode({ name = "Lunax", version = 1.0 })
print(str)  -- {"name":"Lunax","version":1.0}

local pretty = json.encode({ a = 1, b = 2 }, { indent = true })
-- {
--   "a": 1,
--   "b": 2
-- }
```

### `.decode(str, [pos], [nullval])`

将 JSON 字符串解码为 Lua 值。`pos` 指定起始位置，`nullval` 指定 JSON null 映射的值。

```lua
local t = json.decode('{"name":"Lunax","version":1.0}')
print(t.name)     -- Lunax
print(t.version)  -- 1.0
```

### `.null`

JSON null 的表示值，可在编码/解码时识别。

```lua
local t = json.decode('{"a":null}', 1, json.null)
print(t.a == json.null)  -- true
```

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
```
