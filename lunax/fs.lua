local util = require('lunax.util')
local fmt = util.fmt_type_err

local FS = {}

local lfs =(function()
    local ok, lfs = pcall(require, 'lfs')
    return ok and lfs or nil
end)()

local unix = require('lunax.os_prober') ~= 'NT'
local msys = not unix and os.getenv("MSYSTEM") ~= nil

-- Cross-version os.execute wrapper
-- Lua 5.4+: returns (ok, reason, code); LuaJIT/5.1: returns exit_code (number)
local function exec_ok(cmd)
    local ok = os.execute(cmd)
    if type(ok) == "number" then return ok == 0 end
    return not not ok
end

local function close_result(handle)
    local r1, r2, r3 = handle:close()
    if type(r1) == "number" then return r1 == 0, nil, r1 end
    return r1, r2, r3
end

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
    if msys then
        p = p:gsub("^/([%a])/", "%1:/")
        p = p:gsub("^/([%a])$", "%1:/")
    end
    return p
end

--- [ 获得工作目录 ] ---
local function cwd()
    if lfs then return lfs.currentdir() end
    if unix then
        local handle = assert(io.popen("pwd"))
        local result = handle:read("*l")
        handle:close()
        return result
    end

    local handle = assert(io.popen("cd"))
    local result = handle:read("*l"):gsub("[\r\n]+$", "")
    handle:close()
    return result
end

--- [ 脚本绝对路径 ] ---
local function src()
    local p = arg[0]
    if unix then
        local file = p:match('[^/]+$') or ""
        local dir = p:gsub(file .. '$', '')
        local cd_dir = dir == '' and '.' or dir
        local handle = assert(io.popen(('cd %s && pwd'):format(sh_quote(cd_dir))))
        local result = handle:read('*l') .. '/' .. file
        handle:close()
        return result
    end

    -- Windows: resolve arg[0] to absolute path
    if p:match('^[A-Za-z]:') then
        return p:gsub("/", "\\")
    end

    if p:match('^[\\/]') then
        local wd = cwd()
        local drive = wd:match('^([A-Za-z]:)') or "C:"
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

    local ok, ext, code = close_result(handle)
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

        local modes = {
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

        local info = {
            size = tonumber(size),
            mtime = tonumber(mtime),
            perm = perm,
            type = type_str
        }

        local type_char = info.type:sub(1, 1)
        local types = {
            ['-'] = 'FILE', ['d'] = 'DIR', ['l'] = 'LINK'
        }
        info.type = types[type_char] or 'OTHER'
        return info
    end

    -- Windows without lfs: best-effort stat
    if exec_ok(("dir /a:d %s >nul 2>nul"):format(win_quote(path))) then
        return { size = 0, mtime = nil, perm = nil, type = "DIR" }
    end

    local f = io.open(path, "rb")
    if f then
        local size = f:seek("end")
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

    local types = {
        ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l', ['EXIST'] = 'e',
    }

    local flag = types[type] or type

    if unix then
        return exec_ok(("test -%s %s"):format(flag, sh_quote(path)))
    end

    -- Windows native: use cmd internal commands
    if flag == 'd' then
        return exec_ok(("dir /a:d %s >nul 2>nul"):format(win_quote(path)))
    elseif flag == 'f' then
        return exec_ok(("dir /a:-d %s >nul 2>nul"):format(win_quote(path)))
    elseif flag == 'e' then
        return exec_ok(("dir %s >nul 2>nul"):format(win_quote(path)))
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
    local parts = util.pack(...)
    local sep = unix and "/" or "\\"
    local res = table.concat(parts, sep):gsub("[/\\]+", sep)

    if unix then return res end

    -- Preserve UNC path double-backslash prefix
    local first_part = tostring(parts[1] or "")
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

            -- skip drive letter (e.g. "C:") on Windows
            if not (accum:match("^[A-Za-z]:$") or FS.test(accum, 'EXIST')) then
                local ok, err = lfs.mkdir(lfs_path(accum))
                if not ok then return false, err end
            end
        end

        return true
    end

    if unix then
        return exec_ok(("mkdir -p %s"):format(sh_quote(path)))
    end

    -- Windows: mkdir natively creates intermediate directories
    return exec_ok(("mkdir %s 2>nul"):format(win_quote(path)))
end

--- [ 内部辅助：递归删除非空目录 (仅 lfs 路径) ]
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
        return exec_ok(("rm -rf %s"):format(table.concat(quoted_paths, " ")))
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
        if not exec_ok(("rd /s /q %s"):format(table.concat(dirs, " "))) then
            win_success = false
        end
    end
  
    -- 一次性删除所有文件: del /f /q "file1" "file2"
    if #files > 0 then
        if not exec_ok(("del /f /q %s"):format(table.concat(files, " "))) then
            win_success = false
        end
    end

    return win_success
end

--- [ 等同于 `cp -r` ]
function FS.cp(src, dst)
    if not FS.test(src, 'EXIST') then
        return false, "Source does not exist"
    end

    if unix then
        return exec_ok(("cp -r %s %s"):format(sh_quote(src), sh_quote(dst)))
    end

    -- Windows native
    if FS.test(src, 'DIR') then
        return exec_ok(("xcopy %s %s /E /I /Y >nul")
            :format(win_quote(src .. "\\"), win_quote(dst .. "\\")))
    else
        return exec_ok(("copy /y %s %s >nul"):format(win_quote(src), win_quote(dst)))
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
        return exec_ok(("mv %s %s"):format(sh_quote(src), sh_quote(dst)))
    end

    -- Windows native: move for files, cp+rm for directories (cross-drive safety)
    if FS.test(src, 'DIR') then
        if FS.cp(src, dst) then
            return FS.rm(src)
        end
        return false
    end

    return exec_ok(("move /y %s %s >nul"):format(win_quote(src), win_quote(dst)))
end

--- [ 递归查找文件 ]
function FS.find(path, name, type)
    if unix then
        local clean_path = path:gsub("/+$", "")
        local cmd = ("find %s -name %s"):format(sh_quote(clean_path), sh_quote(name))
        local types = {
            ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l',
        }
        if type then
            cmd = cmd .. " -type " .. (types[type] or sh_quote(type))
        end

        local handle = assert(io.popen(cmd))
        local entries = {}
        for entry in handle:lines() do
            entries[#entries + 1] = entry:gsub('\r$', '')
        end

        local ok, ext, code = close_result(handle)
        if not ok then
            error({ext = ext, code = code})
        end

        return entries
    end

    -- Windows native: use dir /s /b
    local clean_path = path:gsub("[/\\]+$", "")
    local cmd = ("dir /s /b %s 2>nul"):format(win_quote(clean_path .. "\\" .. name))

    if type == 'FILE' then
        cmd = cmd:gsub(" 2>nul", " /a:-d 2>nul")
    elseif type == 'DIR' then
        cmd = cmd:gsub(" 2>nul", " /a:d 2>nul")
    elseif type == 'LINK' then
        cmd = cmd:gsub(" 2>nul", " /a:l 2>nul")
    end

    local handle = assert(io.popen(cmd))
    local entries = {}
    for entry in handle:lines() do
        entries[#entries + 1] = entry:gsub('\r$', '')
    end

    local ok, ext, code = close_result(handle)
    if not ok then
        error({ext = ext, code = code})
    end

    return entries
end

return FS
