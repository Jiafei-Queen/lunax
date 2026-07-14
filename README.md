# Lunax

可移植自动化脚本？
- C/C++/Rust - 杀鸡用牛刀
- Python/Ruby - 分发有点重
- Bash/Bat/PS - 不跨平台（至少很麻烦）

想要：

- [✓] 方便轻量
- [✓] 移植简单
- [✓] 分发方便

那么... **Lunax 就是你想要的**

Lunax 是一个纯 Lua 实现，在 Unix 与 Windows 环境下，提供 C 库与系统工具和 Shell（sh, bash）操作封装调度的库。

## 特征

- 轻量：LuaVM 占用 1~2MB，磁盘占用 < 400KB
- 强大：Lua Table 的灵活；强大的模式匹配；元表编程
- 可移植性高：Lua 由 ANSI C 编写，可被轻易编译

**强烈推荐：**

[Oxiluna](https://github.com/Jiafei-Queen/oxiluna) 是一个基于 Rust `mlua` crate 的构建工具，方便地**将 Lua 交叉编译成各种平台的二进制**（磁盘占用 < 1MB）借助 `cargo` 的强大

--> Example

```bash
# Oxiluna 会自动搜寻依赖，并对动态库给出警告
oxiluna foo.lua -o program
```

## 注意 ⚠️

本项目致力于为 Lua 设计 Pure Lua “标准库”

### 1. Lua 版本选择

为了获取 **更新的语法支持** 与 **位运算支持**，并且保证 **通用性与兼容性**，需要保证 Lua 版本 >= Lua5.4。

### 2. 复杂需求（e.g. *数据库连接*，*Web 服务器* 等）：

一般需要

- 第三方 C Binding（[Luarocks](https://luarocks.org) 上有丰富的现成库，但不保证是否能在特定环境下编译）
- 自行调用命令行工具

所以：对此我更推荐使用 Python, Ruby, Perl 等更加成熟、适合的语言实现脚本


### 3. 可靠性？

Lunax 至少在

- [✓] *Microsoft NT*     - Windows 10 LTSC 21H2
- [✓] *Apple Darwin*     - macOS latest
- [✓] *GNU/Linux*        - Debian trixie

裸环境中经过了 [可用性测试](docs/test.md)，保证各模块能正常使用，适配了各种主流平台工具版本的参数传递，输出格式等

> 对于 Windows 1803+ Utils、GNU coreutils、BSD Userland (macOS Edition) 支持良好

部分适配：

- [ · ] FreeBSD（试验性）
    - 所有模块基本可用，不保证边缘情况正常工作

- [ · ] Alpine Linux
    - *BusyBox* 适配进行中，部分模块表现不符合预期
    - `curl` 模块无法使用（需 `apk install curl`）

不会适配：

- [ x ] AIX
    - 绝大部分模块无法按预期运行
    - 本项目并没有能力维护纯 AIX 环境

## 快速开始

### 安装

1. 安装 Lua5.4

```bash
lua -v  # 应输出 `Lua 5.4.x ...`
```

2. 配置
```bash
# 克隆仓库
git clone https://github.com/Jiafei-Queen/lunax <path>

# 配置 LUA_PATH
export LUA_PATH="<path>/?.lua;;"
```

## 模块

| 模块 | 说明 |
|------|------|
| [`lunax.os_prober`](docs/os_prober.md) | 操作系统检测 — Windows -> 'NT', Unix -> 'Kernal Name' |
| [`lunax.exec`](docs/exec.md) | 更高级的 `os.execute` 跨平台封装，支持方便的 table cmd, cwd, env 指定、stdout, stderr 分离/重定向/抛弃，自动处理编码 |
| [`lunax.popen`](docs/popen.md) | 更高级的 `io.popen`，同 exec，并同时支持 write, lines 函数 |
| [`lunax.fs`](docs/fs.md) | 文件系统操作 — `ls`、`mkdir`、`rm`、`cp`、`mv`、`find`、`stat` 等，可选 `lfs` 加速 |
| [`lunax.rl`](docs/rl.md) | 交互式 Readline 输入 — 支持方向键（在 Unix 系统上使用 *Bash Readline*，Windows 使用 *CMD ReadConsole*，可选 `linenoise`、`linenoise-windows` 优化性能 |
| [`lunax.margs`](docs/margs.md) | 声明式，强大的参数解析器 |
| [`lunax.ansi`](docs/ansi.md) | ANSI 终端控制 — 颜色（含 TrueColor）、样式、光标移动、缓冲区切换 |
| [`lunax.logger`](docs/logger.md) | 彩色日志 — 多级别日志、级别过滤、Table 自动展开 |
| [`lunax.util`](docs/util.md) | 通用工具 — 格式化输出 `dump`、字符串 `trim`/`split`、深度 `clone`、字节格式化 `hsz`、表顺序迭代器 `spairs`、数组判断 `is_array`、格式化 Lua 风格类型错误 `fmt_type_err` |
| [`lunax.json`](docs/json.md) | JSON 编码/解码 — 可选 `lua-cjson`，回退 `dkjson` |
| [`lunax.hash`](docs/hash.md) | 封装 SHA256/512, md5 系统工具处理 文件/字符串，纯 Lua 实现 Adler32, CRC32 |
| [`lunax.base64`](docs/base64.md) | `certutil` 和 `base64` 提供文件编解码，纯 Lua 实现字符串编解码
| [`lunax.archive`](docs/archive.md) | 封装了系统工具进行压缩/解压，支持 tar, zip, gz, bz2（ Windows 10 1803+ ) |
| [`lunax.curl`](docs/curl.md) | 对于 `curl` 命令行工具（ Windows 10 1803+ ) 的封装，支持 HTTP 和文件传输 FTP/SFTP/SCP 以及 接收/发送 邮件 SMTP/IMAP/POP3 |

> `lunax.archive` 模块正在建设中...

### 使用示例

```lua
-- entries.lua
--- [ 列出当前目录下的隐藏条目 ] ---
local fs = require('lunax.fs')

for _,entry in ipairs(fs.ls()) do
    if entry:sub(1, 1) == '.' then
        print(entry)
    end
end
```

--> Build and Run
```bash
# 使用 Lua
lua entries.lua

# 使用 Oxiluna 构建 Windows 分发（需要安装 Oxiluna 与对应 Rust 编译环境）
oxiluna entries.lua --target x86_64-pc-windows-gnu
```