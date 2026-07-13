local popen = require('lunax.popen')
local exec = require('lunax.exec')
local fs = require('lunax.fs')
local ansi = require('lunax.ansi')
local logger = require('lunax.logger')
local unix = require('lunax.os_prober') ~= 'NT'

local exit_code = 0
local tmpdir

print(ansi.green('\n---- [ POPEN Test ] ----'))

-- 清理函数
local function cleanup()
    if tmpdir then fs.rm(tmpdir) end
end

-- 创建临时工作目录
do
    tmpdir = os.tmpname()
    fs.rm(tmpdir)
    fs.mkdir(tmpdir)
end

do  -- 1. 基本读取（字符串命令）
    print(ansi.green('\n--> 1. Basic Read (string cmd)'))
    local handle = popen(unix and 'echo hello popen' or 'echo hello popen')
    local out = handle:read('*l')
    local exit = handle:close()

    if not exit.ok then
        logger.error('basic-read', 'close.ok should be true')
        exit_code = 1; goto test_table_cmd
    end
    if exit.code ~= 0 then
        logger.error('basic-read', ('close.code should be 0, got %d'):format(exit.code))
        exit_code = 1; goto test_table_cmd
    end
    if out ~= 'hello popen' then
        logger.error('basic-read', ('output mismatch: got %q'):format(tostring(out)))
        exit_code = 1; goto test_table_cmd
    end
    logger.info('basic-read', '\t..OK')

    -- 验证 close 返回结构
    if type(exit) ~= 'table' then
        logger.error('basic-read', 'close must return table')
        exit_code = 1; goto test_table_cmd
    end
    if exit.ext ~= nil and type(exit.ext) ~= 'string' then
        logger.error('basic-read', ('ext must be string or nil, got %s'):format(type(exit.ext)))
        exit_code = 1; goto test_table_cmd
    end
    if type(exit.code) ~= 'number' then
        logger.error('basic-read', ('code must be number, got %s'):format(type(exit.code)))
        exit_code = 1
    end
end

:: test_table_cmd ::
do  -- 2. 数组命令（每个元素是一条完整命令，自动拼接）
    print(ansi.green('\n--> 2. Table Array Cmd'))
    local handle = popen(unix and { 'echo first', 'echo second' } or { 'echo first', 'echo second' })
    local out = handle:read('*a')
    local exit = handle:close()

    if not exit.ok then
        logger.error('table-cmd', 'close.ok should be true')
        exit_code = 1; goto test_close_fail
    end
    if not out:match('first') or not out:match('second') then
        logger.error('table-cmd', ('should contain both first and second, got: %q'):format(out))
        exit_code = 1; goto test_close_fail
    end
    logger.info('table-cmd', '\t..OK')
end

:: test_close_fail ::
do  -- 3. close 返回失败退出码
    print(ansi.green('\n--> 3. Close Returns Failure Code'))
    local handle = popen(unix and 'exit 42' or 'exit /b 42')
    handle:read('*a')
    local exit = handle:close()

    if exit.ok ~= false then
        logger.error('close-fail', 'exit.ok should be false')
        exit_code = 1; goto test_cwd
    end
    if exit.code ~= 42 then
        logger.error('close-fail', ('exit.code should be 42, got %d'):format(exit.code))
        exit_code = 1; goto test_cwd
    end
    logger.info('close-fail', ('\t..OK (code=%d)'):format(exit.code))
end

:: test_cwd ::
do  -- 4. 工作目录
    print(ansi.green('\n--> 4. Working Directory (cwd)'))
    local handle
    if unix then
        handle = popen('pwd', { cwd = tmpdir })
    else
        handle = popen('cd', { cwd = tmpdir })
    end
    local out = handle:read('*l')
    local exit = handle:close()

    if not exit.ok then
        logger.error('cwd', 'close.ok should be true')
        exit_code = 1; goto test_env
    end
    if unix then
        if out ~= tmpdir then
            logger.error('cwd', ('cwd mismatch: expected %q, got %q'):format(tmpdir, out))
            exit_code = 1; goto test_env
        end
    end
    logger.info('cwd', '\t..OK')
end

:: test_env ::
do  -- 5. 环境变量
    print(ansi.green('\n--> 5. Environment Variables (env)'))
    local handle
    if unix then
        handle = popen('echo $MY_VAR', { env = { MY_VAR = 'hello env' } })
    else
        handle = popen('echo %MY_VAR%', { env = { MY_VAR = 'hello env' } })
    end
    local out = handle:read('*l')
    local exit = handle:close()

    if not exit.ok then
        logger.error('env', 'close.ok should be true')
        exit_code = 1; goto test_stderr
    end
    if out ~= 'hello env' then
        logger.error('env', ('env mismatch: expected hello env, got %q'):format(tostring(out)))
        exit_code = 1; goto test_stderr
    end
    logger.info('env', '\t..OK')
end

:: test_stderr ::
do  -- 6. stderr 合并到 stdout（stderr = true）
    print(ansi.green('\n--> 6. Stderr Merge (stderr=true)'))
    local handle
    if unix then
        handle = popen('echo out1; echo err1 >&2', { stderr = true })
    else
        -- Windows fallback
        handle = popen('echo out1 & echo err1 1>&2', { stderr = true })
    end
    local out = handle:read('*a')
    local exit = handle:close()

    if not exit.ok then
        logger.error('stderr-merge', 'close.ok should be true')
        exit_code = 1; goto test_stdout_discard
    end
    -- stderr merged into stdout; both should appear in output
    if not out:match('out1') or not out:match('err1') then
        logger.error('stderr-merge', ('should contain both out1 and err1, got: %q'):format(out))
        exit_code = 1; goto test_stdout_discard
    end
    logger.info('stderr-merge', '\t..OK')
end

:: test_stdout_discard ::
do  -- 7. 丢弃 stdout（stdout = false）
    print(ansi.green('\n--> 7. Discard Stdout (stdout=false)'))
    local handle = popen(unix and 'echo should be discarded' or 'echo should be discarded', { stdout = false })
    local out = handle:read('*a')
    local exit = handle:close()

    if not exit.ok then
        logger.error('stdout-discard', 'close.ok should be true')
        exit_code = 1; goto test_lines
    end
    if out ~= '' then
        logger.error('stdout-discard', ('stdout should be empty, got: %q'):format(out))
        exit_code = 1; goto test_lines
    end
    logger.info('stdout-discard', '\t..OK')
end

:: test_lines ::
do  -- 8. lines() 迭代
    print(ansi.green('\n--> 8. Lines Iteration'))
    local handle = popen(unix and 'printf "a\\nb\\nc"' or 'echo a & echo b & echo c')
    local count = 0
    for _ in handle:lines() do count = count + 1 end
    local exit = handle:close()

    if not exit.ok then
        logger.error('lines', 'close.ok should be true')
        exit_code = 1; goto test_read_all
    end
    if unix and count ~= 3 then
        logger.error('lines', ('expected 3 lines, got %d'):format(count))
        exit_code = 1; goto test_read_all
    end
    logger.info('lines', ('\t..OK (%d lines)'):format(count))
end

:: test_read_all ::
do  -- 9. read('*a') 读取全部
    print(ansi.green('\n--> 9. Read All (*a)'))
    local handle = popen(unix and 'echo line1; echo line2' or 'echo line1 & echo line2')
    local out = handle:read('*a')
    local exit = handle:close()

    if not exit.ok then
        logger.error('read-all', 'close.ok should be true')
        exit_code = 1; goto test_null_conf
    end
    if not out:match('line1') or not out:match('line2') then
        logger.error('read-all', ('should contain both lines, got: %q'):format(out))
        exit_code = 1
    end
    logger.info('read-all', '\t..OK')
end

:: test_null_conf ::
do  -- 10. conf = nil 正常运行
    print(ansi.green('\n--> 10. Null Config'))
    local handle = popen(unix and 'echo null conf' or 'echo null conf', nil)
    local out = handle:read('*l')
    local exit = handle:close()

    if not exit.ok or out ~= 'null conf' then
        logger.error('null-conf', 'should work with nil conf')
        exit_code = 1; goto test_type_err
    end
    logger.info('null-conf', '\t..OK')
end

:: test_type_err ::
do  -- 11. 参数类型错误应抛出 error
    print(ansi.green('\n--> 11. Type Error Checking'))
    local ok1, err1 = pcall(popen, { key = 'val' })
    if ok1 then
        logger.error('type-err', 'popen(map) should error')
        exit_code = 1
    else
        logger.info('type-err', ('\t..OK map err: %s'):format(err1))
    end

    local ok2, err2 = pcall(popen, 'echo hi', { cwd = 42 })
    if ok2 then
        logger.error('type-err', 'popen(_, {cwd=42}) should error')
        exit_code = 1
    else
        logger.info('type-err', ('\t..OK cwd err: %s'):format(err2))
    end

    local ok3, err3 = pcall(popen, 'echo hi', { env = 'bad' })
    if ok3 then
        logger.error('type-err', 'popen(_, {env=\"bad\"}) should error')
        exit_code = 1
    else
        logger.info('type-err', ('\t..OK env err: %s'):format(err3))
    end
end

-- 清理
cleanup()
os.exit(exit_code)
