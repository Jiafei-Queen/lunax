local unix = require('lunax.os_prober') ~= 'NT'
local popen = require('lunax.popen')
local json = require('lunax.json')

local Hash = {}

--- [ 类展开器 ] ---
local function obj_expander(v)
    local t = type(v)
    if t == "string" then
        return v
    -- 统一转为字符串
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "table" then
        -- 递归清洗 table 内部的所有键值
        local cleaned = {}
        for k, val in pairs(v) do
            cleaned[k] = obj_expander(val)
        end
        return json.encode(cleaned)
    else
        -- 拒绝其他所有类型 (function, thread, userdata, nil)
        error("Unsupported data type in object: " .. t)
    end
end


--- [ 文件哈希 ] ---
local function hash_file(file, hash)
    local cmd = unix and ('%ssum %q'):format(hash:lower(), file)
        or ('certutil -hashfile %q %s'):format(file, hash:upper())

    local handle = popen((cmd), { stderr = true })
    local res = handle:read('*l')
    return handle:close() and res or false, res
end

function Hash.md5_file(file) return hash_file(file, 'MD5') end
function Hash.sha256_file(file) return hash_file(file, 'SHA256') end
function Hash.sha512_file(file) return hash_file(file, 'SHA512') end


--- [ 对象哈希 ] ---
local function hash_buf(input, hash_type)
    local tasks = {}
    local is_single = false

    -- 使用 obj_expander 规范输入
    if type(input) == "table" then
        for k, v in pairs(input) do
            tasks[tostring(k)] = obj_expander(v)
        end
    else
        -- 如果是单个 string/number/boolean，通过 obj_expander 处理后存入
        tasks["1"] = obj_expander(input)
        is_single = true
    end

    -- 写入临时文件
    local json_str = json.encode(tasks)
    local tmp_json = os.tmpname() .. ".json"
    local file <close> = assert(io.open(tmp_json, "w"))
    file:write(json_str)

    local results = {}
    local cmd

    if unix then
        -- xxxsum + awk
        local cmd_name = hash_type:lower() .. "sum"
        cmd = string.format([[awk -F'":"|","|{"|"}' '{for(i=2;i<=NF;i+=2) if($(i)!="") print $(i)}' %q | while read -r key; do read -r val; hash=$(echo -n "$val" | %s | awk '{print $1}'); echo "$key:$hash"; done]], tmp_json, cmd_name)
    else
        --- Windows PowerShell
        local algo = hash_type:upper()
        cmd = string.format([[powershell -NoProfile -Command "$hasher = [System.Security.Cryptography.HashAlgorithm]::Create('%s'); $obj = Get-Content -Raw -Path '%s' | ConvertFrom-Json; foreach ($p in $obj.psobject.properties) { $bytes = [System.Text.Encoding]::UTF8.GetBytes($p.value); $hash = [System.BitConverter]::ToString($hasher.ComputeHash($bytes)) -replace '-'; Write-Output ($p.name + ':' + $hash) }"]], algo, tmp_json)
    end

    -- 执行并解析回传结果
    local handle = io.popen(cmd)
    if handle then
        for line in handle:lines() do
            local key, hash = line:match("^([^:]+):(%x+)")
            if key and hash then
                local num_key = tonumber(key)
                if num_key then
                    results[num_key] = hash:lower() -- 统一保证输出小写哈希
                else
                    results[key] = hash:lower()
                end
            end
        end
        handle:close()
    end

    os.remove(tmp_json)

    if is_single then
        return results[1]
    else
        return results
    end
end

function Hash.md5_buf(input) return hash_buf(input, 'MD5') end
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