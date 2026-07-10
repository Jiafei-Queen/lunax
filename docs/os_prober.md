# `lunax.os_prober` — 操作系统检测

运行时自动检测当前操作系统，返回操作系统名称字符串。模块加载时即执行检测，结果被缓存。

## 导入

```lua
local os_name = require("lunax.os_prober")
```

## 返回值

| 返回值 | 说明 |
|--------|------|
| `"NT"` | Windows 系统 |
| `"Linux"` | Linux 系统 |
| `"Darwin"` | macOS 系统 |
| 其他 | `uname -s` 返回的原始字符串 |

### 检测逻辑

1. 先尝试通过 `cd` 命令输出判断是否为 Windows（输出匹配 `[A-Z]:\` 路径格式）
2. 若不是 Windows，则执行 `uname -s` 获取系统名称

### 示例

```lua
local os = require("lunax.os_prober")

if os == "NT" then
    print("当前系统: Windows")
elseif os == "Linux" then
    print("当前系统: Linux")
elseif os == "Darwin" then
    print("当前系统: macOS")
else
    print("未知系统:", os)
end
```

### 配合其他模块使用

```lua
local os = require("lunax.os_prober")
local unix = os ~= "NT"

if unix then
    -- Unix 路径处理
else
    -- Windows 路径处理
end
```
