local util = require('lunax.util')
local logger = require('lunax.logger')
local fmt = util.fmt_type_err
local unix = require('lunax.os_prober') ~= 'NT'
local is_luajit = type(jit) == 'table'

local function join(...)
    local n, args = select('#', ...), { ... }
    if n == 1 and type(args[1]) == 'table' then
        args, n = args[1], #args[1]
    end
    local cmd = ''
    for i = 1, n do
        local arg = args[i]
        if i == 1 then cmd = arg; goto continue end
        cmd = unix and cmd..'; '..arg or cmd..' & '..arg
        :: continue ::
    end
    return cmd
end

local function popen(cmd, conf, mode)
    -- 1. 规范化用户命令
    if type(cmd) == 'table' then
        if not util.is_array(cmd) then
            error(fmt(1, 'popen', 'array or string', 'map'))
        end

        cmd = join(cmd)
    elseif type(cmd) ~= 'string' then
        error(fmt(1, 'popen', 'array or string', type(cmd)))
    end

    cmd = '('..cmd..')'

    local all_cmds = {}
    local has_env = false
    local tmp_exit_file

    if not unix then
        table.insert(all_cmds, 'chcp 65001 > NUL')
    end

    if conf == nil then goto run end

    do  --- [ 预处理命令 ] ---

        -- 当前目录
        if type(conf.cwd) == 'string' then
            if unix then
                table.insert(all_cmds, ('cd %q'):format(conf.cwd))
            else
                table.insert(all_cmds, ('cd /d %s'):format(conf.cwd))
            end
        elseif conf.cwd ~= nil then
            error(fmt(2, 'popen(_, conf.cwd)', 'string', type(conf.cwd)))
        end

        -- 环境变量
        if type(conf.env) == 'table' then
            for k,v in pairs(conf.env) do
                if type(k) ~= 'string' or type(v) ~= 'string' then
                    error(fmt(2, 'popen(_, conf.env)', 'map<string, string>', 'map<T, T>'))
                end

                if unix then
                    table.insert(all_cmds, ('export %s="%s"'):format(k, v))
                else
                    -- 同样引入特殊字符拦截逻辑
                    local need_quotes = v:find('[&|<>"]') ~= nil
                    if need_quotes then
                        error("env value contains special chars, not supported yet")
                    else
                        table.insert(all_cmds, ('set %s=%s'):format(k, v))
                    end
                end
            end
            has_env = true
        elseif conf.env ~= nil then
            error(fmt(2, 'popen(_, conf.env)', 'map<string, string>', type(conf.env)))
        end

        local redirection = ''
        local SET = {
            stdout = 1,
            stderr = 2
        }

        for k,v in pairs(SET) do
            if type(conf[k]) == 'string' then
                redirection = redirection .. (' %d> %q '):format(v, conf[k])
            elseif type(conf[k]) == 'boolean' then
                if not conf[k] then
                    redirection = redirection .. (unix and (' %d> /dev/null '):format(v) or (' %d> NUL '):format(v))
                end

                -- stderr & true -> stdout
                if k == 'stderr' and conf[k] then
                    redirection = redirection .. ' 2>&1 '
                end
            elseif conf[k] ~= nil then
                error(fmt(2, ('popen(_, conf.%s)'):format(k), 'string or boolean or nil', type(conf[k])))
            end
        end

        cmd = cmd .. redirection
    end

    :: run ::

    if not unix and has_env then
        cmd = cmd:gsub('%%(%w+)%%', '!%1!')
    end

    if unix and is_luajit then
        tmp_exit_file = os.tmpname()
        cmd = cmd .. ('; echo $? > %q'):format(tmp_exit_file)
    end

    table.insert(all_cmds, cmd)

    local final_cmd = join(util.unpack(all_cmds))
    if not unix and has_env then
        final_cmd = ('cmd /v:on /c "%s"'):format(final_cmd)
    end

    -- logger.debug('popen', final_cmd)

    local handle = io.popen(final_cmd, mode)
    if not handle then return nil end

    local methods = getmetatable(handle).__index

    local proxy = {}
    for k, v in pairs(methods) do
        if k ~= 'close' then
            proxy[k] = function(_, ...)
                return v(handle, ...)
            end
        end
    end

    proxy.close = function()
        local a, b, c = handle:close()
        local tp = type(a)

        if unix and tmp_exit_file then
            local f = io.open(tmp_exit_file)
            if f then
                local code = tonumber(f:read('*a'))
                f:close()
                os.remove(tmp_exit_file)
                if code then
                    return { ok = code == 0, ext = nil, code = code }
                end
            else
                os.remove(tmp_exit_file)
            end
        end

        if tp == 'number' then
            return { ok = a == 0, ext = nil, code = a }
        elseif tp == 'boolean' then
            if a then
                if b ~= nil then
                    return { ok = true, ext = b, code = c or 0 }
                else
                    return { ok = true, ext = nil, code = 0 }
                end
            else
                return { ok = false, ext = b, code = c or -1 }
            end
        else
            if b ~= nil and c ~= nil then
                return { ok = false, ext = b, code = c }
            else
                return { ok = false, ext = b, code = -1 }
            end
        end
    end

    return proxy
end

return popen