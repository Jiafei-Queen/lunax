# `lunax.fs` — 文件系统操作

基于 Shell 命令封装的文件系统工具模块，提供路径拼接、文件检测、读写删移等常用操作。  
内部自动处理路径转义，兼容 GNU/Linux 与 BSD/macOS。

## 导入

```lua
local fs = require("lunax.fs")
```

## 属性

### `.src`

当前脚本的完整路径（绝对路径 + 文件名）。在模块加载时自动计算并缓存。

```lua
print(fs.src)  -- 例如: /Users/me/project/main.lua
```

## 函数参考

### `.cwd()`

获取当前工作目录（等价于 `pwd`）。

```lua
print(fs.cwd())  -- 例如: /Users/me/project
```

### `.ls([path])`

列出目录下所有条目，等价于 `ls -A`（不包含 `.` 和 `..`，但包含隐藏文件）。  
默认列出当前目录。管道关闭失败时会抛出错误。

```lua
local files = fs.ls()         -- 列出当前目录
for _, f in ipairs(files) do
    print(f)
end

local all = fs.ls("/tmp")     -- 列出 /tmp
```

### `.test(path, type)`

检测路径是否匹配指定类型。使用 `test` 命令进行判断。\
`type` 可以传入内置名称或直接的 test 标志字符（如 `"f"`, `"d"`）。

| type | 含义 |
|------|------|
| `"FILE"` | 是否为文件 |
| `"DIR"` | 是否为目录 |
| `"LINK"` | 是否为符号链接 |
| `"EXIST"` | 是否存在 |

```lua
if fs.test("main.lua", "FILE") then
    print("是文件")
elseif fs.test("src", "DIR") then
    print("是目录")
end
```

### `.join(...)`

拼接文件系统路径组件，自动处理重复分隔符。

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

删除文件或目录，等价于 `rm -rf`。目录使用 `rm -rf`，文件使用 Lua 原生 `os.remove`。

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

移动/重命名文件或目录。优先使用 `os.rename`，失败则回退到 `mv` 命令（支持跨文件系统）。源不存在时返回 `false, "Source does not exist"`。

```lua
fs.mv("old_name.lua", "new_name.lua")
fs.mv("/tmp/data", "./data")
```

### `.find(path, name, type)`

递归搜索文件，等价于 `find` 命令。`name` 支持通配符。`type` 可选，可选值为 `"FILE"`, `"DIR"`, `"LINK"`。

```lua
local lua_files = fs.find(".", "*.lua")
local all_dirs = fs.find("src", "*", "DIR")
```

### `.stat(path)`

获取文件详细属性。返回 table，包含以下字段：

| 字段 | 说明 |
|------|------|
| `size` | 字节大小 |
| `mtime` | 最后修改时间戳（Unix 秒） |
| `perm` | 权限字符串（如 `rwxr-xr-x`） |
| `type` | 类型：`"FILE"`, `"DIR"`, `"LINK"`, `"OTHER"` |

路径不存在时抛出错误。  
内部自动识别 GNU stat（Linux/MSYS2）与 BSD stat（macOS）。

```lua
local info = fs.stat("README.md")
print("大小:", info.size)
print("修改时间:", os.date("%c", info.mtime))
print("权限:", info.perm)
print("类型:", info.type)
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
    print(f .. "  " .. tostring(info.size) .. "B")
end

-- Stat 测试
local s = fs.stat("myapp/src/main.lua")
print(os.date("%Y-%m-%d %H:%M:%S", s.mtime))  -- 文件修改时间
```
