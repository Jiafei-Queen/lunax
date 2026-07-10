return (function()
    do  -- Windows
        local handle <close> = assert(io.popen('cd'))
        local res = handle:read('*l')
        if res and res:match('^[A-Z]:\\') then
            return 'NT'
        end
    end

    do  -- Unix
        local handle <close> = assert(io.popen('uname -s'))
        return handle:read('*l')
    end
end)()