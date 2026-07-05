local FS = {}
local function get_lfs()
    local ok, lfs = pcall(require, 'lfs')
    return ok and lfs or nil
end

local lfs = get_lfs()
local unix = not os.getenv('USERPROFILE')

-- 跨平台 Shell 安全转义函数
local function sh_quote(str)
    if not str then return "''" end
    if unix then
        -- POSIX 环境：单引号包裹，内部单引号闭合转义
        return "'" .. string.gsub(str, "'", "'\\''") .. "'"
    else
        -- Windows 环境：双引号包裹。因为最终要作为参数传给 sh -c "...",
        -- 内部的 ", \, $, ` 必须加反斜杠转义，防止被 Windows 或 sh 提前解析
        local escaped = string.gsub(str, '(["\\$`])', "\\%1")
        return '"' .. escaped .. '"'
    end
end

-- 将 Windows path -> MSYS2 path
local function same_path(win_path)
    if not win_path then return nil end
    
    -- 1. 匹配开头的 "字母:"（盘符），将其转换为 "/字母" 的小写形式
    local msys2_path = win_path:gsub("^([%a]):", function(drive)
        return "/" .. drive:lower()
    end)
    
    -- 2. 将所有的反斜杠 \ 替换为正斜杠 /
    msys2_path = msys2_path:gsub("\\", "/")
    
    return msys2_path
end

-- 将 Windows 下的 MSYS2 path -> win_path，供原生 lfs 识别
local function lfs_path(path)
    if unix or not path then return path end
    local p = path:gsub("\\", "/")
    p = p:gsub("^/([%a])/", "%1:/")
    p = p:gsub("^/([%a])$", "%1:/")
    return p
end

local function exec(cmd)
    if unix then
        return os.execute(cmd)
    else
        return os.execute(('"sh -c %q"'):format(cmd))
    end
end

local function popen(cmd)
    if unix then
        return io.popen(cmd)
    else
        return io.popen(('"sh -c %q"'):format(cmd))
    end
end

--- [ 脚本目录 ] ---
local function src()
    local path = same_path(arg[0])
    local file = path:match('[^/]+$') or ""
    local dir = path:gsub(file..'$', '')
    dir = dir == '' and '.' or dir

    local handle <close> = assert(popen(('cd %q && pwd'):format(dir)))
    return handle:read('*l')..'/'..file
end

--- [ 获得工作目录 ] ---
local function cwd()
    if lfs then return lfs.currentdir() end
    local handle <close> = assert(popen("pwd"))
    return handle:read("*l")
end

FS.src = src()
FS.cwd = cwd()

--- [ 等同于 `ls -A` ] ---
function FS.ls(path)
    local path = path or "."
    local files = {}

    if lfs and FS.test(path, 'DIR') then
        for entry in lfs.dir(lfs_path(path)) do
            if entry ~= '.' and entry ~= '..' then
                table.insert(files, entry)
            end
        end

        return files
    end

    path = same_path(path)
    local cmd = string.format("ls -A %s", sh_quote(path))
    local handle = assert(popen(cmd))
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
    if lfs then
        local stat = FS.stat(path)
        if not stat then return false end

        if type == 'EXIST' then
            return true
        end

        return stat.type == type
    end

    local types = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l', ['EXIST'] = 'e',
    }

    local ok = exec(('test -%s %s')
        :format((types[type] or type), sh_quote(same_path(path))))

    return ok
end

--- [ 拼接文件系统路径 ] ---
function FS.join(...)
    local arg = {...}
    local res = table.concat(arg, "/")
    return (res:gsub("/+", "/"))
end

--- [ 等同于 `mkdir -p` ] ---
function FS.mkdir(path)
    if lfs then
        if FS.test(path, 'DIR') then return true end
        
        -- 分解路径，逐层创建
        local accum = ""
        local normalized = path:gsub("\\", "/")
        
        if normalized:sub(1, 1) == "/" then
            accum = "/"
        end
        
        for part in normalized:gmatch("[^/]+") do
            if accum == "" or accum == "/" then
                accum = accum .. part
            else
                accum = accum .. "/" .. part
            end
            
            if not FS.test(accum, 'EXIST') then
                local ok, err = lfs.mkdir(lfs_path(accum))
                if not ok then return false, err end
            end
        end
        return true
    end

    local ok = exec(string.format("mkdir -p %s", sh_quote(same_path(path))))
    return (ok == true or ok == 0)
end

--- [ 内部辅助函数：递归删除非空目录 ] ---
local function rec_rmdir(dir_path)
    local native_dir = lfs_path(dir_path)
    for entry in lfs.dir(native_dir) do
        if entry ~= "." and entry ~= ".." then
            local full_path = dir_path .. "/" .. entry
            local mode = lfs.attributes(lfs_path(full_path), "mode")
            
            if mode == "directory" then
                local ok, err = rec_rmdir(full_path)
                if not ok then return false, err end
            else
                local ok, err = os.remove(lfs_path(full_path))
                if not ok then return false, err end
            end
        end
    end

    return lfs.rmdir(native_dir)
end

--- [ 等同于 `rm -rf` ] ---
function FS.rm(path)
    if not path or path == "" then return false end
    
    if lfs then
        local mode = lfs.attributes(lfs_path(path), "mode")
        if not mode then return true end 
        
        if mode == "directory" then
            local ok, err = rec_rmdir(path)
            return ok == true, err
        else
            return os.remove(lfs_path(path))
        end
    end

    if FS.test(path, 'DIR') then
        local ok = exec(string.format("rm -rf %s", sh_quote(same_path(path))))
        return (ok == true or ok == 0)
    elseif FS.test(path, 'EXIST') then
        return os.remove(lfs_path(path))
    end

    return true
end

--- [ 等同于 `cp -r` ] ---
function FS.cp(src, dst)
    if not FS.test(src, 'EXIST') then return false, "Source does not exist" end
    return exec(string.format("cp -r %s %s", sh_quote(same_path(src)), sh_quote(same_path(dst))))
end

--- [ 等同于 `mv` ] ---
function FS.mv(src, dst)
    if not FS.test(src, 'EXIST') then return false, "Source does not exist" end
    if not os.rename(lfs_path(src), lfs_path(dst)) then
        return exec(string.format("mv %s %s", sh_quote(same_path(src)), sh_quote(same_path(dst))))
    end

    return true
end

function FS.find(path, name, type)
    -- 去除末尾可能导致 find 报错的斜杠
    local clean_path = same_path(path):gsub("/+$", "")
    local cmd = ('find %s -name %s'):format(sh_quote(clean_path), sh_quote(name))
    local types = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l',
    }

    if type then
        cmd = cmd..' -type '..(types[type] or sh_quote(type))
    end

    local handle = assert(popen(cmd))
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
    if lfs then
        local attrs, err = lfs.attributes(lfs_path(path))
        if not attrs then return nil, err end

        local modes = {
            ['file'] = 'FILE', ['directory'] = 'DIR', ['link'] = 'LINK'
        }

        return {
            ['size'] = attrs.size,
            ['mtime'] = attrs.modification,
            ['perm'] = attrs.permissions,
            ['type'] = modes[attrs.mode] or 'OTHER'
        }
    end

    local is_gnu = false
    local handle_v = popen("stat --version 2>/dev/null")
    if handle_v then
        local version_out = handle_v:read("*a")
        handle_v:close()
        if version_out and version_out:match("GNU") then
            is_gnu = true
        end
    end

    local cmd
    if is_gnu then
        cmd = string.format("stat -c '{size=%%s, mtime=%%Y, perm=\"%%a\", type=\"%%A\"}' %s 2>/dev/null", sh_quote(same_path(path)))
    else
        cmd = string.format("stat -f '{size=%%z, mtime=%%m, perm=\"%%Op\", type=\"%%Sp\"}' %s 2>/dev/null", sh_quote(same_path(path)))
    end

    local handle = assert(popen(cmd))
    local result = handle:read("*a")
    handle:close()

    if not result or result == "" then return nil, "Failed to get stat info" end

    local size, mtime, perm, type_str = result:match("{size=(%d+), mtime=(%d+), perm=\"([^\"]+)\", type=\"([^\"]+)\"}")
    if not size then return nil, "Failed to parse stat output" end
    local info = {
        size = tonumber(size),
        mtime = tonumber(mtime),
        perm = perm,
        type = type_str
    }
        
    local type_char = string.sub(info.type or "", 1, 1)
    local types = {
        ['-'] = 'FILE', ['d'] = 'DIR', ['l'] = 'LINK'
    }

    info.type = types[type_char] or 'OTHER'
    return info
end

return FS