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
local function log_message(level, module_name, msg)
    -- 如果当前级别低于设置的级别，则不打印
    if LEVELS[level] < LEVELS[Logger.level] then return end

    -- 1. 获取格式化时间 (复用你之前的时间逻辑)
    local time_str = os.date("%Y-%m-%d %H:%M:%S")

    -- 2. 处理如果是 table 的情况 (联动你的 dump 逻辑)
    if type(msg) == "table" then
        -- 简单将其扁平化或转为单行，这里为了控制台好看，我们让它展开
        local function simple_dump(t)
            local sb = {}
            for k, v in pairs(t) do
                table.insert(sb, string.format("%s=%s", tostring(k), tostring(v)))
            end
            return "{ " .. table.concat(sb, ", ") .. " }"
        end
        msg = simple_dump(msg)
    else
        msg = tostring(msg)
    end

    -- 3. 组装标准输出格式
    local color = COLORS[level] or ""
    local reset = COLORS.RESET
    
    -- 核心输出模板
    local line = string.format("[%s] %s[%s]%s [%s] - %s\n", time_str, color, level, reset, module_name, msg)
    
    io.stderr:write(line)
end

-- 暴露给外部的快捷 API
function Logger.debug(module_name, msg) log_message("DBG", module_name, msg) end
function Logger.info(module_name, msg)  log_message("INF",  module_name, msg) end
function Logger.warn(module_name, msg)  log_message("WRN",  module_name, msg) end
function Logger.error(module_name, msg) log_message("ERR", module_name, msg) end

return Logger
