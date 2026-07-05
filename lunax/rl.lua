local ok, linenoise = pcall(require, 'linenoise')

local function readline(prompt)
    if ok then
        -- linenoise 遇见 SIGINT & EOF -> nil 而不报错
        return linenoise.linenoise(prompt)
    end

    local prompt = prompt or ''
    local handle = assert(io.popen(
        ([[bash -c 'bind "set disable-completion on"; set -f; read -e -p %q line < /dev/tty && echo $line']]):format(prompt)
    ))

    -- 针对 bash readline SIGINT 行为
    local ok, line = pcall(function()
        return handle:read('*l')
    end)

    if not ok then
        print() -- 对齐 linenoise 行为
        handle:close()
        return
    end

    -- 针对 bash readline EOF 行为
    local ok = handle:close()
    if not ok or not line then
        print() -- 对齐 linenoise 行为
        return
    end

    return line
end

return readline
