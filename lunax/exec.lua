local util = require('lunax.util')
local fmt = util.fmt_type_err
local sub = require('lunax.subprocess')
local unix = require('lunax.os_prober') ~= 'NT'

local function exec(cmd, conf)
    cmd = sub.normalize_cmd(cmd, 'exec')
    cmd = '(' .. cmd .. ')'

    local all_cmds = {}
    local has_env = false

    local chcp = sub.chcp_cmd()
    if chcp then table.insert(all_cmds, chcp) end

    if conf ~= nil then
        local cwd_cmd, env_cmds
        cwd_cmd, env_cmds, has_env = sub.process_conf(conf, 'exec')

        if cwd_cmd then table.insert(all_cmds, cwd_cmd) end
        for _, c in ipairs(env_cmds) do table.insert(all_cmds, c) end

        if conf.stdin ~= nil then
            local tp = type(conf.stdin)
            if tp == 'string' then
                cmd = cmd .. (' < %q '):format(conf.stdin)
            elseif tp ~= 'boolean' then
                error(fmt(2, "exec(_, conf.stdin)", 'string or boolean or nil', tp))
            elseif not conf.stdin then
                cmd = cmd .. (unix and ' < /dev/null ' or ' < NUL ')
            end
        end
    end

    if not unix and has_env then
        cmd = cmd:gsub('%%(%w+)%%', '^%%%1^%%')
        cmd = 'cmd /c ' .. cmd
    end

    table.insert(all_cmds, cmd)

    local final_cmd = sub.join(util.unpack(all_cmds))

    local a, b, c = os.execute(final_cmd)
    if type(a) == 'number' then
        return { ok = a == 0, ext = nil, code = a }
    elseif b ~= nil then
        return { ok = not not a, ext = b, code = c }
    else
        return { ok = not not a, ext = nil, code = a and 0 or 1 }
    end
end

return exec
