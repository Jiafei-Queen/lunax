# `lunax.timer` — 休眠与系统级任务调度

跨平台休眠与定时任务调度模块，自动适配底层系统能力：

| 平台 | 单次 / 有限次 | 无限循环 |
|------|--------------|----------|
| Windows | `schtasks + timeout`（秒级） | `schtasks /once /ri /du`（秒级） |
| Linux   | `systemd-run --on-active`（秒级） | `systemd-run --on-unit-active`（秒级） |
| macOS   | launchd plist + `sleep`（秒级） | launchd plist + `StartInterval`（秒级） |
| 其他    | `at` 命令（分钟级） | crontab（分钟级） |

## 导入

```lua
local timer = require("lunax.timer")
```

---

## `timer.sleep(sec)`

阻塞当前进程，休眠指定秒数。

| 参数 | 类型 | 说明 |
|------|------|------|
| `sec` | number | 休眠秒数，`<= 0` 时立即返回 |

```lua
timer.sleep(3)     -- 休眠 3 秒
timer.sleep(0.5)   -- 休眠 0.5 秒
```

**实现：**
- **Windows:** 使用 `ping -n 1 -w <ms> 127.0.0.1`，精度毫秒级
- **Unix:** 使用 `sleep <sec>` 命令

---

## `timer.sch(delay, cmd, [freq])`

注册一个系统级定时任务。返回任务 ID，可用于后续 `timer.remove(id)`。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `delay` | number | 初始延迟（秒）。也是重复执行时的间隔 |
| `cmd`   | string | 要执行的命令（将在 shell 中运行） |
| `freq`  | number / nil | 执行次数。默认 `1`（单次） |

### freq 语义

| 值 | 行为 |
|----|------|
| `nil` 或 `1` | 执行一次（延迟 `delay` 秒后） |
| `0` 或负数 | 无限循环，每 `delay` 秒执行一次 |
| `> 1` | 循环 N 次，第 i 次在 `delay × i` 秒后执行 |

### 返回值

返回生成的 ID（字符串），格式为 `Lunax_YYYYMMDDHHMMSS_RAND`。

```lua
-- 10 秒后执行一次
local id = timer.sch(10, "notify-send 'hello'")

-- 每 5 秒执行一次，无限循环
local id = timer.sch(5, "echo 'tick'", 0)

-- 每 30 秒执行一次，共 3 次（第 30s、60s、90s）
local id = timer.sch(30, "curl http://health-check", 3)
```

### 跨平台说明

- **Windows:** 借助 `timeout` 命令实现秒级偏移；无限循环时使用 `/sc once /ri HH:mm:ss /du 24:00:00`。对于同分钟内的短延迟（< 60s），实际执行时间可能有数秒的调度误差
- **Linux  / macOS:** 使用 `systemd-run` / launchd 原生支持秒级精度
- **其他 Unix:** 使用 `at`（有限次）/ crontab（无限循环），仅分钟级精度

---

## `timer.remove(id)`

移除指定 ID 的定时任务（包括 `freq > 1` 产生的所有子任务）。

| 参数 | 类型 | 说明 |
|------|------|------|
| `id` | string | `timer.sch` 返回的任务 ID |

```lua
local id = timer.sch(10, "echo 'hi'", 5)
-- 在任务执行完之前取消它
timer.remove(id)
```

**实现：**
- **Windows:** `schtasks /delete` + PowerShell 通配删除 `id__*` 子任务
- **Linux:** `systemctl --user stop lunax-<id>.*` + 通配匹配 `lunax-<id>__*.{timer,service}`
- **macOS:** `launchctl unload /tmp/<id>.plist` + 通配删除 `/tmp/<id>__*.plist`
- **其他:** crontab 按 ID 注释行过滤删除（`at` 任务无法取消）

---

## `timer.clear()`

移除所有由 `lunax.timer` 创建的定时任务（ID 以 `Lunax_` 开头）。

```lua
timer.clear()  -- 清理所有 Lunax 任务
```

**实现：**
- **Windows:** PowerShell `Get-ScheduledTask -TaskName 'Lunax_*' \| Unregister-ScheduledTask`
- **Linux:** 遍历 `systemctl --user list-units 'lunax-*'` 逐个 `stop` + `reset-failed`
- **macOS:** 遍历 `/tmp/Lunax_*.plist` 逐个 `launchctl unload` 并删除
- **其他:** crontab 按 `# Lunax_` 标签过滤

---

## 完整示例

```lua
local timer = require("lunax.timer")

-- 单次：5 秒后弹窗
timer.sch(5, "notify-send 'Time is up!'")

-- 无限循环：每 2 秒写一条日志
local log_id = timer.sch(2, "echo '$(date): running' >> /tmp/daemon.log", 0)

-- 有限次：每 10 秒检查一次，共 6 次（1 分钟）
local check_id = timer.sch(10, "curl -s http://localhost:8080/health", 6)

-- 取消任务
timer.remove(log_id)
```
