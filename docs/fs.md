# `lunax.fs` — 文件系统操作

文件系统工具模块，优先使用 LuaFileSystem (`lfs`) 提供高性能本地调用，回退到 Shell 命令。  
自动处理跨平台路径转换（Unix / Windows），兼容 GNU/Linux、BSD/macOS 与 Windows（含 MSYS2）。

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

### `.cwd`

获取当前工作目录（等价于 `pwd`）。在模块加载时自动计算并缓存。

```lua
print(fs.cwd)  -- 例如: /Users/me/project
```

## 函数参考

### `.ls([path])`

列出目录下所有条目，等价于 `ls -A`（不包含 `.` 和 `..`，但包含隐藏文件）。  
默认列出当前目录。当 `lfs` 可用时优先使用 `lfs.dir`，否则回退到系统命令（Unix 使用 `ls -A`，Windows 使用 `dir /b /a`）。若管道关闭失败则抛出错误。

```lua
local files = fs.ls()         -- 列出当前目录
for _, f in ipairs(files) do
    print(f)
end

local all = fs.ls("/tmp")     -- 列出 /tmp
```

### `.test(path, type)`

检测路径是否匹配指定类型。当 `lfs` 可用时优先使用 `lfs.attributes`，否则回退到系统命令（Unix 使用 `test -<type>`，Windows 使用 `if exist` 及 `dir /a:l` 等内部命令）。

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

创建目录，等价于 `mkdir -p`。当 `lfs` 可用时逐层创建，否则使用系统命令（Unix 使用 `mkdir -p`，Windows 使用 `mkdir 2>nul`）。

```lua
fs.mkdir("build/output/logs")
```

### `.rm(path)`

删除文件或目录，等价于 `rm -rf`。当 `lfs` 可用时递归删除目录，否则使用系统命令（Unix 使用 `rm -rf`，Windows 使用 `rd /s /q` 删除目录、`del /f /q` 删除文件）。  
路径不存在时静默返回 `true`。

```lua
fs.rm("old.txt")
fs.rm("temp_dir")
```

### `.cp(src, dst)`

递归拷贝，等价于 `cp -r`。源不存在时返回 `false, "Source does not exist"`。  
Windows 下目录使用 `xcopy`、文件使用 `copy` 实现。

```lua
local ok = fs.cp("source.txt", "backup.txt")
fs.cp("src/", "dst/")
```

### `.mv(src, dst)`

移动/重命名文件或目录。优先使用 `os.rename`，失败则回退到系统命令（Unix 使用 `mv`，Windows 使用 `move`，目录跨盘符时退化到 `cp + rm`）。源不存在时返回 `false, "Source does not exist"`。成功后返回 `true`。

```lua
fs.mv("old_name.lua", "new_name.lua")
fs.mv("/tmp/data", "./data")
```

### `.find(path, name, type)`

递归搜索文件，等价于 `find` 命令。`name` 支持通配符。`type` 可选，可选值为 `"FILE"`, `"DIR"`, `"LINK"`。  
自动去除路径末尾的冗余斜杠。Unix 下使用 `find` 命令，Windows 下使用 `dir /s /b`。

```lua
local lua_files = fs.find(".", "*.lua")
local all_dirs = fs.find("src", "*", "DIR")
```

### `.stat(path)`

获取文件详细属性。当 `lfs` 可用时优先使用 `lfs.attributes`，否则回退到 `stat` 命令（自动识别 GNU / BSD）。  
Windows 无 `lfs` 时执行最佳推测（通过 `NUL` 目录标记和 `io.open`）。  
路径不存在时返回 `nil, err`。

返回 table 包含以下字段：

| 字段 | 说明 |
|------|------|
| `size` | 字节大小 |
| `mtime` | 最后修改时间戳（Unix 秒） |
| `perm` | 权限字符串（如 `rwxr-xr-x`） |
| `type` | 类型：`"FILE"`, `"DIR"`, `"LINK"`, `"OTHER"` |

```lua
local info = fs.stat("README.md")
if info then
    print("大小:", info.size)
    print("修改时间:", os.date("%c", info.mtime))
    print("权限:", info.perm)
    print("类型:", info.type)
end
```

## 跨平台支持

- **Unix / Linux / macOS:** 使用 Shell 命令或 `lfs`
- **Windows:** 使用 Windows 原生命令（`dir`、`xcopy`、`rd` 等），通过 `win_quote()` 安全转义路径；通过 `lfs_path()` 将 MSYS2 风格路径转换为 Windows 格式供 `lfs` 识别

## 可选依赖

- [LuaFileSystem (lfs)](https://github.com/lunarmodules/luafilesystem) — 提供高性能文件系统操作，推荐安装

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
if s then
    print(os.date("%Y-%m-%d %H:%M:%S", s.mtime))  -- 文件修改时间
end
```
