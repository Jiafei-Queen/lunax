local fs = require('lunax.fs')

local TEST = {
    'C:', 'C:/', 'C:\\', 'C:\\base', 'C:/base',
    '/', '/base',
    '~', '~/', '~\\', '~/base', '~\\base',
}

print('Path\t', 'Basename', 'Dirname')
for _,path in ipairs(TEST) do
    print(path, '', fs.basename(path), '', fs.dirname(path))
end