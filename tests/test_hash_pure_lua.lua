local hash = require('lunax.hash')

local TOTAL_KB = 512

local MAP = {
    ADLER32 = hash.adler32,
    CRC32 = hash.crc32
}

--- [ 调用 ] ---
local data_chunks = {}
for _=1, TOTAL_KB do
    -- 1KB, A-Z 随机字符
    table.insert(data_chunks, string.char(math.random(65, 90)):rep(1024))
end

local data = table.concat(data_chunks)
for k,v in pairs(MAP) do
    local start = os.clock()
    v(data)
    print(('%s: %.3fms'):format(k, (os.clock() - start) * 1000))
end