local os = require('lunax.os_prober')

if os == 'NT' then
    os = 'NT (Windows)'
elseif os == 'Darwin' then
    os = 'Darwin (OS X, macOS)'
end

print('OS: '..os)