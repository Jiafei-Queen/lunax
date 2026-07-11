local util = require('lunax.util')
local fmt = util.fmt_type_err

local FS = {}

local lfs =(function()
    local ok, lfs = pcall(require, 'lfs')
    return ok and lfs or nil
end)()

local unix = require('lunax.os_prober') ~= 'NT'

-- POSIX shell quoting
local function sh_quote(str)
    if not str then return "''" end
    return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

-- Windows cmd quoting: double-quote, escape internal double-quotes by doubling
local function win_quote(str)
    return '"' .. tostring(str):gsub('"', '""') .. '"'
end

local function lfs_path(path)
    if unix or not path then return path end
    local p = path:gsub("\\", "/")
    p = p:gsub("^/([%a])/", "%1:/")
    p = p:gsub("^/([%a])$", "%1:/")

    return p
end

--- [ 获得工作目录 ] ---
local function cwd()
    if lfs then return lfs.currentdir() end
    if unix then
        local handle <close> = assert(io.popen("pwd"))
        return handle:read("*l")
    end

    local handle <close> = assert(io.popen("cd"))
    return handle:read("*l"):gsub("[\r\n]+$", "")
end

--- [ 脚本绝对路径 ] ---
local function src()
    local p <const> = arg[0]
    if unix then
        local file <const> = p:match('[^/]+$') or ""
        local dir = p:gsub(file .. '$', '')
        local cd_dir = dir == '' and '.' or dir
        local handle <close> = assert(io.popen(('cd %s && pwd'):format(sh_quote(cd_dir))))
        return handle:read('*l') .. '/' .. file
    end

    -- Windows: resolve arg[0] to absolute path
    if p:match('^[A-Za-z]:') then
        return p:gsub("/", "\\")
    end

    if p:match('^[\\/]') then
        local wd = cwd()
        local drive <const> = wd:match('^([A-Za-z]:)') or "C:"
        return drive .. p:gsub("/", "\\")
    end

    return cwd() .. "\\" .. p:gsub("/", "\\")
end

FS.src = src()
FS.cwd = cwd()

--- [ 等同于 `ls -A` ] ---
function FS.ls(path)
    path = path or "."
    local files = {}

    if lfs and FS.test(path, 'DIR') then
        for entry in lfs.dir(lfs_path(path)) do
            if entry ~= '.' and entry ~= '..' then
                files[#files + 1] = entry
            end
        end

        return files
    end

    local cmd
    if unix then
        cmd = ("ls -A %s"):format(sh_quote(path))
    else
        cmd = ("dir %s /b /a 2>nul"):format(win_quote(path))
    end

    local handle = assert(io.popen(cmd))
    for entry in handle:lines() do
        files[#files + 1] = entry:gsub('\r$', '')
    end

    local ok, ext, code = handle:close()
    if not ok then
        error({ext = ext, code = code})
    end

    return files
end

--- [ 获取文件/目录属性 ]
function FS.stat(path)
    if lfs then
        local attrs, err = lfs.attributes(lfs_path(path))
        if not attrs then return nil, err end

        local modes <const> = {
            ['file'] = 'FILE', ['directory'] = 'DIR', ['link'] = 'LINK'
        }

        return {
            size = attrs.size,
            mtime = attrs.modification,
            perm = attrs.permissions,
            type = modes[attrs.mode] or 'OTHER'
        }
    end

    if unix then
        local is_gnu = false
        local handle_v = io.popen("stat --version 2>/dev/null")
        if handle_v then
            local version_out = handle_v:read("*a")
            handle_v:close()
            if version_out and version_out:match("GNU") then
                is_gnu = true
            end
        end

        local cmd
        if is_gnu then
            cmd = ("stat -c '{size=%%s, mtime=%%Y, perm=\"%%a\", type=\"%%A\"}' %s 2>/dev/null")
                :format(sh_quote(path))
        else
            cmd = ("stat -f '{size=%%z, mtime=%%m, perm=\"%%Op\", type=\"%%Sp\"}' %s 2>/dev/null")
                :format(sh_quote(path))
        end

        local handle = assert(io.popen(cmd))
        local result = handle:read("*a")
        handle:close()

        if not result or result == "" then return nil end

        local size, mtime, perm, type_str =
            result:match("{size=(%d+), mtime=(%d+), perm=\"([^\"]+)\", type=\"([^\"]+)\"}")
        if not size then return nil end

        local info <const> = {
            size = tonumber(size),
            mtime = tonumber(mtime),
            perm = perm,
            type = type_str
        }

        local type_char <const> = info.type:sub(1, 1)
        local types <const> = {
            ['-'] = 'FILE', ['d'] = 'DIR', ['l'] = 'LINK'
        }
        info.type = types[type_char] or 'OTHER'
        return info
    end

    -- Windows without lfs: best-effort stat
    if os.execute(("if exist %s (exit /b 0) else (exit /b 1)")
        :format(win_quote(path .. "\\NUL"))) then

        return { size = 0, mtime = nil, perm = nil, type = "DIR" }
    end

    local f = io.open(path, "rb")
    if f then
        local size <const> = f:seek("end")
        f:close()
        return { size = size, mtime = nil, perm = nil, type = "FILE" }
    end
end

--- [ 检测路径 ]
function FS.test(path, type)
    if lfs then
        local stat = FS.stat(path)
        if not stat then return false end
        if type == 'EXIST' then return true end
        return stat.type == type
    end

    local types <const> = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l', ['EXIST'] = 'e',
    }

    local flag <const> = types[type] or type

    if unix then
        return os.execute(("test -%s %s"):format(flag, sh_quote(path)))
    end

    -- Windows native: use cmd internal commands
    if flag == 'd' then
        return os.execute(("if exist %s (exit /b 0) else (exit /b 1)")
            :format(win_quote(path .. "\\NUL")))
    elseif flag == 'f' then
        -- file: exists but is not a directory
        return os.execute(("if exist %s if not exist %s (exit /b 0) else (exit /b 1)")
            :format(win_quote(path), win_quote(path .. "\\NUL")))
    elseif flag == 'e' then
        return os.execute(("if exist %s (exit /b 0) else (exit /b 1)")
            :format(win_quote(path)))
    elseif flag == 'l' then
        -- check for reparse point (junction / symlink)
        local handle = io.popen(("dir %s /a:l 2>nul"):format(win_quote(path)))
        if not handle then return false end
        local out = handle:read("*a")
        handle:close()
        return out and #out > 0
    end

    return false
end

--- [ 拼接文件系统路径 ]
function FS.join(...)
    local parts <const> = table.pack(...)
    local sep <const> = unix and "/" or "\\"
    local res <const> = table.concat(parts, sep):gsub("[/\\]+", sep)

    if unix then return res end

    -- Preserve UNC path double-backslash prefix
    local first_part <const> = tostring(parts[1] or "")
    if first_part:match("^\\\\") or first_part:match("^//") then
        return "\\" .. res
    end

    return res
end

--- [ 等同于 `mkdir -p` ]
function FS.mkdir(path)
    if lfs then
        if FS.test(path, 'DIR') then return true end

        local accum = ""
        local normalized <const> = path:gsub("\\", "/")

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

    if unix then
        return os.execute(("mkdir -p %s"):format(sh_quote(path)))
    end

    -- Windows: mkdir natively creates intermediate directories
    return os.execute(("mkdir %s 2>nul"):format(win_quote(path)))
end

--- [ 内部辅助：递归删除非空目录 (仅 lfs 路径) ]
local function rec_rmdir(dir_path)
    local native_dir <const> = lfs_path(dir_path)
    for entry in lfs.dir(native_dir) do
        if entry ~= "." and entry ~= ".." then
            local full_path <const> = dir_path .. "/" .. entry
            local mode <const> = lfs.attributes(lfs_path(full_path), "mode")

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

--- [ 等同于 `rm -rf` ]
function FS.rm(path)
    if type(path) ~= 'string' and type(path) ~= 'table' then
        error(fmt(1, 'rm', 'string or array', type(path)))
    end

    -- 统一转换为 table
    local paths = (type(path) == "table") and path or { path }
    if #paths == 0 then return true end

    if not util.is_array(paths) then
        error(fmt(1, 'rm', 'string or array', 'table'))
    end

    if lfs then
        local all_success = true
        for _, p in ipairs(paths) do
            if p and p ~= "" then
                local mode = lfs.attributes(lfs_path(p), "mode")
                if mode then
                    local success = (mode == "directory") and rec_rmdir(p) or os.remove(lfs_path(p))
                    if not success then all_success = false end
                end
            end
        end
        return all_success
    end

    -- 3. Unix：一次性拼接所有路径
    if unix then
        local quoted_paths = {}
        for _, p in ipairs(paths) do
            if p and p ~= "" then
                table.insert(quoted_paths, sh_quote(p))
            end
        end
        if #quoted_paths == 0 then return true end
        -- 结果类似于: rm -rf "file1" "file2" "dir3"
        return os.execute(("rm -rf %s"):format(table.concat(quoted_paths, " ")))
    end

    -- 4. Windows: rd 和 del 分类拼接
    local dirs = {}
    local files = {}
    
    for _, p in ipairs(paths) do
        if p and p ~= "" then
            if FS.test(p, 'DIR') then
                table.insert(dirs, win_quote(p))
            elseif FS.test(p, 'EXIST') then
                table.insert(files, win_quote(p))
            end
        end
    end

    local win_success = true

    -- 一次性删除所有文件夹: rd /s /q "dir1" "dir2"
    if #dirs > 0 then
        local res = os.execute(("rd /s /q %s"):format(table.concat(dirs, " ")))
        if not res then win_success = false end
    end
 
    -- 一次性删除所有文件: del /f /q "file1" "file2"
    if #files > 0 then
        local res = os.execute(("del /f /q %s"):format(table.concat(files, " ")))
        if not res then win_success = false end
    end

    return win_success
end

--- [ 等同于 `cp -r` ]
function FS.cp(src, dst)
    if not FS.test(src, 'EXIST') then
        return false, "Source does not exist"
    end

    if unix then
        return os.execute(("cp -r %s %s"):format(sh_quote(src), sh_quote(dst)))
    end

    -- Windows native
    if FS.test(src, 'DIR') then
        return os.execute(("xcopy %s %s /E /I /Y >nul")
            :format(win_quote(src .. "\\"), win_quote(dst .. "\\")))
    else
        return os.execute(("copy /y %s %s >nul"):format(win_quote(src), win_quote(dst)))
    end
end

--- [ 等同 `mv` ]
function FS.mv(src, dst)
    if not FS.test(src, 'EXIST') then
        return false, "Source does not exist"
    end

    local ok = os.rename(lfs_path(src), lfs_path(dst))
    if ok then return true end

    if unix then
        return os.execute(("mv %s %s"):format(sh_quote(src), sh_quote(dst)))
    end

    -- Windows native: move for files, cp+rm for directories (cross-drive safety)
    if FS.test(src, 'DIR') then
        if FS.cp(src, dst) then
            return FS.rm(src)
        end
        return false
    end

    return os.execute(("move /y %s %s >nul"):format(win_quote(src), win_quote(dst)))
end

--- [ 递归查找文件 ]
function FS.find(path, name, type)
    if unix then
        local clean_path <const> = path:gsub("/+$", "")
        local cmd = ("find %s -name %s"):format(sh_quote(clean_path), sh_quote(name))
        local types <const> = {
            ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l',
        }
        if type then
            cmd = cmd .. " -type " .. (types[type] or sh_quote(type))
        end

        local handle = assert(io.popen(cmd))
        local entries <const> = {}
        for entry in handle:lines() do
            entries[#entries + 1] = entry:gsub('\r$', '')
        end

        local ok, ext, code = handle:close()
        if not ok then
            error({ext = ext, code = code})
        end

        return entries
    end

    -- Windows native: use dir /s /b
    local clean_path <const> = path:gsub("[/\\]+$", "")
    local cmd = ("dir /s /b %s 2>nul"):format(win_quote(clean_path .. "\\" .. name))

    if type == 'FILE' then
        cmd = cmd:gsub(" 2>nul", " /a:-d 2>nul")
    elseif type == 'DIR' then
        cmd = cmd:gsub(" 2>nul", " /a:d 2>nul")
    elseif type == 'LINK' then
        cmd = cmd:gsub(" 2>nul", " /a:l 2>nul")
    end

    local handle = assert(io.popen(cmd))
    local entries <const> = {}
    for entry in handle:lines() do
        entries[#entries + 1] = entry:gsub('\r$', '')
    end

    local ok, ext, code = handle:close()
    if not ok then
        error({ext = ext, code = code})
    end

    return entries
end

return FS
