local OS = (function()
    -- Windows
    if string.sub(package.config, 1, 1) == '\\' then
        return "NT"
    end

    -- Unix
    local handle = io.popen('uname -s')
    local os = handle:read('*l'); handle:close()
    return os
end)()

return OS