local hash = require('lunax.hash')
local util = require('lunax.util')

local TOTAL_KB = 512

local MAP = {
    MD5 = hash.md5_file,
    SHA256 = hash.sha256_file,
    SHA512 = hash.sha512_file,
}

--- [ 调用 ] ---
local data_chunks = {}
for _=1, TOTAL_KB do
    -- 1KB, A-Z 随机字符
    table.insert(data_chunks, string.char(math.random(65, 90)):rep(1024))
end

local data = table.concat(data_chunks)

local tmp = os.tmpname()
local file <close> = assert(io.open(tmp, 'w'))
file:write(data)

for _,k,v in util.spairs(MAP) do
    local res = v(tmp)
    print(k..': '..res)
end

os.remove(tmp)