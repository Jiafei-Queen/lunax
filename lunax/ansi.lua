local Ansi = {}

-- 1. 智能检测：判断当前标准输出是否是真正的终端 (TTY)
-- 如果是在终端里跑，is_tty 为 true；如果被重定向到了文件或管道，为 false
-- 1. 智能检测：跨平台判断当前标准输出是否是真正的终端 (TTY)
local is_tty = false

-- 根据操作系统选择检测命令
-- Windows (cmd/powershell) 本身没有标准的 test -t 命令，但可以通过判断环境变量或使用特定方式
if package.config:sub(1,1) == '\\' then
    -- Windows 环境
    -- 1. 检查是否在主流的新版终端、Git Bash 或 MSYS2 下（它们会设置 TERM）
    local term = os.getenv("TERM")
    if term and term ~= "" and term ~= "dumb" then
        is_tty = true
    else
        -- 2. 针对纯 Windows 原生控制台的终极 TTY 检查：
        -- 尝试在后台往 conOut$（Windows的当前控制台输出伪文件）写点东西，能打开说明是交互式 TTY
        local f = io.open("CONOUT$", "w")
        if f then
            is_tty = true
            f:close()
        end
    end
else
    -- Linux / macOS 环境
    local handle_t = io.popen("test -t 1 2>/dev/null")
    if handle_t then
        local ok = handle_t:close()
        if ok == true or ok == 0 or os.execute("test -t 1 2>/dev/null") == 0 then
            is_tty = true
        end
    end
end

-- 2. 基础转义前缀定义
local ESC = "\27["

-- 3. 静态控制字符（如果是非终端环境，则全部置为空字符串，防止污染文件）
Ansi.reset         = is_tty and (ESC .. "0m") or ""
Ansi.clear         = is_tty and (ESC .. "2J" .. ESC .. "H") or "" -- 清屏并回到左上角
Ansi.clear_line    = is_tty and (ESC .. "K") or ""
Ansi.move_line_top = is_tty and (ESC .. "G") or ""
Ansi.hide_cursor   = is_tty and (ESC .. "?25l") or ""
Ansi.show_cursor   = is_tty and (ESC .. "?25h") or ""
Ansi.save_cursor   = is_tty and (ESC .. "s") or ""
Ansi.restore_cursor = is_tty and (ESC .. "u") or ""
Ansi.enter_alt_bg  = is_tty and (ESC .. "?1049h") or "" -- 进入备用缓冲区 (如 vim)
Ansi.exit_alt_bg   = is_tty and (ESC .. "?1049l") or ""  -- 退出备用缓冲区

-- 4. 光标动态移动函数
function Ansi.move_to(row, col)   return is_tty and (ESC .. (row or 1) .. ";" .. (col or 1) .. "H") or "" end
function Ansi.cursor_up(n)        return is_tty and (ESC .. (n or 1) .. "A") or "" end
function Ansi.cursor_down(n)      return is_tty and (ESC .. (n or 1) .. "B") or "" end
function Ansi.cursor_right(n)     return is_tty and (ESC .. (n or 1) .. "C") or "" end
function Ansi.cursor_left(n)      return is_tty and (ESC .. (n or 1) .. "D") or "" end

-- 5. 256 色与 TrueColor (RGB) 支持
function Ansi.rgb(r, g, b)
    if not is_tty then return function(text) return tostring(text) end end
    return function(text)
        return string.format("%s38;2;%d;%d;%dm%s%s", ESC, r, g, b, tostring(text), Ansi.reset)
    end
end

function Ansi.bg_rgb(r, g, b)
    if not is_tty then return function(text) return tostring(text) end end
    return function(text)
        return string.format("%s48;2;%d;%d;%dm%s%s", ESC, r, g, b, tostring(text), Ansi.reset)
    end
end

-- 6. 核心样式表（映射你的速查表）
local styles = {
    -- 高亮样式
    bold = "1", dim = "2", italic = "3", underline = "4", blink = "5", reverse = "7", hidden = "8", strikethrough = "9",
    -- 前景色 (基础前景色)
    black = "30", red = "31", green = "32", yellow = "33", blue = "34", magenta = "35", cyan = "36", white = "37",
    -- 背景色 (基础背景色)
    bg_black = "40", bg_red = "41", bg_green = "42", bg_yellow = "43", bg_blue = "44", bg_magenta = "45", bg_cyan = "46", bg_white = "47"
}

-- 7. 利用元表让调用变得极度丝滑
-- 允许通过 ansi.red("text")、ansi.bold("text") 直接包裹文本
setmetatable(Ansi, {
    __index = function(_, key)
        local code = styles[key]
        if code then
            return function(text)
                if not is_tty then return tostring(text) end
                return ESC .. code .. "m" .. tostring(text) .. Ansi.reset
            end
        end
    end
})

return Ansi
