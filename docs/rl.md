# `lunax.rl` — Readline 输入

简单交互式输入函数，底层调用 Bash 的 `read -e` 实现行编辑（方向键、历史、Tab 补全等）。  
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

用户按下 `Ctrl+D` 或 `Ctrl+C` 时会抛出错误，可使用 `pcall` 捕获：

```lua
local ok, result = pcall(readline, "> ")
if ok then
    print("输入:", result)
else
    print("用户取消输入")
end
```

### 关于行编辑能力

由于底层使用 `read -e`，天然支持：

- 左右方向键移动光标
- 上下方向键浏览历史
- Tab 键文件名补全
- Ctrl+W 删除单词等 Readline 快捷键
