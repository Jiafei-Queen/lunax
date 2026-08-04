local util = require('lunax.util')
local fmt = util.fmt_type_err

---@class lunax.fs
local FS = {}

local lfs =(function()
    local ok, lfs = pcall(require, 'lfs')
    return ok and lfs or nil
end)()

local unix = require('lunax.os_prober') ~= 'NT'
local msys = not unix and os.getenv("MSYSTEM") ~= nil

-- Cross-version os.execute wrapper
-- Lua 5.4+: returns (ok, reason, code); LuaJIT/5.1: returns exit_code (number)
---@param cmd string
---@return boolean
local function exec_ok(cmd)
    local ok = os.execute(cmd)
    if type(ok) == "number" then return ok == 0 end
    return not not ok
end

---@param handle userdata 命令管道句柄
---@return boolean ok
---@return string? ext
---@return integer? code
local function close_result(handle)
    local r1, r2, r3 = handle:close()
    if type(r1) == "number" then return r1 == 0, nil, r1 end
    return r1, r2, r3
end

-- POSIX shell quoting
---@param str? string
---@return string
local function sh_quote(str)
    if not str then return "''" end
    return "'" .. tostring(str):gsub("'", "'\\''") .. "'"
end

-- Windows cmd quoting: double-quote, escape internal double-quotes by doubling
---@param str any
---@return string
local function win_quote(str)
    return '"' .. tostring(str):gsub('"', '""') .. '"'
end

---@param path string? 路径
---@return string? 转为 lfs 可用的路径
local function lfs_path(path)
    if unix or not path then return path end
    local p = path:gsub("\\", "/")
    if msys then
        p = p:gsub("^/([%a])/", "%1:/")
        p = p:gsub("^/([%a])$", "%1:/")
    end
    return p
end

--- 提取路径的最后一个组件（文件名）
---@param path string 路径
---@return string 文件名
function FS.basename(path)
    return path:match('([^/\\]+)$') or path
end

--- 提取路径的目录部分
---@param path string 路径
---@return string 目录路径
function FS.dirname(path)
    -- 去除末尾路径分隔符
    if not path:match('^[/\\]$') then
        path = path:gsub('[/\\]$', '')
    end

    local base = FS.basename(path)
    -- 如果 Basename == Path 头 -> 文件（本目录）
    if path == base then
        return '.'
    end

    path = path:sub(1, #path-#base)
    return path
end

--- [ 获得工作目录 ] ---
---@return string
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
---@return string
local function src()
    local path = assert(arg[0])
    if unix then
        local file = FS.basename(path)
        local dir = FS.dirname(path)
        local handle = io.popen(('cd %s && pwd'):format(sh_quote(dir)))
        local result = handle:read('*l') .. '/' .. file
        handle:close()
        return result
    end

    -- Windows: resolve arg[0] to absolute path
    if path:match('^[A-Za-z]:') then
        return p:gsub("/", "\\")
    end

    if path:match('^[\\/]') then
        local wd = cwd()
        local drive = wd:match('^([A-Za-z]:)') or "C:"
        return drive .. path:gsub("/", "\\")
    end

    return cwd() .. "\\" .. path:gsub("/", "\\")
end

---@type string
FS.src = src()
---@type string
FS.cwd = cwd()

--- [ 等同于 `ls -A` ]
---@param path? string 目标目录，默认当前目录
---@return string[] 目录条目列表
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
---@param path string 文件或目录路径
---@return { size: integer, mtime: integer?, perm: string?, type: string }? 属性表，不存在时返回 nil
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
---@param path string 文件或目录路径
---@param type string 检测类型：'FILE'|'DIR'|'LINK'|'EXIST'
---@return boolean 是否匹配
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
---@vararg string
---@return string
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
---@param path string 目录路径
---@return boolean 是否成功
---@return string? 失败时的错误信息
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
---@param dir_path string 目录路径
---@return boolean 是否成功
---@return string? 失败时的错误信息
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
---@param path string|string[] 路径或路径数组
---@return boolean 是否全部删除成功
function FS.rm(path)
    if type(path) ~= 'string' and type(path) ~= 'table' then
        error(fmt(1, 'rm', 'string|array', type(path)))
    end

    -- 统一转换为 table
    local paths = (type(path) == "table") and path or { path }
    if #paths == 0 then return true end

    if not util.is_array(paths) then
        error(fmt(1, 'rm', 'string|array', 'map'))
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
---@param src string 源路径
---@param dst string 目标路径
---@return boolean 是否成功
---@return string? 失败时的错误信息
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
---@param src string 源路径
---@param dst string 目标路径
---@return boolean 是否成功
---@return string? 失败时的错误信息
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
---@param path string 起始目录
---@param name string|string[] 文件名（支持通配符），或文件名模式数组
---@param typ? "FILE"|"DIR"|"LINK" 限定类型
---@return string[] 匹配的文件路径列表
function FS.find(path, name, typ)
    local entries = {}

    if unix then
        local clean_path = path:gsub("/+$", "")
        local name_arg = ''

        if type(name) == 'string' then
            name_arg = (' -name %s '):format(sh_quote(name))
        elseif util.is_array(name) then
            name_arg = '\\('
            for _,pat in ipairs(name) do
                name_arg = name_arg..(' -name %s -o '):format(sh_quote(pat))
            end

            name_arg = name_arg:gsub('-o%s*$', '')
            name_arg = name_arg..' \\)'
        else
            error(fmt(2, 'find', 'string|array', type(name)))
        end

        local cmd = ("find %s %s"):format(sh_quote(clean_path), name_arg)
        local types = {
            ['FILE'] = 'f', ['DIR'] = 'd', ['LINK'] = 'l',
        }

        if typ then
            cmd = cmd .. " -type " .. (types[typ] or sh_quote(typ))
        end

        local handle = assert(io.popen(cmd))
        for entry in handle:lines() do
            entries[#entries + 1] = entry:gsub('\r$', '')
        end

        local ok, ext, code = close_result(handle)
        if not ok then
            error({ext = ext, code = code})
        end
    else
        -- Windows native: use dir /s /b
        local clean_path = path:gsub("[/\\]+$", "")

        local patterns
        if type(name) == 'string' then
            patterns = { name }
        elseif util.is_array(name) then
            patterns = name
        else
            error(fmt(2, 'find', 'string|array', type(name)))
        end

        if #patterns == 0 then return entries end

        local parts = {}
        for _, pat in ipairs(patterns) do
            parts[#parts + 1] = win_quote(clean_path .. "\\" .. pat)
        end

        local cmd = ("dir /s /b %s 2>nul"):format(table.concat(parts, " "))

        if typ == 'FILE' then
            cmd = cmd:gsub(" 2>nul", " /a:-d 2>nul")
        elseif typ == 'DIR' then
            cmd = cmd:gsub(" 2>nul", " /a:d 2>nul")
        elseif typ == 'LINK' then
            cmd = cmd:gsub(" 2>nul", " /a:l 2>nul")
        end

        local handle = assert(io.popen(cmd))
        for entry in handle:lines() do
            entries[#entries + 1] = entry:gsub('\r$', '')
        end

        local ok, ext, code = close_result(handle)
        if not ok then
            error({ext = ext, code = code})
        end
    end

    return entries
end

return FS
