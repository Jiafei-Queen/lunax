-- local logger = require('lunax.logger')
local base64 = require('lunax.base64')
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

    local exit = handle:close()

    -- logger.debug('curl.http', '--> OUTPUT\n\n', output, '\n')

    local res = exit.ok and output
        or exit.code == 22
            and tonumber(output:match('curl: %(%d+%) The requested URL returned error: (%d+)'))
            or output:match('curl: %(%d+%) (.+)')

    -- logger.debug('curl.http', '--> RES\n\n', res, '\n')

    return exit, res
end

-- ====================================================================
--  内部工具函数
-- ====================================================================

local function _exec(cmd)
    local handle = popen(cmd, { stderr = true })
    local output = handle:read('*a')
    local exit = handle:close()
    local err = output:match('curl: %(%d+)%s(.+)')
    return exit, exit.ok and output or err or output
end

local function _rfc2822_date()
    return os.date('!%a, %d %b %Y %H:%M:%S +0000')
end

local function _addr_list(value)
    if type(value) == 'string' then return value end
    if type(value) == 'table' then
        return table.concat(value, ', ')
    end
    return ''
end

--- 构建 RFC 2822 邮件内容
local function _build_email(conf)
    local boundary = '=_lunax_' .. tostring(os.time()) .. tostring({}):sub(8)
    local lines = {}

    local function add(v) lines[#lines+1] = v end

    add('From: ' .. conf.from)
    add('To: ' .. _addr_list(conf.to))

    if conf.cc then
        add('Cc: ' .. _addr_list(conf.cc))
    end

    add('Subject: ' .. (conf.subject or ''))
    add('Date: ' .. _rfc2822_date())
    add('MIME-Version: 1.0')

    local attaches = {}
    if type(conf.attachment) == 'string' then
        attaches = { conf.attachment }
    elseif type(conf.attachment) == 'table' and util.is_array(conf.attachment) then
        attaches = conf.attachment
    end

    if #attaches > 0 then
        add('Content-Type: multipart/mixed; boundary="' .. boundary .. '"')
        add('')
        add('--' .. boundary)
        add('Content-Type: text/plain; charset="utf-8"')
        add('Content-Transfer-Encoding: 7bit')
        add('')
        add(conf.body or '')

        for _, file in ipairs(attaches) do
            local f = io.open(file, 'rb')
            if f then
                local content = f:read('*a')
                f:close()
                local name = file:match('[^/\\]+$') or file
                add('')
                add('--' .. boundary)
                add('Content-Type: application/octet-stream; name="' .. name .. '"')
                add('Content-Disposition: attachment; filename="' .. name .. '"')
                add('Content-Transfer-Encoding: base64')
                add('')
                local encoded = base64.encode_str(content)
                for i = 1, #encoded, 76 do
                    add(encoded:sub(i, i + 75))
                end
            end
        end

        add('')
        add('--' .. boundary .. '--')
    else
        add('Content-Type: text/plain; charset="utf-8"')
        add('Content-Transfer-Encoding: 7bit')
        add('')
        add(conf.body or '')
    end

    return table.concat(lines, '\r\n')
end

-- ====================================================================
--  文件传输：FTP(S) / SFTP / SCP
-- ====================================================================

--- 下载文件
---@param url string  协议 URL，支持 ftp:// ftps:// sftp:// scp://
---@param conf { output: string?, user: string?, password: string?, port: number?, insecure: boolean?, resume: boolean?, speed_limit: number?, timeout: number?, ssl_cert: string?, ssl_key: string?, ssh_key: string?, ssh_pub_key: string?, progress: boolean? }?
---@return { ok: true?, ext: string, code: integer }, string?
function curl.file_download(url, conf)
    if type(url) ~= 'string' then
        error(fmt(1, 'file_download', 'string', type(url)))
    end
    if conf ~= nil and type(conf) ~= 'table' then
        error(fmt(2, 'file_download', 'table?', type(conf)))
    end

    local args = { 'curl -sS' }

    if conf then
        if conf.user then
            local auth = conf.password
                and ('%q:%q'):format(conf.user, conf.password)
                or ('%q'):format(conf.user)
            args[#args+1] = ('-u %s'):format(auth)
        end
        if conf.port then args[#args+1] = ('--port %d'):format(conf.port) end
        if conf.insecure then args[#args+1] = '-k' end
        if conf.timeout then args[#args+1] = ('--connect-timeout %d'):format(conf.timeout) end
        if conf.speed_limit then args[#args+1] = ('--limit-rate %dk'):format(conf.speed_limit) end
        if conf.resume then args[#args+1] = '-C -' end
        if conf.ssl_cert then args[#args+1] = ('--cert %q'):format(conf.ssl_cert) end
        if conf.ssl_key then args[#args+1] = ('--key %q'):format(conf.ssl_key) end
        if conf.ssh_key then args[#args+1] = ('--key %q'):format(conf.ssh_key) end
        if conf.ssh_pub_key then args[#args+1] = ('--pubkey %q'):format(conf.ssh_pub_key) end
        if conf.progress then args[#args+1] = '--progress-bar' end
        if conf.output then
            args[#args+1] = ('-o %q'):format(conf.output)
        end
    end

    args[#args+1] = ('%q'):format(url)
    return _exec(table.concat(args, ' '))
end

--- 上传文件
---@param url string  目标 URL，支持 ftp:// ftps:// sftp:// scp://
---@param conf { input: string, user: string?, password: string?, port: number?, insecure: boolean?, speed_limit: number?, timeout: number?, ssl_cert: string?, ssl_key: string?, ssh_key: string?, ssh_pub_key: string?, rename: string?, progress: boolean? }
---@return { ok: true?, ext: string, code: integer }, string?
function curl.file_upload(url, conf)
    if type(url) ~= 'string' then
        error(fmt(1, 'file_upload', 'string', type(url)))
    end
    if type(conf) ~= 'table' then
        error(fmt(2, 'file_upload', 'table', type(conf)))
    end
    if type(conf.input) ~= 'string' then
        error(fmt(2, 'file_upload(_,conf.input)', 'string', type(conf.input)))
    end

    local args = { ('curl -sS -T %q'):format(conf.input) }

    if conf.user then
        local auth = conf.password
            and ('%q:%q'):format(conf.user, conf.password)
            or ('%q'):format(conf.user)
        args[#args+1] = ('-u %s'):format(auth)
    end
    if conf.port then args[#args+1] = ('--port %d'):format(conf.port) end
    if conf.insecure then args[#args+1] = '-k' end
    if conf.timeout then args[#args+1] = ('--connect-timeout %d'):format(conf.timeout) end
    if conf.speed_limit then args[#args+1] = ('--limit-rate %dk'):format(conf.speed_limit) end
    if conf.ssl_cert then args[#args+1] = ('--cert %q'):format(conf.ssl_cert) end
    if conf.ssl_key then args[#args+1] = ('--key %q'):format(conf.ssl_key) end
    if conf.ssh_key then args[#args+1] = ('--key %q'):format(conf.ssh_key) end
    if conf.ssh_pub_key then args[#args+1] = ('--pubkey %q'):format(conf.ssh_pub_key) end
    if conf.progress then args[#args+1] = '--progress-bar' end

    args[#args+1] = ('%q'):format(url)
    return _exec(table.concat(args, ' '))
end

-- ====================================================================
--  邮件发送：SMTP / SMTPS
-- ====================================================================

--- 发送邮件
---@param conf { server: string, port: number?, user: string?, password: string?, from: string, to: string|string[], cc: string|string[]?, bcc: string|string[]?, subject: string, body: string, attachment: string|string[]?, insecure: boolean?, starttls: boolean?, timeout: number? }
---@return { ok: true?, ext: string, code: integer }, string?
function curl.mail_send(conf)
    if type(conf) ~= 'table' then
        error(fmt(1, 'mail_send', 'table', type(conf)))
    end

    local server = conf.server
    if type(server) ~= 'string' then
        error(fmt(1, 'mail_send(_,conf.server)', 'string', type(server)))
    end
    if type(conf.from) ~= 'string' then
        error(fmt(1, 'mail_send(_,conf.from)', 'string', type(conf.from)))
    end
    if not conf.to then
        error(fmt(1, 'mail_send(_,conf.to)', 'string|array', 'nil'))
    end

    -- 生成邮件内容
    local email = _build_email(conf)
    local tmp = os.tmpname()
    local f = io.open(tmp, 'wb')
    if not f then
        error('mail_send: failed to create temp file')
    end
    f:write(email)
    f:close()

    -- 构建 curl 命令
    local scheme = conf.starttls and 'smtp' or (conf.port == 465 and 'smtps' or 'smtp')
    local args = {
        ('curl -sS --mail-from %q --upload-file %q'):format(conf.from, tmp),
    }

    if conf.starttls then
        args[#args+1] = '--starttls'
    end
    if conf.user then
        local auth = conf.password
            and ('%q:%q'):format(conf.user, conf.password)
            or ('%q'):format(conf.user)
        args[#args+1] = ('-u %s'):format(auth)
    end

    -- 收件人
    local function add_rcpt(value)
        if type(value) == 'string' then
            args[#args+1] = ('--mail-rcpt %q'):format(value)
        elseif type(value) == 'table' then
            for _, v in ipairs(value) do
                args[#args+1] = ('--mail-rcpt %q'):format(v)
            end
        end
    end

    add_rcpt(conf.to)
    if conf.cc then add_rcpt(conf.cc) end
    if conf.bcc then add_rcpt(conf.bcc) end

    if conf.insecure then args[#args+1] = '-k' end
    if conf.timeout then args[#args+1] = ('--connect-timeout %d'):format(conf.timeout) end
    args[#args+1] = '--crlf'

    local p = conf.port
    local url = p and ('%s://%s:%d'):format(scheme, server, p)
        or ('%s://%s'):format(scheme, server)
    args[#args+1] = ('%q'):format(url)

    local exit, res = _exec(table.concat(args, ' '))
    os.remove(tmp)
    return exit, res
end

-- ====================================================================
--  邮件接收：POP3 / IMAP
-- ====================================================================

--- 接收邮件
---@param conf { server: string, port: number?, user: string, password: string, protocol: ('pop3'|'imap')?, ssl: boolean?, insecure: boolean?, mailbox: string?, uid: string|number?, count: number?, timeout: number? }
---@return { ok: true?, ext: string, code: integer }, string?
function curl.mail_receive(conf)
    if type(conf) ~= 'table' then
        error(fmt(1, 'mail_receive', 'table', type(conf)))
    end
    if type(conf.server) ~= 'string' then
        error(fmt(1, 'mail_receive(_,conf.server)', 'string', type(conf.server)))
    end
    if type(conf.user) ~= 'string' then
        error(fmt(1, 'mail_receive(_,conf.user)', 'string', type(conf.user)))
    end
    if type(conf.password) ~= 'string' then
        error(fmt(1, 'mail_receive(_,conf.password)', 'string', type(conf.password)))
    end

    local proto = conf.protocol or 'pop3'
    if proto ~= 'pop3' and proto ~= 'imap' then
        error(fmt(1, 'mail_receive(_,conf.protocol)', '"pop3"|"imap"', type(conf.protocol)))
    end

    local ssl = conf.ssl
    if ssl == nil and conf.port then
        ssl = conf.port == 995 or conf.port == 993
    end

    local scheme = proto
    if ssl then
        scheme = proto == 'pop3' and 'pop3s' or 'imaps'
    end

    local port = conf.port
    if not port then
        port = (scheme == 'pop3s' or scheme == 'imaps') and (proto == 'pop3' and 995 or 993)
            or (proto == 'pop3' and 110 or 143)
    end

    local url
    if proto == 'pop3' then
        url = conf.uid
            and ('%s://%s:%d/%s'):format(scheme, conf.server, port, tostring(conf.uid))
            or ('%s://%s:%d'):format(scheme, conf.server, port)
    else
        local mailbox = conf.mailbox or 'INBOX'
        url = conf.uid
            and ('%s://%s:%d/%s;UID=%s'):format(scheme, conf.server, port, mailbox, tostring(conf.uid))
            or ('%s://%s:%d/%s'):format(scheme, conf.server, port, mailbox)
    end

    local args = { ('curl -sS -u %q:%q'):format(conf.user, conf.password) }

    if conf.insecure then args[#args+1] = '-k' end
    if conf.timeout then args[#args+1] = ('--connect-timeout %d'):format(conf.timeout) end

    args[#args+1] = ('%q'):format(url)
    return _exec(table.concat(args, ' '))
end

return curl
