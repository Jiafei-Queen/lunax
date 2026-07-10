local hash = require('lunax.hash')

local TOTAL_KB = 512

local MAP = {
    MD5 = hash.md5_file,
    SHA256 = hash.sha256_file,
    SHA512 = hash.sha512_file,
    ADLER32 = hash.adler32,
    CRC32 = hash.crc32
}

--- [ 调用 ] ---
local TEST = { 'ADLER32', 'CRC32' }

local data_chunks = {}
for _=1, TOTAL_KB do
    -- 1KB, A-Z 随机字符
    table.insert(data_chunks, string.char(math.random(65, 90)):rep(1024))
end

local data = table.concat(data_chunks)
for _,v in ipairs(TEST) do
    local start = os.clock()
    MAP[v](data)
    print(('%s: %.3fms'):format(v, (os.clock() - start) * 1000))
end