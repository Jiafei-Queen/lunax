local popen = require('lunax.popen')
local logger = require('lunax.logger')

local function readline(prompt)
    local unix = require('lunax.os_prober') ~= 'NT'

    local ok, linenoise = (function()
        if unix then
            return pcall(require, 'linenoise')
        else
            return pcall(require, 'linenoise-windows')
        end
    end)()

    if ok then
        -- linenoise 遇见 SIGINT & EOF -> nil 而不报错
        return linenoise.linenoise(prompt)
    end

    local prompt = prompt or ''
    local cmd

    if unix then
        cmd = string.format([[bash -c 'bind "set disable-completion on"; set -f; read -e -p %q line < /dev/tty && echo $line']], prompt)
    else
        -- 1. 安全起见，先将提示符里的双引号替换 fracture 为单引号，避免破坏最外层的双引号
        -- 2. 使用 ^ 转义 CMD 的所有特殊重定向/管道字符 (& < > ( ) @ ^ |)
        local escaped_prompt = prompt:gsub('"', "'"):gsub('([&<>()@^|])', '^%1')

        -- 3. 采用单层纯净双引号包裹，内部不再嵌套任何双引号
        cmd = string.format([[cmd /F:OFF /c "(set /p input=%s) 1>&2 && cmd /v:on /c echo ^!input^!"]], escaped_prompt)
    end

    -- logger.debug('rl', 'cmd: '..cmd)
    local handle = assert(popen(cmd))

    -- 针对 bash readline SIGINT 行为
    local ok, line = pcall(function()
        return handle:read('*l')
    end)

    if not ok then
        print() -- 对齐 linenoise 行为
        handle:close()
        return
    end

    -- 针对 bash readline EOF 行为
    local ok = handle:close().ok
    if not ok or not line then
        print() -- 对齐 linenoise 行为
        return
    end

    -- logger.debug('rl', 'line: '..line)
    return line
end

return readline
