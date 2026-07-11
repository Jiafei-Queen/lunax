local OS = (function()
    -- Windows
    if string.sub(package.config, 1, 1) == '\\' then
        return "NT"
    end

    -- Unix
    local handle <close> = assert(io.popen('uname -s'))
    return handle:read('*l')
end)()

return OS