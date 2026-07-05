# Lunax

一个纯 Lua 实现，在 Unix（包括 MSYS2）环境下，封装系统工具和 Shell（sh, bash）操作的库。

## 模块

| 模块 | 说明 |
|------|------|
| [`lunax.fs`](docs/fs.md) | 文件系统操作 — `ls`、`mkdir`、`rm`、`cp`、`mv`、`find`、`stat` 等，可选 lfs 加速 |
| [`lunax.rl`](docs/rl.md) | 交互式 Readline 输入 — 支持方向键、历史记录，可选 linenoise |
| [`lunax.ansi`](docs/ansi.md) | ANSI 终端控制 — 颜色（含 TrueColor）、样式、光标移动、缓冲区切换 |
| [`lunax.logger`](docs/logger.md) | 彩色日志 — 多级别日志、级别过滤、Table 自动展开 |
| [`lunax.util`](docs/util.md) | 通用工具 — 格式化输出 `dump`、字符串 `trim`/`split`、深度 `clone`、字节格式化 `hsz` |
| [`lunax.json`](docs/json.md) | JSON 编码/解码 — 可选 lua-cjson，回退 dkjson |

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
