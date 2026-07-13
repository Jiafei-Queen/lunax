# `lunax.margs` — 命令行参数解析

结构化命令行参数解析模块，支持子命令、短/长选项、等号选项、多值选项、模式匹配选项及自动帮助输出。  
未知选项和多余参数被静默忽略。

## 导入

```lua
local margs = require("lunax.margs")
```

## 顶层参数

```lua
local params = {
    usage = "myapp <command> [options]",
    help = {
        Commands = {
            { "build", "构建项目" },
            { "run",   "运行应用" },
        },
        ["Environment"] = "NODE_ENV: production | development",
    },
    single = { "--version", "--help" },
    build = { ... },
    run   = { ... },
}
```

### `single`

定义 **无值标志**，匹配后即设 `result[flag] = true`。支持 `only` 属性在匹配后立即返回结果：

```lua
single = {
    "--version",
    { "--help", only = true },
}
```

### `help`

顶层帮助信息，可选。当 `--help` / `-h` 出现在第一个参数位置时显示。`Commands` 区域会被格式化为对齐列表，其余为纯文本段落。

---

## 子命令参数

每个子命令的配置结构如下：

### `single`

当前子命令下的无值标志：

```lua
single = {
    "--verbose",
    { "--dry-run", only = true },
}
```

支持通过 `pattern` 字段进行正则捕获：

```lua
single = {
    { "--lang=", pattern = "^%-%-lang=(%w+)$", tag = "lang", help = "语言" },
}
```

`pattern` 优先级最高，按定义顺序匹配。

### `space`

空格分隔的选项，后跟一个或多个值：

```lua
space = {
    { flag = { "--output", "-o" }, tag = "output", help = "输出路径" },
    { flag = { "--file", "-f" }, tag = "file", help = "输入文件" },
}
```

- `flag` — 触发该选项的所有名称
- `tag` — 结果中使用的键名
- `help` — 帮助文本（字符串或 table 用于分组显示）
- `multi` — 若为 `true`，则收集后续所有非选项参数为数组

```lua
-- multi 示例
space = {
    { flag = { "--include" }, tag = "include", multi = true, help = "搜索路径" },
}
-- 输入: build --include src /usr/lib /opt
-- 结果: { include = { "src", "/usr/lib", "/opt" } }
```

### `equal`

等号分隔的选项：

```lua
equal = {
    { "--name", help = "项目名称" },
    { "--port", help = "端口号" },
}
```

也可用纯字符串形式（无帮助文本）：

```lua
equal = { "--name", "--port" }
```

输入 `--name=myapp` 会在结果中生成 `name = "myapp"`。

### `help`

子命令的帮助配置。当匹配到 `help.flag` 中的标志（如 `--help`）时触发：

```lua
help = {
    flag = { "--help", "-h" },
    template = "\n%s:\n",
    Usage = "build [options]",
    Examples = "myapp build --output ./dist",
}
```

---

## `margs.parse(args, param)`

解析命令行参数，返回结构化的结果 table。

```lua
local result = margs.parse(args, param)
```

### 解析流程

1. `args[1]` 为 `--help` / `-h` 时显示顶层帮助并 `os.exit(0)`
2. 检查顶层 `single` 标志（如 `--version`）；带 `only` 属性的匹配后立即返回
3. `args[1]` 匹配子命令名；无匹配时返回空 table
4. 从 `args[2]` 开始依次解析：
   - 帮助标志 → 显示子命令帮助并退出
   - space 选项 → 取下一个/多个参数为值
   - equal 选项 → 按 `=` 分割
   - single 标志 → 设 `true`
   - pattern 匹配 → 捕获值
   - 无匹配 → 静默跳过

### 返回值结构

- 顶层 `single` 匹配到第一个参数时：`{ ["--version"] = true }`
- 子命令匹配时：`{ build = { output = "dist", verbose = true } }`
- 无匹配时返回空 table `{}`

### 完整示例

```lua
local margs = require("lunax.margs")

local params = {
    usage = "myapp <command> [options]",
    help = {
        Commands = {
            { "build", "编译项目" },
            { "run",   "启动服务" },
        },
    },
    single = { "--version" },

    build = {
        space = {
            { flag = { "--output", "-o" }, tag = "output", help = "输出目录" },
        },
        single = {
            { "--release", help = "发布模式" },
        },
        help = {
            flag = { "--help" },
            Usage = "myapp build [options]",
        },
    },

    run = {
        equal = {
            { "--port", help = "监听端口" },
        },
        help = {
            flag = { "--help" },
            Usage = "myapp run [options]",
        },
    },
}

local result = margs.parse({ "build", "--output", "./dist", "--release" }, params)
-- result == { build = { output = "./dist", release = true } }

local version_result = margs.parse({ "--version" }, params)
-- version_result == { ["--version"] = true }
```
