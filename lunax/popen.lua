local util = require('lunax.util')
local fmt = util.fmt_type_err

local function popen(cmd, conf, mode)
    -- 命令
    if type(cmd) == 'table' then
        if not util.is_array(cmd) then
            error(fmt(1, 'exec', 'array or string', 'map'))
        end

        cmd = table.concat(cmd, ' ')
    elseif type(cmd) ~= 'string' then
        error(fmt(1, 'exec', 'array or string', type(cmd)))
    end

    cmd = '('..cmd..')'

    -- 当前目录
    if type(conf.cwd) == 'string' then
        cmd = (' cd %q; '):format(conf.cwd)..conf.cwd
    elseif conf.cmd ~= nil then
        error(fmt(2, 'exec(_, conf.cwd)', 'string', type(conf.cwd)))
    end

    local unix = require('lunax.os_prober') ~= 'NT'

    -- 环境变量
    if type(conf.env) == 'table' then
        for k,v in pairs(conf.env) do
            if type(k) ~= 'string' or type(v) ~= 'string' then
                error(fmt(2, 'exec(_, conf.env)', 'map<string, string>', 'map<T, T>'))
            end

            cmd = unix and (' export %s="%s"; '):format(k, v)..cmd
                or (' set %s=%s; '):format(k, v)..cmd
        end
    elseif conf.env ~= nil then
        error(fmt(2, 'exec(_, conf.env)', 'map<string, string>', type(conf.env)))
    end

    -- 标准/异常输出
    local set = {
        stdout = 1,
        stderr = 2
    }

    for k,v in pairs(set) do
        if type(conf[k]) == 'string' then
            cmd = cmd .. (' %d> %q '):format(v, conf[k])
        elseif type(conf[k]) == 'boolean' then
            if not conf[k] then
                cmd = unix and cmd..(' %d> /dev/null '):format(v)
                    or cmd..(' %d> NUL '):format(v)
            end

            -- stderr & true -> stdout
            if k == 'stderr' and conf[k] then
                cmd = cmd..' 2>&1 '
            end
        elseif conf[k] ~= nil then
            fmt(2, ('exec(_, conf.%s)'):format(k), 'string or boolean or nil', type(conf[k]))
        end
    end

    cmd = not unix and 'chcp 65001; '..cmd or cmd
    -- print(cmd)
    return io.popen(cmd, mode)
end

return popen