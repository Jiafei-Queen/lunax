local util = require('lunax.util')

local Logger = {}

-- 定义日志级别权重
local LEVELS = { DBG = 1, INF = 2, WRN = 3, ERR = 4 }
Logger.level = "DBG" -- 默认日志级别

-- ANSI 终端颜色码
local COLORS = {
    DBG = "\27[36m", -- 青色
    INF  = "\27[32m", -- 绿色
    WRN  = "\27[33m", -- 黄色
    ERR = "\27[31m", -- 红色
    RESET = "\27[0m"
}

-- 内部通用的高阶打印函数
local function log_message(level, module_name, ...)
    -- 如果当前级别低于设置的级别，则不打印
    if LEVELS[level] < LEVELS[Logger.level] then return end

    -- 1. 获取格式化时间
    local time_str = os.date("%Y-%m-%d %H:%M:%S")

    -- 2. 处理信息表
    local function simple_dump(t)
        local sb = {}
        for k, v in pairs(t) do
            table.insert(sb, string.format("%s=%s", tostring(k), tostring(v)))
        end
        return "{ " .. table.concat(sb, ", ") .. " }"
    end

    local msg_tab = {}
    for _,arg in util.sipairs({...}) do
        local msg = type(arg) == 'table'
            and simple_dump(arg)
            or tostring(arg)

        table.insert(msg_tab, msg)
    end

    -- 3. 组装标准输出格式
    local color = COLORS[level] or ""
    local reset = COLORS.RESET

    -- 核心输出模板
    local line = string.format(
    "[%s] %s[%s]%s [%s] - %s\n",            -- 模板
    time_str,                              -- 格式化时间
    color, level, reset,        -- 色彩等级
    module_name,                           -- 模块名称
    table.concat(msg_tab, ' ')   -- 信息
    )

    io.stderr:write(line)
end

-- 暴露给外部的快捷 API
function Logger.debug(module_name, ...) log_message("DBG", module_name, ...) end
function Logger.info(module_name, ...)  log_message("INF",  module_name, ...) end
function Logger.warn(module_name, ...)  log_message("WRN",  module_name, ...) end
function Logger.error(module_name, ...) log_message("ERR", module_name, ...) end

return Logger
