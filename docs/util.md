# `lunax.util` — 通用工具函数

提供格式化打印、字符串处理、深度克隆、字节格式化等常用工具。

## 导入

```lua
local util = require("lunax.util")
```

## 函数参考

### `.dump(obj, [name])`

以格式化的方式打印 Lua 值（尤其是 table），支持嵌套最多 10 层。  
key 按字母序排序，字符串值带引号。可选 `name` 参数做变量名前缀。

```lua
local t = { z = 1, a = "hello", inner = { x = 10, y = 20 } }
util.dump(t, "config")
```

输出：

```
config = {
  ["a"] = "hello",
  ["inner"] = {
    ["x"] = 10,
    ["y"] = 20,
  },
  ["z"] = 1,
}
```

### `.trim(str)`

去除字符串首尾空白字符。`nil` 返回空字符串。

```lua
print(util.trim("  hello world  "))     -- "hello world"
print(util.trim("\n\tfoo\n"))            -- "foo"
print(util.trim(nil))                    -- ""
```

### `.split(str, sep)`

按分隔符分割字符串，返回数组。默认按空白字符分割。

```lua
local parts = util.split("a:b:c", ":")   -- { "a", "b", "c" }
local words = util.split("hello world")  -- { "hello", "world" }
local empty = util.split("", ",")        -- {}
```

### `.clone(obj)`

深度克隆一个 Lua 值。支持 table（保留 metatable）、string、number 等类型。  
遇到循环引用会导致栈溢出，使用时请确保无环。

```lua
local original = { a = 1, b = { c = 2 } }
local cloned = util.clone(original)
cloned.b.c = 99
print(original.b.c)  -- 2（互不影响）

-- 保留元表
local mt_obj = setmetatable({ x = 1 }, { __tostring = function() return "mt" end })
local cloned_mt = util.clone(mt_obj)
print(getmetatable(cloned_mt))  -- table（元表被复制）
```

### `.hsz(bytes)`

将字节数转换为人类可读的字符串（自动选择 B/KB/MB/GB/TB 单位）。  
字节数 < 1024 时显示整数，≥ 1024 时保留两位小数。  
支持传入带 `B` 后缀的字符串。

```lua
print(util.hsz(1024))         -- "1.00KB"
print(util.hsz(2048))         -- "2.00KB"
print(util.hsz(1234567))      -- "1.18MB"
print(util.hsz(500))          -- "500B"
print(util.hsz("2048B"))      -- "2.00KB"
```

## 完整示例

```lua
local util = require("lunax.util")

-- 解析配置文件路径
local env_paths = util.split(os.getenv("PATH"), ":")
print("PATH 包含 " .. #env_paths .. " 个目录")

-- 深拷贝配置并修改
local defaults = { host = "localhost", port = 3000 }
local config = util.clone(defaults)
config.port = 8080

-- 格式化文件大小
local stat = { size = 12345678 }
print("文件大小:", util.hsz(stat.size))

-- 调试输出
util.dump(config, "config")
```
