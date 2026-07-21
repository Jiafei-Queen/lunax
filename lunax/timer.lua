--- lunax.timer
--- 跨平台休眠与系统级定时任务调度模块
---  - Windows : schtasks + /RI（秒级精度）
---  - Linux   : systemd timer（秒级精度）
---  - macOS   : launchd（秒级精度）
---  - 其他    : at / crontab（分钟级，兼容后备）

local OS = require('lunax.os_prober')
local exec = require('lunax.exec')

local timer = {}

-- ==========================================
-- 内部工具
-- ==========================================

local function gen_id()
    return "Lunax_" .. os.date("%Y%m%d%H%M%S") .. "_" .. tostring(math.random(1000, 9999))
end

local function write_file(path, content)
    local f, err = io.open(path, "w")
    if not f then return false, err end
    f:write(content)
    f:close()
    return true
end

local function xml_escape(s)
    return s:gsub("&", "&amp;")
            :gsub("<", "&lt;")
            :gsub(">", "&gt;")
            :gsub('"', "&quot;")
            :gsub("'", "&apos;")
end

local function sh_quote(s)
    return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function sec_to_hhmmss(s)
    local h = math.floor(s / 3600)
    local m = math.floor((s % 3600) / 60)
    local sec = s % 60
    return string.format("%02d:%02d:%02d", h, m, sec)
end

-- ==========================================
-- 1. 休眠
-- ==========================================

function timer.sleep(sec)
    if sec <= 0 then return end
    if OS == 'NT' then
        local ms = math.floor(sec * 1000)
        exec("ping 127.0.0.1 -n 1 -w " .. tostring(ms), {
            stdout = false, stderr = false
        })
    else
        os.execute("sleep " .. tostring(sec))
    end
end

-- ==========================================
-- 2. 系统级任务调度
--    delay : 初始延迟 / 重复间隔（秒）
--    freq  : 执行次数（1=单次，<=0 无限，>1 循环 N 次）
-- ==========================================

function timer.sch(delay, cmd, freq)
    local id = gen_id()
    if freq == nil then freq = 1 end

    if OS == 'NT' then
        timer._sch_windows(id, delay, cmd, freq)
    elseif OS == 'Linux' then
        timer._sch_linux(id, delay, cmd, freq)
    elseif OS == 'Darwin' then
        timer._sch_macos(id, delay, cmd, freq)
    else
        timer._sch_unix_fallback(id, math.ceil(delay / 60), cmd, freq)
    end
    return id
end

-- ========================
-- Windows 内部
-- ========================

function timer._sch_windows_once(id, delay, cmd)
    local target = os.time() + delay
    local st = os.date("%H:%M", target)
    local sec_off = target % 60
    local tr
    if sec_off > 0 then
        tr = string.format("cmd /c timeout /t %d /nobreak >nul 2>&1 && %s", sec_off, cmd)
    else
        tr = cmd
    end
    os.execute(string.format(
        'schtasks /create /tn "%s" /tr "%s" /sc once /st %s /f >nul 2>&1',
        id, tr, st
    ))
end

function timer._sch_windows_loop(id, interval, cmd)
    local now = os.time()
    local st = os.date("%H:%M", math.floor(now / 60) * 60 + 60)
    local ri = sec_to_hhmmss(interval)
    os.execute(string.format(
        'schtasks /create /tn "%s" /tr "%s" /sc once /st %s /ri %s /du 24:00:00 /f >nul 2>&1',
        id, cmd, st, ri
    ))
end

function timer._sch_windows(id, delay, cmd, freq)
    if freq == 1 then
        timer._sch_windows_once(id, delay, cmd)
    elseif freq <= 0 then
        timer._sch_windows_loop(id, delay, cmd)
    else
        for i = 1, freq do
            timer._sch_windows_once(id .. "__" .. i, delay * i, cmd)
        end
    end
end

-- ========================
-- Linux 内部
-- ========================

function timer._sch_linux(id, delay, cmd, freq)
    local shell = "bash -c " .. sh_quote(cmd)

    if freq == 1 then
        local unit = "lunax-" .. id
        exec("systemd-run --user --on-active=" .. delay .. "s --unit=" .. unit .. " " .. shell,
             { stdout = false, stderr = false })
    elseif freq <= 0 then
        local unit = "lunax-" .. id
        exec("systemd-run --user --on-unit-active=" .. delay .. "s --unit=" .. unit .. " " .. shell,
             { stdout = false, stderr = false })
    else
        for i = 1, freq do
            local sub = id .. "__" .. i
            local unit = "lunax-" .. sub
            exec("systemd-run --user --on-active=" .. (delay * i) .. "s --unit=" .. unit .. " " .. shell,
                 { stdout = false, stderr = false })
        end
    end
end

-- ========================
-- macOS 内部
-- ========================

function timer._sch_macos_once(id, delay, cmd)
    local plist = "/tmp/" .. id .. ".plist"
    local safe_cmd = xml_escape(cmd)
    local content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>%s</string>
    <key>ProgramArguments</key>
    <array>
        <string>sh</string>
        <string>-c</string>
        <string>sleep %d &amp;&amp; %s</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>LaunchOnlyOnce</key>
    <true/>
    <key>KeepAlive</key>
    <false/>
</dict>
</plist>
]], xml_escape(id), delay, safe_cmd)
    write_file(plist, content)
    os.execute("launchctl load " .. plist .. " 2>/dev/null")
end

function timer._sch_macos_loop(id, interval, cmd)
    local plist = "/tmp/" .. id .. ".plist"
    local safe_cmd = xml_escape(cmd)
    local content = string.format([[
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>%s</string>
    <key>ProgramArguments</key>
    <array>
        <string>sh</string>
        <string>-c</string>
        <string>%s</string>
    </array>
    <key>StartInterval</key>
    <integer>%d</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
]], xml_escape(id), safe_cmd, interval)
    write_file(plist, content)
    os.execute("launchctl load " .. plist .. " 2>/dev/null")
end

function timer._sch_macos(id, delay, cmd, freq)
    if freq == 1 then
        timer._sch_macos_once(id, delay, cmd)
    elseif freq <= 0 then
        timer._sch_macos_loop(id, delay, cmd)
    else
        for i = 1, freq do
            timer._sch_macos_once(id .. "__" .. i, delay * i, cmd)
        end
    end
end

-- ========================
-- 后备：at / crontab（分钟级）
-- ========================

function timer._sch_unix_fallback(id, delay_min, cmd, freq)
    if freq == 1 then
        local at_cmd = string.format('echo %s | at now + %d minutes 2>/dev/null', sh_quote(cmd), delay_min)
        os.execute(at_cmd)
    elseif freq <= 0 then
        local cron = string.format("*/%d * * * * %s # %s", delay_min, cmd, id)
        os.execute(string.format('(crontab -l 2>/dev/null; echo %s) | crontab -', sh_quote(cron)))
    else
        for i = 1, freq do
            local sub = id .. "__" .. i
            local at_cmd = string.format('echo %s | at now + %d minutes 2>/dev/null', sh_quote(cmd), delay_min * i)
            os.execute(at_cmd)
        end
    end
end

-- ==========================================
-- 3. 移除指定系统任务
-- ==========================================

function timer.remove(id)
    if not id or id == "" then return false end

    if OS == 'NT' then
        os.execute(string.format('schtasks /delete /tn "%s" /f >nul 2>&1', id))
        os.execute(string.format([[
powershell -NoProfile -Command "& {
    Get-ScheduledTask -TaskName '%s__*' 2>$null | Unregister-ScheduledTask -Confirm:$false 2>$null
}"]], id))
        return true
    elseif OS == 'Linux' then
        local function stop_unit(u)
            os.execute("systemctl --user stop " .. u .. ".timer 2>/dev/null")
            os.execute("systemctl --user stop " .. u .. ".service 2>/dev/null")
            os.execute("systemctl --user reset-failed " .. u .. ".timer 2>/dev/null")
            os.execute("systemctl --user reset-failed " .. u .. ".service 2>/dev/null")
        end
        stop_unit("lunax-" .. id)
        os.execute(string.format([[
for unit in $(systemctl --user list-units --all 'lunax-%s__*' --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl --user stop "$unit" 2>/dev/null
    systemctl --user reset-failed "$unit" 2>/dev/null
done
]], id))
        return true
    elseif OS == 'Darwin' then
        local plist = "/tmp/" .. id .. ".plist"
        os.execute("launchctl unload " .. plist .. " 2>/dev/null")
        os.execute("rm -f " .. plist)
        os.execute(string.format([[
for plist in /tmp/%s__*.plist; do
    [ -f "$plist" ] && launchctl unload "$plist" 2>/dev/null && rm -f "$plist"
done
]], id))
        return true
    else
        os.execute(string.format('crontab -l 2>/dev/null | grep -v "# %s" | crontab -', id))
        return true
    end
end

-- ==========================================
-- 4. 清除所有 Lunax 创建的任务
-- ==========================================

function timer.clear()
    if OS == 'NT' then
        os.execute([[
powershell -NoProfile -Command "& {Get-ScheduledTask -TaskName 'Lunax_*' 2>$null | Unregister-ScheduledTask -Confirm:$false 2>$null}"
]])
    elseif OS == 'Linux' then
        os.execute([[
for unit in $(systemctl --user list-units --all 'lunax-*' --no-legend 2>/dev/null | awk '{print $1}'); do
    systemctl --user stop "$unit" 2>/dev/null
    systemctl --user reset-failed "$unit" 2>/dev/null
done
]])
    elseif OS == 'Darwin' then
        os.execute([[
for plist in /tmp/Lunax_*.plist; do
    [ -f "$plist" ] && launchctl unload "$plist" 2>/dev/null && rm -f "$plist"
done
]])
    else
        os.execute('crontab -l 2>/dev/null | grep -v "# Lunax_" | crontab -')
    end
end

return timer