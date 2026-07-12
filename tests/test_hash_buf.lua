local hash = require('lunax.hash')
local util = require('lunax.util')
local ansi = require('lunax.ansi')

-- 表长度
local TAB_LEN = 20

-- 随机字符长度
local MIN_STR_LEN, MAX_STR_LEN = 128, 8192

local MAP = {
    MD5 = hash.md5_buf,
    SHA1 = hash.sha1_buf,
    SHA256 = hash.sha256_buf,
    SHA512 = hash.sha512_buf,
}

--- [ 调用 ] ---
local data = {}

for _=1, TAB_LEN - 2 do
    local str = string.char(math.random(65, 90))
        :rep(math.random(MIN_STR_LEN, MAX_STR_LEN))

    table.insert(data, str)
end

-- 手动插入两数字
table.insert(data, 12)
table.insert(data, 0.18)

print(ansi.green('\n---- [ hash_buf test ] ----\n'))

for _,k,v in util.spairs(MAP) do
    print('--> '..k)
    local start = os.clock()
    local res = v(data)
    print(('dur: %.3fms'):format((os.clock() - start) * 1000))
    util.dump(res)
end