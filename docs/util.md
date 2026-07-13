# `lunax.util` — 通用工具函数

提供格式化打印、字符串处理、深度克隆、字节格式化、数组检测、类型错误格式化、表遍历等常用工具。

## 导入

```lua
local util = require("lunax.util")
```

## 函数参考

### `.dump(obj, [name])`

以格式化的方式打印 Lua 值（尤其是 table），支持嵌套最多 10 层。  
key 按字母序排序（数字在前），字符串值带引号。可选 `name` 参数做变量名前缀。

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

按分隔符分割字符串，返回数组。默认按空白字符 (`%s`) 分割。

```lua
local parts = util.split("a:b:c", ":")   -- { "a", "b", "c" }
local words = util.split("hello world")  -- { "hello", "world" }
local empty = util.split("", ",")        -- {}
```

### `.clone(obj)`

深度克隆一个 Lua 值。支持 table（保留 metatable）、string、number 等类型。  
遇到循环引用会导致栈溢出，使用时请确保无环。键也会被深度克隆。

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

### `.is_array(t)`

检测 table 是否为有效的纯数组（连续整数键从 1 开始）。比较 `ipairs` 计数和 `pairs` 总数；相等即为数组。

```lua
print(util.is_array({ 1, 2, 3 }))       -- true
print(util.is_array({ a = 1 }))         -- false
print(util.is_array({ 1, nil, 3 }))     -- false（空洞）
print(util.is_array("not a table"))     -- false
```

### `.fmt_type_err(idx, fn, exp, got)`

生成标准化的类型错误消息字符串。

```lua
error(util.fmt_type_err(1, 'open', 'string', 'nil'))
-- "bad argument #1 to 'open' (string expected, got nil)"
```

### `.spairs(t)`

排序键遍历迭代器。数字键按数值升序，字符串键按字母序。  
每次迭代返回 `index, key, value`。

```lua
for i, k, v in util.spairs({ b = 2, a = 1, 3 = "c" }) do
    print(i, k, v)
end
-- 1   3   "c"
-- 2   "a"  1
-- 3   "b"  2
```

### `.sipairs(t)`

安全数组遍历迭代器。与 `ipairs` 不同，`sipairs` 不会在遇到 `nil` 时中断，会遍历所有整数键直到最大索引。

```lua
local t = { 1, nil, 3 }
for i, v in util.sipairs(t) do
    print(i, v)  -- 1: 1, 2: nil, 3: 3
end
```

### `.pack(...)`

兼容 Lua 5.1/5.2+ 的参数打包函数。5.2+ 使用 `table.pack`，否则返回 `{ n = select('#', ...), ... }`。

### `.unpack`

兼容 Lua 5.1/5.2+ 的解包函数。5.2+ 为 `table.unpack`，否则为全局 `unpack`。

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

-- 安全遍历
local arr = { "a", nil, "c" }
for i, v in util.sipairs(arr) do
    print(i, v)
end
```
