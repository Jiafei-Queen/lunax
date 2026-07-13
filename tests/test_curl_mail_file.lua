local curl = require('lunax.curl')
local logger = require('lunax.logger')
local ansi = require('lunax.ansi')

local fail_count = 0

local function assert_contain(str, substr, msg)
    if type(str) ~= 'string' or not str:find(substr, 1, true) then
        logger.error('test_curl_mail_file', ('FAIL: %s\n  expected to contain: %s\n  in: %s'):format(msg or '', tostring(substr), tostring(str)))
        fail_count = fail_count + 1
    end
end

local function assert_true(v, msg)
    if not v then
        logger.error('test_curl_mail_file', ('FAIL: %s'):format(msg or 'expected true'))
        fail_count = fail_count + 1
    end
end

---- [ 1. Type checking ] ----
print(ansi.green('\n---- [ curl.file_download type check ] ----'))

do
    local _, err = pcall(curl.file_download, 123)
    assert_contain(err, "to 'file_download'", 'file_download type check #1')

    _, err = pcall(curl.file_download, 'ftp://x', 42)
    assert_contain(err, "to 'file_download'", 'file_download type check #2')
end

print(ansi.green('\n---- [ curl.file_upload type check ] ----'))

do
    local _, err = pcall(curl.file_upload, 123)
    assert_contain(err, "to 'file_upload'", 'file_upload type check #1')

    _, err = pcall(curl.file_upload, 'ftp://x', nil)
    assert_contain(err, "to 'file_upload'", 'file_upload type check #2')

    _, err = pcall(curl.file_upload, 'ftp://x', {})
    assert_contain(err, "to 'file_upload(_,conf.input)'", 'file_upload type check #3')
end

print(ansi.green('\n---- [ curl.mail_send type check ] ----'))

do
    local _, err = pcall(curl.mail_send, 'oops')
    assert_contain(err, "to 'mail_send'", 'mail_send type check #1')

    _, err = pcall(curl.mail_send, { from = 'x', to = 'y', subject = 's', body = 'b' })
    assert_contain(err, "to 'mail_send(_,conf.server)'", 'mail_send type check #2')

    _, err = pcall(curl.mail_send, { server = 's', to = 'y', subject = 's', body = 'b' })
    assert_contain(err, "to 'mail_send(_,conf.from)'", 'mail_send type check #3')

    _, err = pcall(curl.mail_send, { server = 's', from = 'x', subject = 's', body = 'b' })
    assert_contain(err, "to 'mail_send(_,conf.to)'", 'mail_send type check #4')
end

print(ansi.green('\n---- [ curl.mail_receive type check ] ----'))

do
    local _, err = pcall(curl.mail_receive, 'oops')
    assert_contain(err, "to 'mail_receive'", 'mail_receive type check #1')

    _, err = pcall(curl.mail_receive, { user = 'u', password = 'p' })
    assert_contain(err, "to 'mail_receive(_,conf.server)'", 'mail_receive type check #2')

    _, err = pcall(curl.mail_receive, { server = 's', password = 'p' })
    assert_contain(err, "to 'mail_receive(_,conf.user)'", 'mail_receive type check #3')

    _, err = pcall(curl.mail_receive, { server = 's', user = 'u' })
    assert_contain(err, "to 'mail_receive(_,conf.password)'", 'mail_receive type check #4')

    _, err = pcall(curl.mail_receive, { server = 's', user = 'u', password = 'p', protocol = 'xyz' })
    assert_contain(err, "to 'mail_receive(_,conf.protocol)'", 'mail_receive type check #5')
end

---- [ Summary ] ----
print(ansi.green('\n---- [ Summary ] ----'))
if fail_count > 0 then
    logger.error('test_curl_mail_file', ('%d test(s) FAILED'):format(fail_count))
    os.exit(1)
else
    logger.info('test_curl_mail_file', 'All tests passed!')
end
