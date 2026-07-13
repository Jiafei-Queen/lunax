local b64 = require('lunax.base64')
local logger = require('lunax.logger')
local ansi = require('lunax.ansi')

local fail_count = 0

local function assert_eq(got, expected, msg)
    if got ~= expected then
        logger.error('test_base64', ('FAIL: %s\n  expected: %s\n  got:      %s'):format(msg or '', tostring(expected), tostring(got)))
        fail_count = fail_count + 1
    end
end

local function assert_true(v, msg)
    if not v then
        logger.error('test_base64', ('FAIL: %s'):format(msg or 'expected true'))
        fail_count = fail_count + 1
    end
end

---- [ 1. encode_str 标准向量 ] ----
print(ansi.green('\n---- [ encode_str vectors ] ----'))

do
    local vectors = {
        { '', '' },
        { 'f', 'Zg==' },
        { 'fo', 'Zm8=' },
        { 'foo', 'Zm9v' },
        { 'foob', 'Zm9vYg==' },
        { 'fooba', 'Zm9vYmE=' },
        { 'foobar', 'Zm9vYmFy' },
        { 'hello', 'aGVsbG8=' },
    }
    for _, v in ipairs(vectors) do
        assert_eq(b64.encode_str(v[1]), v[2], ('encode_str(%q)'):format(v[1]))
    end
end

---- [ 2. decode_str 标准向量 ] ----
print(ansi.green('\n---- [ decode_str vectors ] ----'))

do
    local vectors = {
        { '', '' },
        { 'Zg==', 'f' },
        { 'Zm8=', 'fo' },
        { 'Zm9v', 'foo' },
        { 'Zm9vYg==', 'foob' },
        { 'Zm9vYmE=', 'fooba' },
        { 'Zm9vYmFy', 'foobar' },
        { 'aGVsbG8=', 'hello' },
    }
    for _, v in ipairs(vectors) do
        assert_eq(b64.decode_str(v[1]), v[2], ('decode_str(%q)'):format(v[1]))
    end
end

---- [ 3. 编解码往返 ] ----
print(ansi.green('\n---- [ roundtrip ] ----'))

do
    local payloads = {
        '',
        'f',
        'fo',
        'foo',
        'foob',
        'fooba',
        'foobar',
        'hello world',
        'hello\nworld',
        '\0\1\2\255\254\253',
        string.char(0, 0, 0),
        string.char(0, 0),
        string.char(0),
        string.rep('A', 1000),
        '中文测试 🇺🇳',
    }
    for _, s in ipairs(payloads) do
        local enc = b64.encode_str(s)
        local dec = b64.decode_str(enc)
        if dec ~= s then
            logger.error('test_base64', ('FAIL roundtrip: %d bytes -> enc %d -> dec %d'):format(#s, #enc, #dec))
            fail_count = fail_count + 1
        end
    end
end

---- [ 4. decode_str 空白容忍 ] ----
print(ansi.green('\n---- [ decode_str whitespace tolerance ] ----'))

do
    local dec = b64.decode_str('a G V s\nb\tG 8=')
    assert_eq(dec, 'hello', 'decode_str with whitespace')
end

---- [ 5. 与系统 base64 命令一致性 ] ----
print(ansi.green('\n---- [ system base64 consistency ] ----'))

do
    local handle = io.popen('printf "hello\\nworld" | base64')
    local sys_enc = handle:read('*a'):gsub('%s', '')
    handle:close()
    local lua_enc = b64.encode_str('hello\nworld')
    assert_eq(lua_enc, sys_enc, 'system vs lua encode_str')
end

---- [ 6. 文件编解码 ] ----
print(ansi.green('\n---- [ file encode/decode ] ----'))

do
    local tmp_in  = os.tmpname()
    local tmp_b64 = os.tmpname()
    local tmp_out = os.tmpname()

    local data = 'File test \0\255 data\n中文'

    local f = io.open(tmp_in, 'wb')
    f:write(data)
    f:close()

    local ok, err = b64.encode_file(tmp_in, tmp_b64)
    assert_true(ok, ('encode_file: %s'):format(tostring(err)))

    ok, err = b64.decode_file(tmp_b64, tmp_out)
    assert_true(ok, ('decode_file: %s'):format(tostring(err)))

    local f_in  = io.open(tmp_in, 'rb')
    local f_out = io.open(tmp_out, 'rb')
    local orig  = f_in:read('*a')
    local dec   = f_out:read('*a')
    f_in:close()
    f_out:close()

    assert_eq(dec, orig, 'file roundtrip')

    os.remove(tmp_in)
    os.remove(tmp_b64)
    os.remove(tmp_out)
end

---- [ 7. 类型检查 ] ----
print(ansi.green('\n---- [ type checking ] ----'))

do
    local ok, err = pcall(b64.encode_str, 123)
    assert_true(err and err:find('encode_str'), 'encode_str type check')

    ok, err = pcall(b64.decode_str, 456)
    assert_true(err and err:find('decode_str'), 'decode_str type check')

    ok, err = pcall(b64.encode_file, 123, 'out')
    assert_true(err and err:find('encode_file'), 'encode_file type check #1')

    ok, err = pcall(b64.encode_file, 'in', 456)
    assert_true(err and err:find('encode_file'), 'encode_file type check #2')

    ok, err = pcall(b64.decode_file, 123, 'out')
    assert_true(err and err:find('decode_file'), 'decode_file type check #1')

    ok, err = pcall(b64.decode_file, 'in', 456)
    assert_true(err and err:find('decode_file'), 'decode_file type check #2')
end

---- [ Summary ] ----
print(ansi.green('\n---- [ Summary ] ----'))
if fail_count > 0 then
    logger.error('test_base64', ('%d test(s) FAILED'):format(fail_count))
    os.exit(1)
else
    logger.info('test_base64', 'All tests passed!')
end
