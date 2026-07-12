local rl = require('lunax.rl')

print('---- [ Readline Test ] ----')
print(' (Please type some words)')

local line = rl('> ')
if not line then
    io.stderr:write('test_rl: got nil\n')
    os.exit(1)
end

print('YOU TYPED: '..line)