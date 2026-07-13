-- local logger = require('lunax.logger')
local unix = require('lunax.os_prober') ~= 'NT'
local util = require('lunax.util')
local popen = require('lunax.popen')
local fmt = util.fmt_type_err

local b64 = {}

-- ====================================================================
--  Bitwise 运算抽象层（兼容 Lua 5.4 & LuaJIT）
-- ====================================================================
--  LuaJIT 使用 bit 模块；Lua 5.4 通过 load() 在运行时编译原生运算符
--  ，避免 LuaJIT 解析到 & | << >> 时报错。

local band, bor, lshift, rshift

do
    local ok, lib = pcall(require, 'bit')
    if not ok then
        ok, lib = pcall(require, 'bit32')
    end

    if ok then
        local function wrap(fn)
            return function(...)
                local r = select(1, ...)
                for i = 2, select('#', ...) do r = fn(r, select(i, ...)) end
                return r
            end
        end
        band = wrap(lib.band)
        bor  = wrap(lib.bor)
        lshift, rshift = lib.lshift, lib.rshift
    else
        band = load([[
            return function(...)
                local r = select(1, ...)
                for i = 2, select('#', ...) do r = r & select(i, ...) end
                return r
            end
        ]])()
        bor = load([[
            return function(...)
                local r = select(1, ...)
                for i = 2, select('#', ...) do r = r | select(i, ...) end
                return r
            end
        ]])()
        lshift = load([[return function(a,b) return a << b end]])()
        rshift = load([[return function(a,b) return a >> b end]])()
    end
end

-- ====================================================================
--  Base64 字母表 & 解码表
-- ====================================================================

local B64 = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local B64_DEC = {}
for i = 1, 64 do
    B64_DEC[B64:sub(i, i)] = i - 1
end

-- ====================================================================
--  文件操作：certutil (Windows) / base64 (Unix)
-- ====================================================================

--- Base64 编码文件
---@param input string  输入文件路径
---@param output string  输出文件路径
---@return boolean success?, string? err
function b64.encode_file(input, output)
    if type(input) ~= 'string' then
        error(fmt(1, 'encode_file', 'string', type(input)))
    end
    if type(output) ~= 'string' then
        error(fmt(2, 'encode_file', 'string', type(output)))
    end

    local cmd = unix
        and ('base64 < %q > %q'):format(input, output)
        or  ('certutil -encode %q %q'):format(input, output)

    local handle = popen(cmd)
    handle:read('*a')
    local exit = handle:close()
    if not exit.ok then
        return nil, ('base64.encode_file failed (exit %d)'):format(exit.code)
    end
    return true
end

--- Base64 解码文件
---@param input string  输入文件路径
---@param output string  输出文件路径
---@return boolean success?, string? err
function b64.decode_file(input, output)
    if type(input) ~= 'string' then
        error(fmt(1, 'decode_file', 'string', type(input)))
    end
    if type(output) ~= 'string' then
        error(fmt(2, 'decode_file', 'string', type(output)))
    end

    local cmd = unix
        and ('base64 -d < %q > %q'):format(input, output)
        or  ('certutil -decode %q %q'):format(input, output)

    local handle = popen(cmd)
    handle:read('*a')
    local exit = handle:close()
    if not exit.ok then
        return nil, ('base64.decode_file failed (exit %d)'):format(exit.code)
    end
    return true
end

-- ====================================================================
--  字符串操作：纯 Lua 实现
-- ====================================================================

--- Base64 编码字符串
---@param input string  原始字节串
---@return string  Base64 编码结果
function b64.encode_str(input)
    if type(input) ~= 'string' then
        error(fmt(1, 'encode_str', 'string', type(input)))
    end

    local out, len, i = {}, #input, 1

    while i <= len - 2 do
        local c1, c2, c3 = input:byte(i, i + 2)
        local n = bor(lshift(c1, 16), lshift(c2, 8), c3)
        out[#out+1] = B64:sub(rshift(n, 18) + 1, rshift(n, 18) + 1)
        out[#out+1] = B64:sub(band(rshift(n, 12), 63) + 1, band(rshift(n, 12), 63) + 1)
        out[#out+1] = B64:sub(band(rshift(n, 6), 63) + 1, band(rshift(n, 6), 63) + 1)
        out[#out+1] = B64:sub(band(n, 63) + 1, band(n, 63) + 1)
        i = i + 3
    end

    local remain = len - i + 1
    if remain == 1 then
        local n = lshift(input:byte(i), 16)
        out[#out+1] = B64:sub(rshift(n, 18) + 1, rshift(n, 18) + 1)
        out[#out+1] = B64:sub(band(rshift(n, 12), 63) + 1, band(rshift(n, 12), 63) + 1)
        out[#out+1] = '=='
    elseif remain == 2 then
        local c1, c2 = input:byte(i, i + 1)
        local n = bor(lshift(c1, 16), lshift(c2, 8))
        out[#out+1] = B64:sub(rshift(n, 18) + 1, rshift(n, 18) + 1)
        out[#out+1] = B64:sub(band(rshift(n, 12), 63) + 1, band(rshift(n, 12), 63) + 1)
        out[#out+1] = B64:sub(band(rshift(n, 6), 63) + 1, band(rshift(n, 6), 63) + 1)
        out[#out+1] = '='
    end

    return table.concat(out)
end

--- Base64 解码字符串
---@param input string  Base64 编码字符串
---@return string  原始字节串
function b64.decode_str(input)
    if type(input) ~= 'string' then
        error(fmt(1, 'decode_str', 'string', type(input)))
    end

    input = input:gsub('[ \t\r\n]', '')
    local pad = input:match('=+$')
    pad = pad and #pad or 0
    if pad > 0 then
        input = input:sub(1, -1 - pad)
    end

    local out, len, i = {}, #input, 1

    while i <= len - 3 do
        local n = bor(
            lshift(B64_DEC[input:sub(i, i)], 18),
            lshift(B64_DEC[input:sub(i + 1, i + 1)], 12),
            lshift(B64_DEC[input:sub(i + 2, i + 2)], 6),
            B64_DEC[input:sub(i + 3, i + 3)]
        )
        out[#out+1] = string.char(band(rshift(n, 16), 255))
        out[#out+1] = string.char(band(rshift(n, 8), 255))
        out[#out+1] = string.char(band(n, 255))
        i = i + 4
    end

    local remain = len - i + 1
    if remain == 2 then
        local n = bor(lshift(B64_DEC[input:sub(i, i)], 18), lshift(B64_DEC[input:sub(i + 1, i + 1)], 12))
        out[#out+1] = string.char(band(rshift(n, 16), 255))
    elseif remain == 3 then
        local n = bor(
            lshift(B64_DEC[input:sub(i, i)], 18),
            lshift(B64_DEC[input:sub(i + 1, i + 1)], 12),
            lshift(B64_DEC[input:sub(i + 2, i + 2)], 6)
        )
        out[#out+1] = string.char(band(rshift(n, 16), 255))
        out[#out+1] = string.char(band(rshift(n, 8), 255))
    end

    return table.concat(out)
end

return b64
