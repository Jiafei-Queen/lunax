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

-- int-indexed charset: chars[pos] => char (avoids B64:sub string alloc per call)
local b64_chars = {}
for i = 1, 64 do b64_chars[i] = B64:sub(i, i) end

-- byte-indexed decode table: dec[byte] => value (avoids input:sub(i,i) string alloc per char)
-- 0 for non-Base64 bytes
local B64_DEC = {}
for i = 1, 64 do
    B64_DEC[string.byte(B64, i)] = i - 1
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

local use_native = not pcall(require, 'bit') and not pcall(require, 'bit32')

if use_native then
    -- Lua 5.4+: compile encode_str/decode_str with native operators, zero call overhead

    b64.encode_str = load([[
        local chars = ...
        return function(input)
            if type(input) ~= 'string' then
                error("bad argument #1 to 'encode_str' (string expected, got "..type(input)..")")
            end
            local out, len, i = {}, #input, 1
            while i <= len - 2 do
                local c1, c2, c3 = string.byte(input, i, i + 2)
                local n = (c1 << 16) | (c2 << 8) | c3
                out[#out+1] = chars[(n >> 18) + 1]
                out[#out+1] = chars[((n >> 12) & 63) + 1]
                out[#out+1] = chars[((n >> 6) & 63) + 1]
                out[#out+1] = chars[(n & 63) + 1]
                i = i + 3
            end
            local remain = len - i + 1
            if remain == 1 then
                local n = string.byte(input, i) << 16
                out[#out+1] = chars[(n >> 18) + 1]
                out[#out+1] = chars[((n >> 12) & 63) + 1]
                out[#out+1] = '=='
            elseif remain == 2 then
                local c1, c2 = string.byte(input, i, i + 1)
                local n = (c1 << 16) | (c2 << 8)
                out[#out+1] = chars[(n >> 18) + 1]
                out[#out+1] = chars[((n >> 12) & 63) + 1]
                out[#out+1] = chars[((n >> 6) & 63) + 1]
                out[#out+1] = '='
            end
            return table.concat(out)
        end
    ]])(b64_chars)

    b64.decode_str = load([[
        local dec = ...
        return function(input)
            if type(input) ~= 'string' then
                error("bad argument #1 to 'decode_str' (string expected, got "..type(input)..")")
            end
            input = input:gsub('[ \t\r\n]', '')
            local pad = input:match('=+$')
            pad = pad and #pad or 0
            if pad > 0 then
                input = input:sub(1, -1 - pad)
            end
            local out, len, i = {}, #input, 1
            while i <= len - 3 do
                local b1, b2, b3, b4 = string.byte(input, i, i + 3)
                local n = (dec[b1] << 18) | (dec[b2] << 12) | (dec[b3] << 6) | dec[b4]
                out[#out+1] = string.char((n >> 16) & 255)
                out[#out+1] = string.char((n >> 8) & 255)
                out[#out+1] = string.char(n & 255)
                i = i + 4
            end
            local remain = len - i + 1
            if remain == 2 then
                local b1, b2 = string.byte(input, i, i + 1)
                local n = (dec[b1] << 18) | (dec[b2] << 12)
                out[#out+1] = string.char((n >> 16) & 255)
            elseif remain == 3 then
                local b1, b2, b3 = string.byte(input, i, i + 2)
                local n = (dec[b1] << 18) | (dec[b2] << 12) | (dec[b3] << 6)
                out[#out+1] = string.char((n >> 16) & 255)
                out[#out+1] = string.char((n >> 8) & 255)
            end
            return table.concat(out)
        end
    ]])(B64_DEC)
else
    -- LuaJIT: use bit module, but with table-based lookups

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
            out[#out+1] = b64_chars[rshift(n, 18) + 1]
            out[#out+1] = b64_chars[band(rshift(n, 12), 63) + 1]
            out[#out+1] = b64_chars[band(rshift(n, 6), 63) + 1]
            out[#out+1] = b64_chars[band(n, 63) + 1]
            i = i + 3
        end

        local remain = len - i + 1
        if remain == 1 then
            local n = lshift(input:byte(i), 16)
            out[#out+1] = b64_chars[rshift(n, 18) + 1]
            out[#out+1] = b64_chars[band(rshift(n, 12), 63) + 1]
            out[#out+1] = '=='
        elseif remain == 2 then
            local c1, c2 = input:byte(i, i + 1)
            local n = bor(lshift(c1, 16), lshift(c2, 8))
            out[#out+1] = b64_chars[rshift(n, 18) + 1]
            out[#out+1] = b64_chars[band(rshift(n, 12), 63) + 1]
            out[#out+1] = b64_chars[band(rshift(n, 6), 63) + 1]
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
            local b1, b2, b3, b4 = string.byte(input, i, i + 3)
            local n = bor(
                lshift(B64_DEC[b1], 18),
                lshift(B64_DEC[b2], 12),
                lshift(B64_DEC[b3], 6),
                B64_DEC[b4]
            )
            out[#out+1] = string.char(band(rshift(n, 16), 255))
            out[#out+1] = string.char(band(rshift(n, 8), 255))
            out[#out+1] = string.char(band(n, 255))
            i = i + 4
        end

        local remain = len - i + 1
        if remain == 2 then
            local b1, b2 = string.byte(input, i, i + 1)
            local n = bor(lshift(B64_DEC[b1], 18), lshift(B64_DEC[b2], 12))
            out[#out+1] = string.char(band(rshift(n, 16), 255))
        elseif remain == 3 then
            local b1, b2, b3 = string.byte(input, i, i + 2)
            local n = bor(
                lshift(B64_DEC[b1], 18),
                lshift(B64_DEC[b2], 12),
                lshift(B64_DEC[b3], 6)
            )
            out[#out+1] = string.char(band(rshift(n, 16), 255))
            out[#out+1] = string.char(band(rshift(n, 8), 255))
        end

        return table.concat(out)
    end
end

return b64
