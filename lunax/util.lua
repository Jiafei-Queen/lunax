local Util = {}

--- [ 打印 Table ] ---
function Util.dump(obj, name)
    local function _dump(value, indent, depth)
        local sp = string.rep("  ", indent)
        if type(value) == "table" then
            if depth > 10 then return "{ ... (Max Depth) ... }" end

            local sb = {}
            table.insert(sb, "{\n")

            for _, k, v in Util.spairs(value) do
                local key_str = type(k) == "string" and string.format("[%q]", k) or string.format("[%s]", tostring(k))
                table.insert(sb, string.format("%s  %s = %s,\n", sp, key_str, _dump(v, indent + 1, depth + 1)))
            end

            table.insert(sb, sp .. "}")
            return table.concat(sb)
        elseif type(value) == "string" then
            return string.format("%q", value)
        else
            return tostring(value)
        end
    end

    local prefix = name and (name .. " = ") or ""
    print(prefix .. _dump(obj, 0, 1))
end

--- [ 去除字符串两端的空白字符 ] ---
function Util.trim(str)
    if not str then return "" end
    return (str:gsub("^%s*(.-)%s*$", "%1"))
end

--- [ 字符串分割 ] ---
-- @param str 目标字符串
-- @param sep 分隔符字符（支持传入单个分隔字符，如 ":" 或 ","）
function Util.split(str, sep)
    local fields = {}
    if not str or str == "" then return fields end
    local pattern = string.format("([^%s]+)", sep or "%s")
    str:gsub(pattern, function(c) fields[#fields + 1] = c end)
    return fields
end

--- [ 深度克隆 Table ] ---
function Util.clone(obj)
    if type(obj) ~= "table" then return obj end
    local res = {}
    for k, v in pairs(obj) do 
        res[Util.clone(k)] = Util.clone(v) 
    end
    return setmetatable(res, getmetatable(obj))
end

--- [ 字节数转换为人类可读 (Human Size) ] ---
-- @param bytes 字节大小数字
function Util.hsz(bytes)
    local n = tonumber(bytes)
        or tonumber(type(bytes) == "string" and bytes:gsub("B$", ""))

    local u = { "B", "KB", "MB", "GB", "TB" }
    local i = 1
    while n >= 1024 and i < #u do
        n = n / 1024
        i = i + 1
    end

    return string.format(i == 1 and "%d%s" or "%.2f%s", n, u[i])
end

function Util.is_array(t)
    if type(t) ~= "table" then
        return false
    end

    -- 计算连续整数键的数量
    local count = 0
    for _ in ipairs(t) do
        count = count + 1
    end

    -- 计算所有键值对的总数
    local total = 0
    for _ in pairs(t) do
        total = total + 1
    end

    return count == total
end

function Util.fmt_type_err(idx, fn, exp, got)
    return ("bad argument #%d to '%s' (%s expected, got %s)"):format(idx, fn, exp, got)
end

--- 按字母/升序顺序遍历键的迭代器封装
-- @param t table 要遍历的表
-- @return function 迭代器函数
-- @return table 排序后的键数组
-- @return number 初始控制变量（索引 0）
function Util.spairs(t)
    local keys = {}
    for k in pairs(t) do table.insert(keys, k) end

    table.sort(keys, function(a, b)
        local type_a, type_b = type(a), type(b)
        if type_a == "number" and type_b == "number" then
            return a < b
        end
        -- 如果类型不同或不是数字，转换为字符串按字母表排序
        return tostring(a) < tostring(b)
    end)

    return function(state, i)
        i = i + 1
        local k = state[i]
        if k ~= nil then return i, k, t[k] end
    end, keys, 0
end

--- 安全遍历数组的迭代器（即使中间包含 nil，也绝不中断并保持顺序）
-- @param t table 要遍历的数组
-- @return function 迭代器函数
-- @return table 包含最大边界的状态表 {max_len = max_len, origin_table = t}
-- @return number 初始控制变量（索引 0）
function Util.sipairs(t)
    local max_len = 0

    for k in pairs(t) do
        if type(k) == "number" and k > 0 and math.floor(k) == k then
            if k > max_len then
                max_len = k
            end
        end
    end

    local state = {
        max_len = max_len,
        origin_table = t
    }

    return function(s, i)
        i = i + 1
        if i <= s.max_len then
            return i, s.origin_table[i]
        end
    end, state, 0
end

return Util
