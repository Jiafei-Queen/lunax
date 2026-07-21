# `lunax.popen` — 增强进程调用

对 `io.popen` 的封装，支持命令表拼接、工作目录设置、环境变量传递、以及标准/异常输出重定向。跨平台兼容 Unix 与 Windows。  
与 `exec` 不同，`popen` 返回文件句柄，可用于异步读取/写入。

## 导入

```lua
local popen = require("lunax.popen")
```

## `popen(cmd, conf)`

执行命令并返回文件句柄代理。`mode` 默认为 `"r"`（读取模式），可传入 `"w"` 用于写入。命令被包裹在 `(<cmd>)` 中执行。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `cmd` | string \| table | 命令字符串，或字符串数组（自动以 `; ` 或 ` & ` 拼接） |
| `conf` | table | 配置项（见下表） |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `cwd` | string \| nil | 设置工作目录 |
| `env` | table \| nil | 环境变量键值对 |
| `stdout` | string \| boolean \| nil | `nil`（默认，捕获输出），`false`（丢弃到 `/dev/null` 或 `NUL`），或文件路径（重定向到文件） |
| `stderr` | string \| boolean \| nil | `true`（合并到 stdout 即 `2>&1`），`false`（丢弃），或文件路径 |
| `mode` | string? | 句柄模式（e.g. `r`, `w`） |

### 示例

```lua
local popen = require("lunax.popen")

-- 基本用法
local handle = popen("ls -la")
if handle then
    for line in handle:lines() do
        print(line)
    end
    handle:close()
end

-- 命令以数组形式传入
local handle = popen("git log --oneline", "-5", { stderr = true })

-- 指定工作目录与输出重定向
local handle = popen("npm test", {
    cwd = "/path/to/project",
    env = { NODE_ENV = "test" },
    stdout = "/tmp/test_output.log",
    stderr = true,
})

-- 丢弃输出，仅捕获错误
local handle = popen("some_command", {
    stdout = false,
    stderr = true,
})
```

### 返回值

成功时返回文件句柄代理对象，支持除 `close` 外的所有标准文件方法（`read`、`write`、`lines`、`seek` 等）。  
`handle:close()` 返回一个包含以下字段的表格：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 退出码是否为 0 |
| `ext` | string \| nil | 退出状态类型（`"exit"` 或 `"signal"`） |
| `code` | integer | 退出码（或错误码） |

失败时返回 `nil`（pipe 打开失败）或抛出参数类型错误。

错误消息示例：

```
bad arg#1 for popen(): array or string expected, got boolean
bad arg#2 for 'popen(_, conf.cwd)': string expected, got number
bad arg#2 for 'popen(_, conf.env)': map<string, string> expected, got string
```

### 跨平台说明

- **Unix:** 命令以 `; ` 拼接；`export KEY=value` 设置环境变量；`/dev/null` 丢弃输出
- **Windows:** 命令以 ` & ` 拼接；`set KEY=value` 设置环境变量；`NUL` 丢弃输出；自动 `chcp 65001 > NUL` 启用 UTF-8；带环境变量时使用 `cmd /v:on /c` 启用延迟扩展，`%VAR%` 转换为 `!VAR!`
- **LuaJIT (Unix):** 自动写入退出码到临时文件以实现可靠捕获

### 与 `exec` 的区别

| 特性 | `exec` | `popen` |
|------|--------|---------|
| 执行方式 | 同步阻塞 (`os.execute`) | 异步 (`io.popen`，可流式读写) |
| stdout 捕获 | 无 | 支持（通过 `handle:read()`） |
| stdout/stderr 重定向 | 无 | 支持 |
| 返回值 | exit info table | 文件句柄代理 |
