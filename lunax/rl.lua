local function readline(prompt)
    local prompt = prompt or ''
    local handle = assert(io.popen(
        ([[bash -c 'bind "set disable-completion on"; set -f; read -e -p %q line < /dev/tty && echo $line']]):format(prompt)
    ))

    local line = handle:read('*l')
    local ok, ext, code = handle:close()
    if not ok then
        error({ext = ext, code = code})
    end

    return line
end

return readline
