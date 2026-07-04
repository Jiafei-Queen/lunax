# `lunax.fs` — 文件系统操作

基于 Shell 命令封装的文件系统工具模块，提供路径拼接、文件检测、读写删移等常用操作。  
内部自动处理路径转义，兼容 GNU/Linux 与 BSD/macOS。

## 导入

```lua
local fs = require("lunax.fs")
```

## 函数参考

### `.cwd()`

获取当前工作目录（等价于 `pwd`）。

```lua
print(fs.cwd())  -- 例如: /Users/me/project
```

### `.ls([path])`

列出目录下所有条目，等价于 `ls -A`（不包含 `.` 和 `..`，但包含隐藏文件）。  
默认列出当前目录。

```lua
local files = fs.ls()         -- 列出当前目录
for _, f in ipairs(files) do
    print(f)
end

local all = fs.ls("/tmp")     -- 列出 /tmp
```

### `.test(path)`

检测路径类型。

| 返回值 | 含义 |
|--------|------|
| `"FILE"` | 可读文件 |
| `"DIR"` | 目录 |
| `nil` | 不存在或不可读 |

```lua
if fs.test("main.lua") == "FILE" then
    print("是文件")
elseif fs.test("src") == "DIR" then
    print("是目录")
end
```

### `.join(...)`

拼接路径组件，自动处理重复分隔符。

```lua
local p = fs.join("a", "b", "c")   -- a/b/c
local p2 = fs.join("/usr/", "/local/", "bin")  -- /usr/local/bin
```

### `.mkdir(path)`

创建目录，等价于 `mkdir -p`。

```lua
fs.mkdir("build/output/logs")
```

### `.rm(path)`

删除文件或目录，等价于 `rm -rf`。自动判断类型使用 Lua 原生或 Shell 删除。

```lua
fs.rm("old.txt")
fs.rm("temp_dir")
```

### `.cp(src, dst)`

递归拷贝，等价于 `cp -r`。源不存在时返回 `false, "Source does not exist"`。

```lua
local ok = fs.cp("source.txt", "backup.txt")
fs.cp("src/", "dst/")
```

### `.mv(src, dst)`

移动/重命名文件或目录。优先使用 `os.rename`，失败则回退到 `mv` 命令（支持跨文件系统）。

```lua
fs.mv("old_name.lua", "new_name.lua")
fs.mv("/tmp/data", "./data")
```

### `.stat(path)`

获取文件详细属性。返回 table，包含以下字段：

| 字段 | 说明 |
|------|------|
| `size` | 字节大小 |
| `mtime` | 最后修改时间戳（Unix 秒） |
| `perm` | 权限数字（如 `644`） |
| `type` | 类型：`"FILE"`, `"DIR"`, `"LINK"`, `"OTHER"` |

路径不存在时返回 `nil, "Path does not exist"`。  
内部自动识别 GNU stat（Linux/MSYS2）与 BSD stat（macOS）。

```lua
local info, err = fs.stat("README.md")
if info then
    print("大小:", info.size)
    print("修改时间:", os.date("%c", info.mtime))
    print("权限:", info.perm)
    print("类型:", info.type)
end
```

## 完整示例

```lua
local fs = require("lunax.fs")

-- 创建项目结构
fs.mkdir("myapp/src")
fs.mkdir("myapp/test")

-- 拷贝模板
fs.cp("template/main.lua", "myapp/src/main.lua")

-- 列出创建结果
for _, f in ipairs(fs.ls("myapp/src")) do
    local info = fs.stat(fs.join("myapp/src", f))
    if info then
        print(f .. "  " .. tostring(info.size) .. "B")
    end
end

-- Stat 测试
local s = fs.stat("myapp/src/main.lua")
print(os.date("%Y-%m-%d %H:%M:%S", s.mtime))  -- 文件修改时间
```
