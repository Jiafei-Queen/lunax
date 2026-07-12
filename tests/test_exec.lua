local exec = require('lunax.exec')
local unix = require('lunax.os_prober') ~= 'NT'
local ansi = require('lunax.ansi')

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