local fs = require('lunax.fs')

for _,file in ipairs(fs.ls('tests')) do
    local ok, ext, code = os.execute(('%s %q'):format(arg[-1], fs.join('tests', file)))
    if not ok then
        io.stderr:write(('batch_test: { ext: %s, code: %d }\n'):format(ext, code))
        os.exit(1)
    end
end