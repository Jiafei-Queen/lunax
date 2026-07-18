local fs = require('lunax.fs')
local unix = require('lunax.os_prober') ~= 'NT'

for _,file in ipairs(fs.ls('tests')) do
    local template = unix and '%s %q' or '"%q %q"'
    local ok, ext, code = os.execute((template):format(arg[-1], fs.join('tests', file)))
    if not ok then
        io.stderr:write(('batch_test: { ext: %s, code: %d }\n'):format(ext, code))
        os.exit(1)
    end
end