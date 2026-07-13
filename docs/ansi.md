# `lunax.ansi` — ANSI Terminal Control

ANSI 终端转义码模块，支持样式、颜色（含 TrueColor）、光标控制与终端缓冲区切换。  
自动检测 stdout 是否为 TTY（通过 `io.popen("test -t 1")`），非终端环境下所有输出降级为空字符串，避免污染管道或文件。

| 属性 | 类型 | 说明 |
|------|------|------|
| `.is_tty` | boolean | 当前 stdout 是否为真正的终端 |

## 导入

```lua
local ansi = require("lunax.ansi")
```

## 控制标记（字符串常量）

| 字段 | 说明 |
|------|------|
| `.reset` | 重置所有样式 |
| `.clear` | 清屏并复位光标 |
| `.clear_line` | 清除当前行 |
| `.move_line_top` | 移动光标到当前行首 |
| `.hide_cursor` | 隐藏光标 |
| `.show_cursor` | 显示光标 |
| `.save_cursor` | 保存光标位置 |
| `.restore_cursor` | 恢复光标位置 |
| `.enter_alt_bg` | 进入备用缓冲区（类似 vim 全屏） |
| `.exit_alt_bg` | 退出备用缓冲区 |

### 示例

```lua
io.write(ansi.clear)          -- 清屏
io.write(ansi.hide_cursor)    -- 隐藏光标
io.write(ansi.show_cursor)    -- 恢复光标
io.write(ansi.move_line_top)  -- 回到行首
```

## 光标移动函数

| 函数 | 说明 |
|------|------|
| `.move_to(row, col)` | 移动光标到指定行列（默认 1,1） |
| `.cursor_up(n)` | 光标上移 n 行（默认 1） |
| `.cursor_down(n)` | 光标下移 n 行（默认 1） |
| `.cursor_right(n)` | 光标右移 n 列（默认 1） |
| `.cursor_left(n)` | 光标左移 n 列（默认 1） |

### 示例

```lua
io.write(ansi.move_to(10, 5))     -- 移动到第 10 行第 5 列
io.write(ansi.cursor_up(3))       -- 上移 3 行
io.write(ansi.cursor_right(2))    -- 右移 2 列
```

## TrueColor（RGB 函数）

每个函数返回一个 **闭包**，接收文本并返回包裹后的字符串（自动追加 reset）。

| 函数 | 说明 |
|------|------|
| `.rgb(r, g, b)` | 设置 24 位前景色 |
| `.bg_rgb(r, g, b)` | 设置 24 位背景色 |

### 示例

```lua
print(ansi.rgb(255, 100, 50)("Hello"))      -- 橙色前景
print(ansi.bg_rgb(30, 30, 30)("Dark bg"))   -- 深色背景
```

## 样式与颜色快捷调用（元表）

通过元表（`__index`）支持函数式调用，直接包裹文本。可用名称：

- **样式：** `bold`, `dim`, `italic`, `underline`, `blink`, `reverse`, `hidden`, `strikethrough`
- **前景色：** `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`
- **背景色：** `bg_black`, `bg_red`, `bg_green`, `bg_yellow`, `bg_blue`, `bg_magenta`, `bg_cyan`, `bg_white`

所有函数在非 TTY 环境下直接返回 `tostring(text)`，不做任何修饰。

### 示例

```lua
print(ansi.red("错误信息"))
print(ansi.bold(ansi.green("成功")))
print(ansi.underline("下划线文本"))
print(ansi.bg_red("红底白字效果"))
print(ansi.bold(ansi.italic(ansi.blue("混合样式"))))
```

## 完整示例

```lua
local ansi = require("lunax.ansi")

-- 清屏
io.write(ansi.clear)

-- 色彩与样式组合
print(ansi.bold(ansi.rgb(255, 200, 0)("Lunax")))
print(ansi.underline("配置文件已加载") .. " " .. ansi.green("✓"))
print(ansi.red("✗") .. " 连接失败")
print(ansi.dim("这是次要信息"))

-- 光标保存与恢复
io.write(ansi.save_cursor)
io.write(ansi.move_to(1, 1))
print(ansi.reverse("顶部标题"))
io.write(ansi.restore_cursor)
```
