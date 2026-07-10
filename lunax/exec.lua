local function fmt_err(idx, type, suffix)
    local err = ('bad arg#%d for exec(): expected %s'):format(idx, type)
    err = suffix and err..' '..suffix or err

    error(err)
end

local function exec(cmd, conf)
    -- 命令
    if type(cmd) == 'table' then
        cmd = table.concat(cmd, ' ')
    elseif type(cmd) ~= 'string' then
        fmt_err(1, 'table or string')
    end

    cmd = '('..cmd..')'

    -- 当前目录
    if type(conf.cwd) == 'string' then
        cmd = (' cd %q; '):format(conf.cwd)..cmd
    elseif conf.cmd ~= nil then
        fmt_err(2, 'string or nil', 'at cwd')
    end

    local unix = require('lunax.os_prober') ~= 'NT'

    -- 环境变量
    if type(conf.env) == 'table' then
        for k,v in pairs(conf.env) do
            if type(k) ~= 'string' or type(v) ~= 'string' then
                fmt_err(2, 'string', 'at env.k&v')
            end

            cmd = unix and (' export %s="%s"; '):format(k, v)..cmd
                or (' set %s=%s; '):format(k, v)..cmd
        end
    elseif conf.env ~= nil then
        fmt_err(2, 'table or nil', 'at env')
    end

    -- 标准/异常输出
    local set = {
        stdout = 1,
        stderr = 2
    }

    for k,v in pairs(set) do
        if type(conf[k]) == 'string' then
            cmd = cmd .. (' %d> %q '):format(v, conf[k])
        elseif type(conf[k]) == 'boolean' and conf.stdout == false then
            cmd = unix and cmd..(' %d> /dev/null '):format(v)
                or cmd..(' %d> NUL '):format(v)
        elseif conf[k] ~= nil then
            fmt_err(2, 'string or boolean or nil', 'at '..k)
        end
    end

    -- 执行命令
    return os.execute(cmd)
end

return exec