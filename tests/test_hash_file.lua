local hash = require('lunax.hash')
local util = require('lunax.util')
local ansi = require('lunax.ansi')

local TOTAL_KB = 512

local MAP = {
    MD5 = hash.md5_file,
    SHA1 = hash.sha1_file,
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
local file = assert(io.open(tmp, 'w'))
file:write(data)
file:close()

print(ansi.green('\n---- [ hash_file test ] ----\n'))

for _,k,v in util.spairs(MAP) do
    local res, err = v(tmp)
    if not res then
        print(k..': ERROR - '..tostring(err))
        os.exit(1)
    else
        print(k..': '..res)
    end
end

os.remove(tmp)