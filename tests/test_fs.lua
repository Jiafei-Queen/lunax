local fs = require('lunax.fs')
local ansi = require('lunax.ansi')

local tmpdir = os.tmpname()
os.remove(tmpdir)
local mkdir = fs.mkdir or function(p) os.execute("mkdir -p " .. p) end
mkdir(tmpdir)

local fail_count = 0
local function assert_eq(got, expected, msg)
    if got ~= expected then
        io.stderr:write(("FAIL: %s (expected: %s, got: %s)\n"):format(msg, tostring(expected), tostring(got)))
        fail_count = fail_count + 1
    end
end

local function assert_ne(got, unexpected, msg)
    if got == unexpected then
        io.stderr:write(("FAIL: %s (unexpected: %s)\n"):format(msg, tostring(unexpected)))
        fail_count = fail_count + 1
    end
end

local function assert_true(v, msg)
    if not v then
        io.stderr:write(("FAIL: %s (expected true, got false)\n"):format(msg))
        fail_count = fail_count + 1
    end
end

local function assert_false(v, msg)
    if v then
        io.stderr:write(("FAIL: %s (expected false, got true)\n"):format(msg))
        fail_count = fail_count + 1
    end
end

print(ansi.green('\n---- [ FS.src / FS.cwd ] ----'))
assert_ne(fs.src, nil, "FS.src should not be nil")
assert_ne(fs.cwd, nil, "FS.cwd should not be nil")
assert_true(type(fs.src) == 'string', "FS.src should be a string")
assert_true(type(fs.cwd) == 'string', "FS.cwd should be a string")
print(('  src: %s'):format(fs.src))
print(('  cwd: %s'):format(fs.cwd))

print(ansi.green('\n---- [ FS.join ] ----'))
local joined = fs.join('a', 'b', 'c')
assert_eq(type(joined), 'string', "FS.join should return a string")
print(('  fs.join("a", "b", "c") => %s'):format(joined))

print(ansi.green('\n---- [ FS.mkdir / FS.test / FS.ls ] ----'))
local test_dir = fs.join(tmpdir, 'test_subdir')
local ok, err = fs.mkdir(test_dir)
assert_true(ok, ("FS.mkdir(%s) should succeed"):format(test_dir))
if not ok and err then
    print(('  mkdir note: %s'):format(tostring(err)))
end

assert_true(fs.test(test_dir, 'DIR'), ("FS.test(%s, 'DIR') should be true"):format(test_dir))
assert_true(fs.test(test_dir, 'EXIST'), ("FS.test(%s, 'EXIST') should be true"):format(test_dir))
assert_false(fs.test(test_dir, 'FILE'), ("FS.test(%s, 'FILE') should be false"):format(test_dir))

local files = fs.ls(tmpdir)
assert_true(type(files) == 'table', "FS.ls should return a table")
local found = false
for _, f in ipairs(files) do
    if f == 'test_subdir' then found = true end
end
assert_true(found, ("FS.ls(%s) should contain 'test_subdir'"):format(tmpdir))
print(('  ls: %s'):format(table.concat(files, ', ')))

print(ansi.green('\n---- [ FS.stat ] ----'))
local stat, err = fs.stat(test_dir)
if not stat then
    if err then print(('  stat note: %s'):format(tostring(err))) end
else
    assert_eq(type(stat), 'table', "FS.stat should return a table")
    print(('  stat.type: %s'):format(tostring(stat.type)))
    print(('  stat.size: %s'):format(tostring(stat.size)))
    assert_true(stat.type == 'DIR', ("FS.stat(%s).type should be 'DIR'"):format(test_dir))
end

print(ansi.green('\n---- [ FS.cp / FS.stat (file) ] ----'))
local src_file = fs.join(tmpdir, 'src.txt')
local dst_file = fs.join(tmpdir, 'dst.txt')
local f = assert(io.open(src_file, 'w'))
f:write('hello fs test')
f:close()

local ok_cp, err_cp = fs.cp(src_file, dst_file)
assert_true(ok_cp, ("FS.cp(%s, %s) should succeed"):format(src_file, dst_file))
if not ok_cp and err_cp then
    print(('  cp note: %s'):format(tostring(err_cp)))
end

assert_true(fs.test(dst_file, 'FILE'), ("FS.test(%s, 'FILE') should be true after cp"):format(dst_file))

local stat_f, err_f = fs.stat(dst_file)
if stat_f then
    assert_eq(stat_f.type, 'FILE', "stat of a file should have type 'FILE'")
    print(('  file size: %d'):format(stat_f.size))
end

print(ansi.green('\n---- [ FS.mv ] ----'))
local mv_src = fs.join(tmpdir, 'mv_src.txt')
local mv_dst = fs.join(tmpdir, 'mv_dst.txt')
local f2 = assert(io.open(mv_src, 'w'))
f2:write('move me')
f2:close()
assert_true(fs.test(mv_src, 'EXIST'), "mv_src should exist before move")

local ok_mv, err_mv = fs.mv(mv_src, mv_dst)
assert_true(ok_mv, ("FS.mv(%s, %s) should succeed"):format(mv_src, mv_dst))
if not ok_mv and err_mv then
    print(('  mv note: %s'):format(tostring(err_mv)))
end

assert_false(fs.test(mv_src, 'EXIST'), "mv_src should not exist after move")
assert_true(fs.test(mv_dst, 'EXIST'), "mv_dst should exist after move")

print(ansi.green('\n---- [ FS.find ] ----'))
local found_files = fs.find(tmpdir, '*.txt')
assert_true(type(found_files) == 'table', "FS.find should return a table")
print(('  find *.txt: found %d entries'):format(#found_files))
for _, entry in ipairs(found_files) do
    print(('    %s'):format(entry))
end

print(ansi.green('\n---- [ FS.rm ] ----'))
local rm_file = fs.join(tmpdir, 'to_remove.txt')
local f3 = assert(io.open(rm_file, 'w'))
f3:write('remove me')
f3:close()
assert_true(fs.rm(rm_file), ("FS.rm(%s) should succeed"):format(rm_file))
assert_false(fs.test(rm_file, 'EXIST'), ("%s should not exist after rm"):format(rm_file))

local rm_arr_ok = fs.rm({ dst_file, mv_dst })
assert_true(rm_arr_ok, "FS.rm with array should succeed")
assert_false(fs.test(dst_file, 'EXIST'), "dst_file should be removed")
assert_false(fs.test(mv_dst, 'EXIST'), "mv_dst should be removed")

-- clean up
fs.rm(tmpdir)

if fail_count > 0 then
    io.stderr:write(('FAILED: %d test(s) failed\n'):format(fail_count))
    os.exit(1)
end

print(ansi.green('\n---- [ All FS tests passed ] ----'))
