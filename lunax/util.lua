local Util = {}

--- [ 打印 Table ] ---
function Util.dump(obj, name)
    local function _dump(value, indent, depth)
        local sp = string.rep("  ", indent)
        if type(value) == "table" then
            if depth > 10 then return "{ ... (Max Depth) ... }" end
            
            local sb = {}
            table.insert(sb, "{\n")
            
            -- 1. 先把所有的 Key 收集起来
            local keys = {}
            for k in pairs(value) do
                table.insert(keys, k)
            end
            
            -- 2. 对 Key 进行字母表排序
            table.sort(keys, function(a, b)
                return tostring(a) < tostring(b)
            end)
            
            -- 3. 按照排序后的顺序进行遍历输出
            for _, k in ipairs(keys) do
                local v = value[k]
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

return Util
