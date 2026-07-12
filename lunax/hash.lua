local unix = require('lunax.os_prober') ~= 'NT'
local logger = require('lunax.logger')
local util = require('lunax.util')
local popen = require('lunax.popen')

local Hash = {}

--- [ 文件哈希 ] ---
local function hash_file(file, hash)
    local cmd = unix and ('%ssum %q'):format(hash:lower(), file)
        or ('certutil -hashfile %q %s'):format(file, hash:upper())

    -- logger.debug('hash_file', 'cmd: '..cmd)
    local handle = popen((cmd), { stderr = true })
    local res = handle:read('*a')
    -- logger.debug('hash_file', 'res: '..res)
    if handle:close() then
        return util.split(res, '\n')[2], nil
    else
        return nil, res:gsub('\n%', '')
    end
end

function Hash.md5_file(file) return hash_file(file, 'MD5') end
function Hash.sha1_file(file) return hash_file(file, 'SHA1') end
function Hash.sha256_file(file) return hash_file(file, 'SHA256') end
function Hash.sha512_file(file) return hash_file(file, 'SHA512') end


--- [ 字符串哈希 ] ---
local function hash_buf(input, hash_type)
    --- [ 过滤参数 ] ---
    local function fmt(ty)
        return util.fmt_type_err(1, 'hash_buf', 'array or string or number', ty)
    end

    local is_tab
    local filter = {
        string = function() input = {input} end,
        number = function() input = {tostring(input)} end,

        table = function()
            if not util.is_array(input) then
                error(fmt('table'))
            end

            if #input == 0 then
                return {}
            end

            is_tab = true
        end
    }

    local fn = filter[type(input)]
    if not fn then
        fmt(type(input))
    else fn() end

    --- [ 逻辑 ] ---
    local results = {}
    local tmp_out = os.tmpname()
    local handle

    if unix then
        local cmd_name = hash_type:lower() .. "sum"
        -- 使用 while read -d "" 按 \0 切割读取，彻底避免引号转义与命令注入漏洞
        local cmd = string.format(
            [[while IFS= read -r -d "" val; do printf "%%s" "$val" | %s | awk '{print $1}'; done > %q]], 
            cmd_name, tmp_out
        )
        handle = io.popen(cmd, "w")
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
    end

    if not handle then return {} end

    for _, v in ipairs(input) do
        handle:write(tostring(v))
        handle:write("\0") -- 使用 Null 字符作为绝对安全的边界
    end

    handle:close()

    local file <close> = io.open(tmp_out, "r")
    if file then
        local i = 1
        for line in file:lines() do
            results[i] = line
            i = i + 1
        end
    end

    os.remove(tmp_out)
    if not is_tab then
        results = results[1]
    end

    return results
end

function Hash.md5_buf(input) return hash_buf(input, 'MD5') end
function Hash.sha1_buf(input) return hash_buf(input, 'SHA1') end
function Hash.sha256_buf(input) return hash_buf(input, 'SHA256') end
function Hash.sha512_buf(input) return hash_buf(input, 'SHA512') end


--- [ Adler32 算法 ] ---
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

    return (b << 16) | a
end

--- [ CRC32 算法 ] ---

-- 初始化 CRC32 查找表
local crc_table = {}
local POLY = 0xEDB88320 -- 标准 CRC32 多项式 (IEEE 802.3)

for i = 0, 255 do
    local crc = i
    for j = 1, 8 do
        if (crc & 1) ~= 0 then
            crc = (crc >> 1) ~ POLY
        else
            crc = crc >> 1
        end
    end

    crc_table[i] = crc
end

--- 计算字符串的 CRC32 值
-- @param str 字符串输入
-- @return 32位无符号整数结果
function Hash.crc32(str)
    local crc = 0xFFFFFFFF

    for i = 1, #str do
        local byte = string.byte(str, i)
        local lookup_index = (crc ~ byte) & 0xFF
        crc = (crc >> 8) ~ crc_table[lookup_index]
    end

    return (crc ~ 0xFFFFFFFF) & 0xFFFFFFFF
end

return Hash