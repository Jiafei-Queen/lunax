# `lunax.logger` — 彩色日志

轻量级彩色日志模块，支持 4 个日志级别、级别过滤、自动 Table 转字符串输出。  
日志格式：`[时间戳] [级别] [模块名] - 消息`  
所有日志写入 `io.stderr`（标准错误输出），不干扰 stdout 的正常输出。

## 导入

```lua
local logger = require("lunax.logger")
```

## 日志级别

| 函数 | 级别名 | 颜色 | 权重 |
|------|--------|------|------|
| `.debug(module, ...)` | DBG | 青色 | 1 |
| `.info(module, ...)` | INF | 绿色 | 2 |
| `.warn(module, ...)` | WRN | 黄色 | 3 |
| `.error(module, ...)` | ERR | 红色 | 4 |

所有函数接受 **模块名**（字符串）作为第一个参数，后续可变参数自动空格拼接。table 参数自动展开为 `{ key=value, ... }` 格式。

### 示例

```lua
logger.info("app", "服务已启动")
logger.debug("db", "查询耗时:", "12ms")
logger.warn("app", "内存使用率 85%")
logger.error("core", "连接超时")
logger.info("config", { host = "localhost", port = 8080 })
```

输出示例：

```
[2026-07-05 14:30:22] [INF] [app] - 服务已启动
[2026-07-05 14:30:22] [WRN] [app] - 内存使用率 85%
[2026-07-05 14:30:22] [ERR] [core] - 连接超时
[2026-07-05 14:30:22] [INF] [config] - { host="localhost", port=8080 }
```

## 日志级别过滤

通过设置 `logger.level` 控制最低输出级别。默认值为 `"DBG"`（全部输出）。

```lua
logger.level = "WRN"      -- 仅显示 WRN 及以上
logger.debug("db", "隐藏") -- 不输出（权重 1 < 3）
logger.error("db", "显示") -- 输出（权重 4 >= 3）
```

可用值（按优先级从低到高）：`"DBG"` (1) < `"INF"` (2) < `"WRN"` (3) < `"ERR"` (4)

## Table 消息

当消息参数为 table 时，自动展开为单行键值对：

```lua
logger.info("config", { host = "localhost", port = 8080, ssl = true })
```

输出：

```
[2026-07-05 14:30:22] [INF] [config] - { host="localhost", port=8080, ssl=true }
```

## 完整示例

```lua
local logger = require("lunax.logger")

function load_config(path)
    logger.info("config", "加载配置:", path)
    local ok = true
    if not ok then
        logger.error("config", "配置文件损坏")
        return nil
    end
    logger.info("config", { status = "loaded", path = path })
    return {}
end

-- 仅显示 INFO 及以上
logger.level = "INF"

load_config("settings.lua")
logger.debug("db", "这行不会输出")  -- 被过滤
```
