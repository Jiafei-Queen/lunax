# `lunax.exec` — 命令执行

对 `os.execute` 的封装，支持命令表拼接、工作目录设置、环境变量传递。跨平台兼容 Unix 与 Windows。

## 导入

```lua
local exec = require("lunax.exec")
```

## `exec(cmd, conf)`

执行外部命令并等待其完成。命令被包裹在 `(<cmd>)` 中执行。

### 返回值

返回一个包含以下字段的表格：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 退出码是否为 0 |
| `ext` | string \| nil | 退出状态类型（`"exit"` 或 `"signal"`），部分 Lua 版本可能不可用 |
| `code` | integer | 退出码（或信号编号） |

兼容 Lua 5.1 / 5.2+ / LuaJIT 三种 `os.execute` 返回值约定：
1. 返回数字：`{ ok = code == 0, ext = nil, code = code }`
2. 返回 boolean + string + number：`{ ok = a, ext = b, code = c }`
3. 仅返回 boolean：`{ ok = a, ext = nil, code = a and 0 or 1 }`

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `cmd` | string \| table | 命令字符串，或数组（自动以 `; ` 或 ` & ` 拼接） |
| `conf` | table | 配置项（见下表） |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `cwd` | string \| nil | 设置工作目录（Unix: `cd <path>`，Windows: `cd /d <path>`） |
| `env` | table \| nil | 环境变量键值对（Unix: `export KEY="value"`，Windows: `set KEY=value`） |
| `stdin` | string \| boolean \| nil | 输入重定向：`nil`（默认，继承父进程 stdin），字符串（从文件读取），`false`（从 `/dev/null` 或 `NUL` 读取） |

> **注意：** `exec` 不提供 `stdout`/`stderr` 重定向（参见 `lunax.popen`）。

### 示例

```lua
local exec = require("lunax.exec")

-- 基本用法
local exit = exec("ls -la")
if exit.ok then
    print("命令执行成功")
end

-- 命令以数组形式传入（自动以 "; " 拼接）
local exit = exec({ "mkdir", "-p", "build/output" })

-- 指定工作目录与环境变量
local exit = exec("npm install", {
    cwd = "/path/to/project",
    env = { NODE_ENV = "production" },
})

-- 从文件重定向 stdin
local exit = exec("sort", { stdin = "/tmp/input.txt" })

-- 从空设备读取 stdin
local exit = exec("read -t 0", { stdin = false })
```

### 跨平台说明

- **Unix:** 命令以 `; ` 拼接，使用 `cd` 切换目录，`export` 设置环境变量
- **Windows:** 命令以 ` & ` 拼接，使用 `cd /d` 切换目录，`set` 设置环境变量；带环境变量时使用 `cmd /v:on /c` 启用延迟扩展，`%VAR%` 转换为 `!VAR!`；自动执行 `chcp 65001 > NUL` 启用 UTF-8

### 错误处理

参数类型不匹配时抛出错误：

```
bad arg#1 for exec(): array or string expected, got map
bad arg#2 for 'exec(_, conf.cwd)': string expected, got number
bad arg#2 for 'exec(_, conf.env)': map<string, string> expected, got table
bad arg#2 for 'exec(_, conf.stdin)': string or boolean or nil expected, got number
```
