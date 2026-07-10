local exec = require('../lunax/exec')

exec('ls && echo $VAR', {
    cwd = 'tests/',
    env = { VAR = 'TEST' },
    stdout = false
})