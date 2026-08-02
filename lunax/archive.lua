local popen = require('lunax.popen')
-- local logger = require('lunax.logger')
local util = require('lunax.util')
local fmt = util.fmt_type_err
local unix = require('lunax.os_prober') ~= 'NT'

---@class lunax.archive
local Archive = {}

--- 压缩文件/目录（单个路径）或批量压缩（路径数组）
---@param src string|string[] 源路径或路径数组
---@param dst? string 目标压缩包路径，单个路径时可省略
---@return boolean 是否成功
---@return string? 失败时的错误信息
function Archive.zip(src, dst)

    if type(src) == 'string' then
        dst = dst or src..'.zip'
    elseif type(src) == 'table' then
        if not util.is_array(src) then
            error(fmt(1, 'zip', 'string|array', 'map'))
        end

        if type(dst) ~= 'string' then
            error(fmt(2, 'zip', 'string', type(dst)))
        end

        local str = ''
        for _, v in ipairs(src) do
            str = unix and str..('%q '):format(v)
                or str..('%q, '):format(v)
        end

        -- 删去末尾“, ”
        src = unix and str or str:sub(1, #str-2)
    else
        error(fmt(1, 'zip', 'string|array', type(src)))
    end

    local cmd = unix and ('zip -q -r %q %s'):format(dst, src)
        or ([[powershell -NoProfile -Command "Compress-Archive -Path %s -DestinationPath "%s" -Force"]]):format(src, dst)

    -- logger.debug('archive.zip', cmd)
    local handle = popen(cmd, { stderr = true })

    local res = unix and handle:read('*a'):gsub('^\n', '')
        or handle:read('*l')

    local exit = handle:close()

    -- logger.debug('archive.zip', 'res:'..tostring(res))
    -- logger.debug('archive.zip', 'code: '..exit.code)

    if exit.ok then
        return true
    else
        res = res:gsub('^zip error:%s*', '')                    -- 去 zip error 头
        res = res:gsub('^[Cc]ompress%-[Aa]rchive%s*:%s*', '')   -- 去 Compress-Archive 头
        res = util.trim(res)                                    -- 去尾部空白字符
        return nil, res
    end
end

--- 解压压缩包
---@param src string 压缩包路径
---@param dst? string 解压目标目录，默认当前目录
---@return boolean 是否成功
---@return string? 失败时的错误信息
function Archive.unzip(src, dst)
    if type(src) ~= 'string' then
        error(fmt(1, 'unzip', 'string', type(src)))
    end

    dst = dst or '.'

    local cmd = unix 
        and ('unzip -q %q -d %q'):format(src, dst)
        or ([[powershell -NoProfile -Command "Expand-Archive -Path '%s' -DestinationPath '%s' -Force"]]):format(src, dst)

    local handle = popen(cmd, { stderr = true })

    local res = unix and handle:read('*a'):gsub('^\n', '')
        or handle:read('*l')

    if handle:close().ok then
        return true
    else
        res = res:gsub('^unzip error:%s*', '')                  -- 去 zip error 头
        res = res:gsub('^[Ee]xpand%-[Aa]rchive%s*:%s*', '')     -- 去 Expand-Archive 头
        res = util.trim(res)                                    -- 去尾部空白字符
        return false, res
    end
end

return Archive
