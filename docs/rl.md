# `lunax.rl` — Readline 输入

交互式行输入函数。底层优先使用 [linenoise](https://github.com/antirez/linenoise)（需额外安装），回退到 Bash `read -e` 实现行编辑。  
需在真正的终端中运行。

## 导入

```lua
local readline = require("lunax.rl")
```

## `readline([prompt])`

显示提示符并等待用户输入，返回输入的字符串（不含换行符）。  
`prompt` 可选，默认为空。

### 示例

```lua
local name = readline("请输入姓名: ")
print("你好, " .. name)

local age = readline("年龄: ")
print("年龄: " .. age)
```

交互效果：

```
请输入姓名: Jiafei
你好, Jiafei
```

### 错误处理

用户按下 `Ctrl+D`（EOF）或 `Ctrl+C`（SIGINT）时，函数会打印换行并返回 `nil`，不再抛出错误：

```lua
local result = readline("> ")
if result then
    print("输入:", result)
else
    print("用户取消输入")
end
```

### 可选依赖

- [linenoise](https://github.com/antirez/linenoise) — 提供更轻量的行编辑支持（方向键、历史记录），推荐安装

### 关于行编辑能力

底层使用 `read -e`（或 linenoise），天然支持：

- 左右方向键移动光标
- Ctrl+W 删除单词等 Readline 快捷键
