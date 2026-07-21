local util = require('lunax.util')
local sub = require('lunax.subprocess')
local logger = require('lunax.logger')
local unix = require('lunax.os_prober') ~= 'NT'
local is_luajit = type(jit) == 'table'

local function popen(cmd, conf)
    cmd = sub.normalize_cmd(cmd, 'popen')
    cmd = '('..cmd..')'

    local all_cmds = {}
    local has_env = false
    local tmp_exit_file

    local chcp = sub.chcp_cmd()
    if chcp then table.insert(all_cmds, chcp) end

    if conf ~= nil then
        local cwd_cmd, env_cmds
        cwd_cmd, env_cmds, has_env = sub.process_conf(conf, 'popen')

        if cwd_cmd then table.insert(all_cmds, cwd_cmd) end
        for _, c in ipairs(env_cmds) do table.insert(all_cmds, c) end

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
                if k == 'stderr' and conf[k] then
                    redirection = redirection .. ' 2>&1 '
                end
            elseif conf[k] ~= nil then
                error(fmt(2, ('popen(_, conf.%s)'):format(k), 'string or boolean or nil', type(conf[k])))
            end
        end

        cmd = cmd .. redirection
    end

    if not unix and has_env then
        cmd = cmd:gsub('%%(%w+)%%', '^%%%1^%%')
        cmd = 'cmd /c ' .. cmd
    end

    if unix and is_luajit then
        tmp_exit_file = os.tmpname()
        cmd = cmd .. ('; echo $? > %q'):format(tmp_exit_file)
    end

    table.insert(all_cmds, cmd)

    local final_cmd = sub.join(util.unpack(all_cmds))

    local handle = io.popen(final_cmd, conf.mode)
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
            if type(b) == 'number' then
                return { ok = b == 0, ext = nil, code = b }
            elseif a then
                return { ok = true, ext = b, code = c or 0 }
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
