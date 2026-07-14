local b64 = require('lunax.base64')
local ansi = require('lunax.ansi')

local TOTAL_KB = 512

local data_chunks = {}
for _=1, TOTAL_KB do
    table.insert(data_chunks, string.char(math.random(65, 90)):rep(1024))
end

local data = table.concat(data_chunks)

local tmp_raw  = os.tmpname()
local tmp_enc  = os.tmpname()
local tmp_dec  = os.tmpname()

local f = assert(io.open(tmp_raw, 'wb'))
f:write(data)
f:close()

print(ansi.green('\n---- [ base64 performance ] ----'))

-- encode_str
do
    local start = os.clock()
    local enc = b64.encode_str(data)
    local dur = (os.clock() - start) * 1000
    print(('encode_str: %.3fms (%.1f MB/s)'):format(dur, TOTAL_KB / dur * 1000 / 1024))

    local f2 = assert(io.open(tmp_enc, 'wb'))
    f2:write(enc)
    f2:close()
end

-- decode_str
do
    local f2 = assert(io.open(tmp_enc, 'rb'))
    local enc = f2:read('*a')
    f2:close()

    local start = os.clock()
    local dec = b64.decode_str(enc)
    local dur = (os.clock() - start) * 1000
    print(('decode_str: %.3fms (%.1f MB/s)'):format(dur, TOTAL_KB / dur * 1000 / 1024))

    if dec ~= data then print(ansi.red('  decode_str MISMATCH!')) end
end

-- encode_file
do
    local start = os.clock()
    local ok, err = b64.encode_file(tmp_raw, tmp_enc)
    local dur = (os.clock() - start) * 1000
    print(('encode_file: %.3fms (%.1f MB/s)'):format(dur, TOTAL_KB / dur * 1000 / 1024))
    if not ok then print(ansi.red('  encode_file ERROR: ' .. tostring(err))) end
end

-- decode_file
do
    local start = os.clock()
    local ok, err = b64.decode_file(tmp_enc, tmp_dec)
    local dur = (os.clock() - start) * 1000
    print(('decode_file: %.3fms (%.1f MB/s)'):format(dur, TOTAL_KB / dur * 1000 / 1024))
    if not ok then print(ansi.red('  decode_file ERROR: ' .. tostring(err))) end
end

-- verify file roundtrip
do
    local f1 = assert(io.open(tmp_raw, 'rb'))
    local f2 = assert(io.open(tmp_dec, 'rb'))
    local a, b = f1:read('*a'), f2:read('*a')
    f1:close()
    f2:close()
    if a == b then
        print(ansi.green('  file roundtrip OK'))
    else
        print(ansi.red('  file roundtrip MISMATCH'))
    end
end

os.remove(tmp_raw)
os.remove(tmp_enc)
os.remove(tmp_dec)
