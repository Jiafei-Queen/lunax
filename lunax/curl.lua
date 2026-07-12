-- local logger = require('lunax.logger')
local popen = require('lunax.popen')
local util = require('lunax.util')
local fmt = util.fmt_type_err

local curl = {}

--- 发送 HTTP 请求
---@param url string URL
---@param req string Request
---@param conf { output: string?, header: string|string[]?, data: string|string[]? }? Config
---@return { ok: true?, ext: string, code: integer }, string|integer? # cURL 退出信息, (HTTP 响应|cURL 错误信息|>= 400 的 HTTP 状态码)
function curl.http(url, req, conf)
    if type(url) ~= 'string' then
        error(fmt(1, 'http', 'string', type(url)))
    end
    if type(req) ~= 'string' then
        error(fmt(2, 'http', 'string', type(req)))
    end

    local cmd = ('curl -sS -f -X %q'):format(req)

    if not conf then
        goto skip
    end

    do
        local function push(flag, key)
            local array = {} 
            if type(conf[key]) == 'string' then
                array = { (' %s %q'):format(flag, conf[key]) }
            elseif type(conf[key]) == 'table' then
                if not util.is_array(conf[key]) then
                    error(fmt(3, ('http(_,_,conf.%s)'):format(key), 'string|array?', 'map'))
                end

                for _,value in ipairs(conf[key]) do
                    table.insert(array, (' %s %q'):format(flag, value))
                end
            end

            cmd = cmd..table.concat(array)
        end

        push('-H', 'header')    -- 请求头
        if req ~= 'GET' then
            push('-d', 'data')  -- 载荷
        end

        --- [ 输出文件 ] ---
        if type(conf.output) == 'string' then
            cmd = cmd..(' -o %q'):format(conf.output)
        elseif type(conf.output) == 'boolean' then
            cmd = conf.output and cmd..' -O ' or cmd
        elseif type(conf.output) ~= 'nil' then
            error(fmt(3, 'http(_,_,conf.output)', 'string|boolean?', type(conf.output)))
        end
    end

    :: skip ::  -- 跳过可选配置

    cmd = ('%s %q'):format(cmd, url)
    -- logger.debug('curl.http', 'cmd: ', cmd)

    local handle = popen(cmd, { stderr = true })
    local output = handle:read('*a')

    local ok, ext, code = handle:close()
    local exit = { ok = ok, ext = ext, code = code }

    -- logger.debug('curl.http', '--> OUTPUT\n\n', output, '\n')

    local res = ok and output
        or code == 22
            and tonumber(output:match('curl: %(%d+%) The requested URL returned error: (%d+)'))
            or output:match('curl: %(%d+%) (.+)')

    -- logger.debug('curl.http', '--> RES\n\n', res, '\n')

    return exit, res
end

return curl