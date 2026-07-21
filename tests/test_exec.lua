local exec = require('lunax.exec')
local unix = require('lunax.os_prober') ~= 'NT'
local ansi = require('lunax.ansi')
local logger = require('lunax.logger')

do  -- 切换目录测试
    print(ansi.green('\n---- [ Change Directory Test ] ----'))
    local home = unix and os.getenv('HOME')
        or os.getenv('USERPROFILE')

    local cmd = unix and 'pwd' or 'cd'

    io.write(('`%s` at `%s`: '):format(cmd, home))
    exec(cmd, { cwd = home })
end

do  -- 环境变量测试
    print(ansi.green('\n---- [ ENV Test ] ----'))
    local cmd = unix and 'echo $VAR' or 'echo %VAR%'
    exec(cmd, {
        env = { VAR = 'ENV TEST' }
    })
end

do  -- stdin 重定向测试
    print(ansi.green('\n---- [ Stdin Redirect Test ] ----'))
    local tmpfile = os.tmpname()
    local f = io.open(tmpfile, 'w')
    f:write('hello exec stdin')
    f:close()

    local cmd = unix and 'grep -q "hello exec stdin"' or 'find "hello exec stdin"'
    local r = exec(cmd, { stdin = tmpfile })
    if r.ok then
        logger.info('stdin', '\t..OK')
    else
        logger.error('stdin', ('stdin redirect failed: code=%d'):format(r.code))
    end
    os.remove(tmpfile)
end