local archive = require('lunax.archive')
local fs = require('lunax.fs')
local ansi = require('lunax.ansi')
local logger = require('lunax.logger')

local function zip(src, dst)
    local ok, err = archive.zip(src, dst)
    if not ok then
        logger.error('zip', ('compress err: %s'):format(err))
    end

    if not fs.test('foo.zip', 'FILE') then
        logger.error('zip', ('compress-output err: `%s` not found'):format(src))
    end

    return ok
end

print(ansi.green('---- [ ZIP Compress Test ] ----'))

--- 创建测试文件/目录
logger.info('create', 'test[create]: two files, one directory')
io.open('foo', 'w')
io.open('bar', 'w')
fs.mkdir('baz')

---- [ 1. 压缩测试（应正常压缩） ] ----
print(ansi.green('\n--> 1. Compress `foo`, `bar`, `baz` -> `foo.zip`'))
if zip({'foo', 'bar', 'baz'}, 'foo.zip') then
    logger.info('compress-test', '\t..OK')
else
    os.exit(1)
end

---- [ 2. 覆盖测试（应正常覆盖） ] ----
print(ansi.green('\n--> 2. Overwrite `foo.zip`'))
if zip('foo') then
    logger.info('compress-test', '\t..OK')
else
    os.exit(1)
end

---- [ 3. 异常测试（应正常返回错误） ]
print(ansi.green('\n--> 3. Error Test - file not found'))
local ok, err = archive.zip('none')
if ok then
    logger.error('err-test', 'should err but ok')
    os.exit(1)
else
    logger.info('err-test', 'expected-behav(err): '..ansi.red(err))
end

-- 删除测试文件
fs.rm({'foo', 'bar', 'baz', 'foo.zip'})