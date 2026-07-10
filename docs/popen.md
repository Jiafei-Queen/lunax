# `lunax.popen` — 增强进程调用

对 `io.popen` 的封装，支持命令表拼接、工作目录设置、环境变量传递、以及标准/异常输出重定向。跨平台兼容 Unix 与 Windows。

## 导入

```lua
local popen = require("lunax.popen")
```

## `popen(cmd, conf, [mode])`

执行命令并返回文件句柄。`mode` 默认为 `"r"`（读取模式），可传入 `"w"` 用于写入。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `cmd` | string \| table | 命令字符串，或字符串数组（自动拼接） |
| `conf` | table | 配置项（见下表） |
| `mode` | string | 可选，`io.popen` 模式（默认 `"r"`） |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `cwd` | string \| nil | 设置工作目录 |
| `env` | table \| nil | 环境变量键值对 |
| `stdout` | string \| boolean \| nil | `true`（默认，捕获输出），`false`（丢弃），或文件路径 |
| `stderr` | string \| boolean \| nil | `true`（合并到 stdout），`false`（丢弃），或文件路径 |

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
local handle = popen({ "git", "log", "--oneline", "-5" }, { stderr = true })

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

### 跨平台说明

- **Unix:** 使用 `export KEY=value` 设置环境变量，`/dev/null` 丢弃输出
- **Windows:** 使用 `set KEY=value` 设置环境变量，`NUL` 丢弃输出

### 返回值

成功时返回 `io.popen` 文件句柄。失败时抛出错误，描述是哪个参数不合法：

```
bad arg#2 for exec(): string or nil at cwd
```
