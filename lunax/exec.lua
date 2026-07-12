local util = require('lunax.util')
local logger = require('lunax.logger')
local fmt = util.fmt_type_err
local unix = require('lunax.os_prober') ~= 'NT'

local function join(...)
    local cmd = ''

    for i,arg in ipairs({...}) do
        if i == 1 then cmd = arg; goto continue end
        local sep = (function()
            if cmd == '' then
                return ''
            end

            if unix then
                return '; '
            else
                return ' & '
            end
        end)()

        cmd = cmd..sep..arg

        :: continue ::
    end

    return cmd
end

local function exec(cmd, conf)
    -- 1. 规范化用户命令
    if type(cmd) == 'table' then
        if not util.is_array(cmd) then
            error(fmt(1, 'exec', 'array or string', 'map'))
        end

        cmd = join(cmd)
    elseif type(cmd) ~= 'string' then
        error(fmt(1, 'exec', 'array or string', type(cmd)))
    end

    cmd = '(' .. cmd .. ')'

    -- 2. 收集前置命令
    local pre_cmds = {}
    local has_env = false

    if conf then
        -- cwd
        if type(conf.cwd) == 'string' then
            if unix then
                table.insert(pre_cmds, ('cd %q'):format(conf.cwd))
            else
                -- 如果路径无空格就不加引号，否则加（可同理判断）
                table.insert(pre_cmds, ('cd /d %s'):format(conf.cwd))
            end
        elseif conf.cwd ~= nil then
            error(fmt(2, 'exec(_, conf.cwd)', 'string', type(conf.cwd)))
        end

        -- env
        if type(conf.env) == 'table' then
            for k, v in pairs(conf.env) do
                if type(k) ~= 'string' or type(v) ~= 'string' then
                    error(fmt(2, 'exec(_, conf.env)', 'map<string, string>', 'map<T, T>'))
                end
                if unix then
                    table.insert(pre_cmds, ('export %s="%s"'):format(k, v))
                else
                    -- 如果值包含 & | < > " 则用引号
                    local need_quotes = v:find('[&|<>"]') ~= nil
                    if need_quotes then
                        error("env value contains special chars, not supported yet")
                    else
                        table.insert(pre_cmds, ('set %s=%s'):format(k, v))
                    end
                end
            end
            has_env = true
        elseif conf.env ~= nil then
            error(fmt(2, 'exec(_, conf.env)', 'map<string, string>', type(conf.env)))
        end
    end

    -- 3. 构建最终命令
    local all_cmds = {}
    if not unix then
        table.insert(all_cmds, 'chcp 65001 > NUL')
        if has_env then
            cmd = cmd:gsub('%%(%w+)%%', '!%1!')   -- %VAR% 转 !VAR!
        end
    end

    for _, c in ipairs(pre_cmds) do
        table.insert(all_cmds, c)
    end
    table.insert(all_cmds, cmd)

    local final_cmd = join(table.unpack(all_cmds))

    if not unix then
        if has_env then
            final_cmd = ('cmd /v:on /c "%s"'):format(final_cmd)
        end
    end

    logger.debug('exec', final_cmd)
    return os.execute(final_cmd)
end

return exec