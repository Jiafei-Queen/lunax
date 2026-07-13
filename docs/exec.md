# `lunax.exec` — 命令执行

对 `os.execute` 的封装，支持命令表拼接、工作目录设置、环境变量传递、以及标准/异常输出重定向。跨平台兼容 Unix 与 Windows。

## 导入

```lua
local exec = require("lunax.exec")
```

## `exec(cmd, conf)`

执行外部命令并等待其完成。

### 返回值

返回一个包含以下字段的表格：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 退出码是否为 0 |
| `ext` | string \| nil | 退出状态类型（`"exit"` 或 `"signal"`），LuaJIT 上不可用 |
| `code` | integer | 退出码（或信号编号） |

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `cmd` | string \| table | 命令字符串，或字符串数组（自动拼接） |
| `conf` | table | 配置项（见下表） |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `cwd` | string \| nil | 设置工作目录 |
| `env` | table \| nil | 环境变量键值对 |
| `stdout` | string \| boolean \| nil | `true`（默认，显示输出），`false`（丢弃），或文件路径 |
| `stderr` | string \| boolean \| nil | `true`（合并到 stdout），`false`（丢弃），或文件路径 |

### 示例

```lua
local exec = require("lunax.exec")

-- 基本用法
local exit = exec("ls -la")
if exit.ok then
    print("命令执行成功")
end

-- 命令以数组形式传入
local exit = exec({ "mkdir", "-p", "build/output" })

-- 指定工作目录与环境变量
local exit = exec("npm install", {
    cwd = "/path/to/project",
    env = { NODE_ENV = "production" },
})

-- 丢弃输出
local exit = exec("some_noisy_command", {
    stdout = false,
    stderr = false,
})

-- 将输出写入文件
local exit = exec("long_running_task", {
    stdout = "/tmp/output.log",
    stderr = true,
})
```

### 跨平台说明

- **Unix:** 使用 `cd` 命令切换目录，`export` 设置环境变量，`/dev/null` 丢弃输出
- **Windows:** 使用 `set` 设置环境变量，`NUL` 丢弃输出

### 错误处理

参数类型不匹配时抛出错误：

```
bad arg#1 for exec(): expected table or string
bad arg#2 for exec(): string or nil at cwd
bad arg#2 for exec(): table or nil at env
bad arg#2 for exec(): string or boolean or nil at stdout
```
