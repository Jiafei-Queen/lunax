# `lunax.tty` — 终端尺寸获取

轻量终端信息模块，目前提供获取当前终端行列数（字符尺寸）的能力。内部通过系统命令查询，自动适配 Unix / Windows。

## 导入

```lua
local tty = require("lunax.tty")
```

---

## `tty.term_size()`

查询当前终端（TTY）的行数与列数。

### 返回值

| 返回值 | 类型 | 说明 |
|--------|------|------|
| `rows` | number / nil | 行数（终端高度），失败时为 `nil` |
| `cols` | number / nil | 列数（终端宽度），失败时为 `nil` |

```lua
local rows, cols = tty.term_size()
if rows and cols then
    print("终端尺寸:", cols .. "x" .. rows)  -- 例如 "120x40"
end
```

### 跨平台说明

- **Unix:** 调用 `stty size < /dev/tty`，解析输出的 `<rows> <cols>`
- **Windows:** 调用 `mode`，解析 `Lines:` 与 `Columns:` 字段

### 使用注意

- 需要**控制终端（controlling terminal）**才能查询成功：
  - Unix 下依赖 `/dev/tty` 可读，在后台进程、管道或无 TTY 的调度环境（如 cron、CI）中可能无法访问
  - Windows 下依赖控制台输出重定向为 `mode` 的文本
- 查询失败时返回 `nil`，调用方应做好空值判断，避免直接 `tonumber` 崩溃

---

## 完整示例

```lua
local tty = require("lunax.tty")

local rows, cols = tty.term_size()
if not rows or not cols then
    print("无法获取终端尺寸（可能没有 TTY）")
    return
end

-- 依据终端宽度绘制分隔线
local width = cols
print(string.rep("=", width))
```

---

## 相关模块

- [`lunax.ansi`](ansi.md)：终端彩色输出
- [`lunax.rl`](rl.md)：命令行读取
