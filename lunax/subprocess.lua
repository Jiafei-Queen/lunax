local util = require('lunax.util')
local fmt = util.fmt_type_err
local unix = require('lunax.os_prober') ~= 'NT'

---@class lunax.subprocess
local M = {}

--- Join multiple command parts with OS-appropriate separator
---@vararg string
---@return string
function M.join(...)
    local n, args = select('#', ...), { ... }
    if n == 1 and type(args[1]) == 'table' then
        args, n = args[1], #args[1]
    end
    local cmd = ''
    for i = 1, n do
        local arg = args[i]
        if i == 1 then cmd = arg; goto continue end
        local sep = cmd == '' and '' or (unix and '; ' or ' & ')
        cmd = cmd .. sep .. arg
        :: continue ::
    end
    return cmd
end

--- Normalize cmd parameter: table → joined string, else validate string
---@param cmd string|string[]
---@param fn_name string
---@return string
function M.normalize_cmd(cmd, fn_name)
    if type(cmd) == 'table' then
        if not util.is_array(cmd) then
            error(fmt(1, fn_name, 'string|array', 'map'))
        end
        return M.join(cmd)
    elseif type(cmd) ~= 'string' then
        error(fmt(1, fn_name, 'string|array', type(cmd)))
    end
    return cmd
end

--- Return chcp command for Windows, nil on Unix
---@return string?
function M.chcp_cmd()
    if not unix then
        return 'chcp 65001 > NUL'
    end
end

--- Process cwd and env from conf.
---@param conf { cwd: string?, env: table<string, string>? }
---@param fn_name string
---@return string? cwd_cmd
---@return string[] env_cmds
---@return boolean has_env
function M.process_conf(conf, fn_name)
    local cwd_cmd
    local env_cmds = {}
    local has_env = false

    if conf.cwd ~= nil then
        if type(conf.cwd) == 'string' then
            cwd_cmd = unix and ('cd %q'):format(conf.cwd) or ('cd /d %s'):format(conf.cwd)
        else
            error(fmt(2, fn_name..'(_, conf.cwd)', 'string', type(conf.cwd)))
        end
    end

    if conf.env ~= nil then
        if type(conf.env) == 'table' then
            for k, v in pairs(conf.env) do
                if type(k) ~= 'string' or type(v) ~= 'string' then
                    error(fmt(2, fn_name..'(_, conf.env)', 'map<string, string>', 'map<T, T>'))
                end
                if unix then
                    table.insert(env_cmds, ('export %s="%s"'):format(k, v))
                else
                    if v:find('[&|<>"]') then
                        error("env value contains special chars, not supported yet")
                    end
                    table.insert(env_cmds, ('set %s=%s'):format(k, v))
                end
            end
            has_env = true
        else
            error(fmt(2, fn_name..'(_, conf.env)', 'map<string, string>', type(conf.env)))
        end
    end

    return cwd_cmd, env_cmds, has_env
end

return M
