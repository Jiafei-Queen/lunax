local unix = require('lunax.os_prober') ~= 'NT'
-- local logger = require('lunax.logger')
local util = require('lunax.util')
local popen = require('lunax.popen')
local band, bor, bxor, lshift, rshift

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
        bxor = wrap(lib.bxor)
        lshift, rshift = lib.lshift, lib.rshift
    else
        band = load([[return function(a,b) return a & b end]])()
        bor  = load([[return function(a,b) return a | b end]])()
        bxor = load([[return function(a,b) return a ~ b end]])()
        lshift = load([[return function(a,b) return a << b end]])()
        rshift = load([[return function(a,b) return a >> b end]])()
    end
end

---@class lunax.hash
local Hash = {}

--- [ 文件哈希 ]
---@param file string 文件路径
---@param hash string 哈希算法名（大写）
---@return string? 哈希值，失败时返回 nil
---@return string? 失败时的错误信息
local function hash_file(file, hash)
    local cmd = unix and ('%ssum %q'):format(hash:lower(), file)
        or ('certutil -hashfile %q %s'):format(file, hash:upper())

    -- logger.debug('hash_file', 'cmd: '..cmd)
    local handle = popen((cmd), { stderr = true })
    local res = handle:read('*a')
    -- logger.debug('hash_file', 'res: '..res)
    if handle:close().ok then
        if unix then
            res = res:match('^[^ ]+')
            return res
        else
            return util.split(res, '\n')[2]
        end
    else
        if unix then
            res = res:gsub('^[^:]+: (.+)')
            return nil, res
        else
            return nil, res:gsub('\n%', '')
        end
    end
end

--- 计算文件的 MD5 哈希
---@param file string 文件路径
---@return string? 哈希值，失败时返回 nil
---@return string? 失败时的错误信息
function Hash.md5_file(file) return hash_file(file, 'MD5') end
--- 计算文件的 SHA1 哈希
---@param file string 文件路径
---@return string? 哈希值，失败时返回 nil
---@return string? 失败时的错误信息
function Hash.sha1_file(file) return hash_file(file, 'SHA1') end
--- 计算文件的 SHA256 哈希
---@param file string 文件路径
---@return string? 哈希值，失败时返回 nil
---@return string? 失败时的错误信息
function Hash.sha256_file(file) return hash_file(file, 'SHA256') end
--- 计算文件的 SHA512 哈希
---@param file string 文件路径
---@return string? 哈希值，失败时返回 nil
---@return string? 失败时的错误信息
function Hash.sha512_file(file) return hash_file(file, 'SHA512') end


--- [ 字符串哈希 ]
---@param input string|number|string[] 字符串、数字或字符串数组
---@param hash_type string 哈希算法名（大写）
---@return string|string[] 单输入返回哈希字符串，数组输入返回哈希数组
local function hash_buf(input, hash_type)
    --- [ 过滤参数 ]
    ---@param ty string 实际类型
    ---@return string
    local function fmt(ty)
        return util.fmt_type_err(1, 'hash_buf', 'string|number|array', ty)
    end

    local is_tab
    local filter = {
        string = function() input = {input} end,
        number = function() input = {tostring(input)} end,

        table = function()
            if not util.is_array(input) then
                error(fmt('map'))
            end

            if #input == 0 then
                return {}
            end

            is_tab = true
        end
    }

    local fn = filter[type(input)]
    if not fn then
        error(fmt(type(input)))
    else fn() end

    --- [ 逻辑 ] ---
    local results = {}
    local tmp_out = os.tmpname()
    local handle

    if unix then
        local cmd_name = hash_type:lower() .. "sum"
        -- 临时文件批处理：把每个值写入独立临时文件，再单次调用 xxxsum 批量计算，
        -- 把 fork 数从 2N+1（每值一次 xxxsum+awk）降到 ~1，同时彻底消除 shell 转义/注入面
        local names = {}
        local tmp_ok = true
        for i, v in ipairs(input) do
            local name = ('%s.%d'):format(tmp_out, i)
            local f = io.open(name, 'wb')
            if not f then
                tmp_ok = false
                break
            end
            f:write(tostring(v))
            f:close()
            names[i] = name
        end

        if tmp_ok then
            -- xargs -0 按 NUL 读取路径并自动分块，规避 ARG_MAX 参数过长
            local cmd = string.format(
                [[xargs -0 %s > %q]],
                cmd_name, tmp_out
            )
            handle = io.popen(cmd, "w")

            if handle then
                for _, name in ipairs(names) do
                    handle:write(name)
                    handle:write("\0")
                end
                handle:close()
            end
        end

        for _, name in ipairs(names) do
            os.remove(name)
        end
    else
        local algo = hash_type:upper()
        -- 1. 压缩为单行，去掉所有换行符
        -- 2. 内部全部使用单引号，避免与外部的 -Command "%s" 的双引号冲突
        -- 3. 改用 ReadByte() 读取纯字节流，绕过 Windows 恶心的控制台 CodePage 编码干扰
        local ps_script = string.format(
            [[$hasher=[System.Security.Cryptography.HashAlgorithm]::Create('%s');$stream=[System.Console]::OpenStandardInput();$ms=New-Object System.IO.MemoryStream;while(($b=$stream.ReadByte()) -ne -1){if($b -eq 0){$hashBytes=$hasher.ComputeHash($ms.ToArray());$hex='';foreach($x in $hashBytes){$hex+=$x.ToString('x2')};[System.Console]::WriteLine($hex);$ms.SetLength(0)}else{$ms.WriteByte($b)}}]],
            algo
        )

        local cmd = string.format([[powershell -NoProfile -Command "%s" > %q]], ps_script, tmp_out)
        handle = io.popen(cmd, "w")

        if handle then
            for _, v in ipairs(input) do
                handle:write(tostring(v))
                handle:write("\0") -- 使用 Null 字符作为绝对安全的边界
            end
            handle:close()
        end
    end

    if not handle then
        os.remove(tmp_out)
        return {}
    end

    local file = io.open(tmp_out, "r")
    if file then
        local i = 1
        for line in file:lines() do
            results[i] = line:match('^%x+') or line
            i = i + 1
        end
        file:close()
    end

    os.remove(tmp_out)
    if not is_tab then
        results = results[1]
    end

    return results
end

--- 计算字符串（或字符串数组）的 MD5 哈希
---@param input string|number|string[]
---@return string|string[]
function Hash.md5_buf(input) return hash_buf(input, 'MD5') end
--- 计算字符串（或字符串数组）的 SHA1 哈希
---@param input string|number|string[]
---@return string|string[]
function Hash.sha1_buf(input) return hash_buf(input, 'SHA1') end
--- 计算字符串（或字符串数组）的 SHA256 哈希
---@param input string|number|string[]
---@return string|string[]
function Hash.sha256_buf(input) return hash_buf(input, 'SHA256') end
--- 计算字符串（或字符串数组）的 SHA512 哈希
---@param input string|number|string[]
---@return string|string[]
function Hash.sha512_buf(input) return hash_buf(input, 'SHA512') end


--- [ Adler32 算法 ]
---@param data string 原始字节串
---@return integer 32 位校验值
function Hash.adler32(data)
    local MOD_ADLER = 65521
    local a = 1
    local b = 0

    local len = #data
    local i = 1

    while len > 0 do
        local tlen = len > 5552 and 5552 or len
        len = len - tlen

        for j = i, i + tlen - 1 do
            a = a + string.byte(data, j)
            b = b + a
        end
        i = i + tlen

        a = a % MOD_ADLER
        b = b % MOD_ADLER
    end

    return bor(lshift(b, 16), a)
end

--- [ CRC32 算法 ] ---

-- 初始化 CRC32 查找表
local crc_table = {}
local POLY = 0xEDB88320 -- 标准 CRC32 多项式 (IEEE 802.3)

for i = 0, 255 do
    local crc = i
    for j = 1, 8 do
        if band(crc, 1) ~= 0 then
            crc = bxor(rshift(crc, 1), POLY)
        else
            crc = rshift(crc, 1)
        end
    end

    crc_table[i] = crc
end

--- 计算字符串的 CRC32 值
---@param str string 字符串输入
---@return integer 32位无符号整数结果
function Hash.crc32(str)
    local crc = 0xFFFFFFFF

    for i = 1, #str do
        local byte = string.byte(str, i)
        local lookup_index = band(bxor(crc, byte), 0xFF)
        crc = bxor(rshift(crc, 8), crc_table[lookup_index])
    end

    return band(bxor(crc, 0xFFFFFFFF), 0xFFFFFFFF)
end

return Hash
