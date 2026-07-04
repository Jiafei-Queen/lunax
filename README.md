# Lunax
一个纯 Lua 实现，在 Unix（包括 MSYS2）环境下，封装系统工具和 Shell（sh, bash）操作的库

## 快速开始

### 配置环境

```bash
lua -v  # 应输出 `Lua 5.4.x ...`
```

（Windows 用户需要 MSYS2 环境，最好使用 `pacman -S lua5.4` 安装 Lua）

```bash
# 克隆仓库
git clone https://github.com/Jiafei-Queen/lunax <path>

# 配置 LUA_PATH
export LUA_PATH="<path>/?.lua;;"
```

### 使用示例

```lua
--- [ 列出当前目录下的隐藏条目 ] ---
local fs = require('lunax.fs')

for _,entry in ipairs(fs.ls()) do
    if entry:sub(1, 1) == '.' then
        print(entry)
    end
end
```
