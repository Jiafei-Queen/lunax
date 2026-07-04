local FS = {}

-- 内部 Shell 安全转义函数
local function sh_quote(str)
    return "'" .. string.gsub(str or "", "'", "'\\''") .. "'"
end

--- [ 脚本目录 ] ---
local function src()
    local file = arg[0]:match('[^/]+$')
    local dir = arg[0]:gsub(file..'$', '')
    dir = dir == '' and '.' or dir

    local handle <close> = assert(io.popen(('cd %q && pwd'):format(dir)))
    return handle:read('*l')..'/'..file
end

--- [ 获得工作目录 ] ---
local function cwd()
    local handle <close> = assert(io.popen("pwd"))
    return handle:read("*l")
end

FS.src = src()
FS.cwd = cwd()

--- [ 等同于 `ls -A` ] ---
function FS.ls(path)
    local path = path or "."
    local cmd = string.format("ls -A %s", sh_quote(path))

    local files = {}
    local handle = assert(io.popen(cmd))
    for file in handle:lines() do
        -- 针对 MSYS2
        local file = file:gsub('\r$', '')
        table.insert(files, file)
    end

    local ok, ext, code = handle:close()
    if not ok then
        error({ext = ext, code = code})
    end

    return files
end

--- [ 检测路径 ] ---
function FS.test(path, type)
    local types = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l', ['EXIST'] = 'e',
    }

    return os.execute(('test -%s %s')
        :format((types[type] or sh_quote(type)), sh_quote(path)))
end

--- [ 拼接文件系统路径 ] ---
function FS.join(...)
    local arg = {...}
    local res = table.concat(arg, "/")
    return (res:gsub("/+", "/"))
end

--- [ 等同于 `mkdir -p` ] ---
function FS.mkdir(path)
    return os.execute(string.format("mkdir -p %s", sh_quote(path)))
end

--- [ 等同于 `rm -rf` ] ---
function FS.rm(path)
    if FS.test(path, 'DIR') then
        return os.execute(string.format("rm -rf %s", sh_quote(path)))
    elseif FS.test(path, 'EXIST') then
        return os.remove(path)
    end
end

--- [ 等同于 `cp -r` ] ---
function FS.cp(src, dst)
    if not FS.test(src, 'EXIST') then return false, "Source does not exist" end
    return os.execute(string.format("cp -r %s %s", sh_quote(src), sh_quote(dst)))
end

--- [ 等同于 `mv` ] ---
function FS.mv(src, dst)
    if not FS.test(src, 'EXIST') then return false, "Source does not exist" end
    if not os.rename(src, dst) then
        return os.execute(string.format("mv %s %s", sh_quote(src), sh_quote(dst)))
    end
end

function FS.find(path, name, type)
    local cmd = ('find %s -name %s'):format(sh_quote(path), sh_quote(name))
    local types = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l',
    }

    if type then
        cmd = cmd..' -type '..(types[type] or sh_quote(type))
    end

    local handle = assert(io.popen(cmd))
    local entries = {}
    for entry in handle:lines() do
        local entry = entry:gsub('\r$', '')
        table.insert(entries, entry)
    end

    local ok, ext, code = handle:close()
    if not ok then
        error({ext = ext, code = code})
    end

    return entries
end


--- [ 获取文件/目录的详细属性 (stat) ] ---
function FS.stat(path)
    if not FS.test(path, 'EXIST') then error('Path does not exist') end

    -- 1. 自动检测是 GNU (Linux/MSYS2) 还是 BSD (macOS) 的 stat 命令
    local is_gnu = false
    local handle_v = io.popen("stat --version 2>/dev/null")
    if handle_v then
        local version_out = handle_v:read("*a")
        handle_v:close()
        if version_out and version_out:match("GNU") then
            is_gnu = true
        end
    end

    -- 2. 拼装格式化字符串
    local cmd
    if is_gnu then
        -- GNU stat 格式：%%s=大小, %%Y=时间戳, %%a=权限, %%A=权限字符串(如-rw-r--r--)
        cmd = string.format("stat -c '{size=%%s, mtime=%%Y, perm=\"%%a\", type=\"%%A\"}' %s 2>/dev/null", sh_quote(path))
    else
        -- BSD / macOS stat 格式：%%z=大小, %%m=时间戳, %%Op=权限, %%Sp=权限字符串
        cmd = string.format("stat -f '{size=%%z, mtime=%%m, perm=\"%%Op\", type=\"%%Sp\"}' %s 2>/dev/null", sh_quote(path))
    end

    -- 3. 执行并捕获输出
    local handle = assert(io.popen(cmd))
    local result = handle:read("*a")
    handle:close()

    if not result or result == "" then return nil, "Failed to get stat info" end

    -- 4. 安全地将字符串转换为 Lua Table
    local size, mtime, perm, type_str = result:match("{size=(%d+), mtime=(%d+), perm=\"([^\"]+)\", type=\"([^\"]+)\"}")
    if not size then return nil, "Failed to parse stat output" end
    local info = {
        size = tonumber(size),
        mtime = tonumber(mtime),
        perm = perm,
        type = type_str
    }
        
    -- 5. 统一规整 type 的返回值
    -- 截取权限字符串的第一位（例如 "-rw-r--r--" 截取到 "-"，"drwxr-xr-x" 截取到 "d"）
    local type_char = string.sub(info.type or "", 1, 1)
    local types = {
        ['-'] = 'FILE', ['d'] = 'DIR', ['l'] = 'LINK'
    }

    info.type = types[type_char] or 'OTHER'
    return info
end

return FS
