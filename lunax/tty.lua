local unix = require('lunax.os_prober') ~= 'NT'

---@class lunax.tty
local tty = {}

--- 获取终端尺寸
---@return string? rows 行数
---@return string? cols 列数
function tty.term_size()
    if unix then
        local handle = io.popen('stty size < /dev/tty ')
        local rows, cols = handle:read('*l'):match("(%d+)%s+(%d+)")
        handle:close()

        return rows, cols
    else
        local handle = io.popen('mode')
        local res = handle:read('*a')
        local rows = res:match('Lines:%s*(%d+)')
        local cols = res:match('Columns:%s*(%d+)')

        return rows, cols
    end
end

return tty
