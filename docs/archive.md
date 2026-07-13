# `lunax.archive` — 文件打包与解压

压缩/解压缩模块，支持 zip 格式的打包与解包。基于 `lunax.popen` 实现，跨平台兼容 Unix 与 Windows。

## 导入

```lua
local archive = require("lunax.archive")
```

## `Archive.zip(src, dst)`

创建 zip 压缩包。

| 参数 | 类型 | 说明 |
|------|------|------|
| `src` | string \| string[] | 源路径字符串，或字符串数组（多个文件） |
| `dst` | string | 可选，目标 zip 文件路径。当 `src` 为字符串时，默认为 `src..'.zip'`；`src` 为数组时必须提供 |

### 返回值

成功返回 `true`，失败返回 `nil, error_message`。

### 示例

```lua
local archive = require("lunax.archive")

-- 压缩单个目录
local ok = archive.zip("myproject/")
if ok then
    print("已打包: myproject.zip")
end

-- 压缩多个文件
local ok, err = archive.zip({ "file1.txt", "file2.txt", "docs/" }, "backup.zip")
if not ok then
    print("打包失败:", err)
end
```

### 底层命令

- **Unix:** `zip -q -r <dst> <src>`
- **Windows:** `powershell Compress-Archive -Path <src> -DestinationPath <dst> -Force`

错误消息会自动去除 OS 特定前缀（`zip error:` / `Compress-Archive:`）。

## `Archive.unzip(src, dst)`

解压 zip 文件。

| 参数 | 类型 | 说明 |
|------|------|------|
| `src` | string | zip 文件路径 |
| `dst` | string | 可选，目标目录（默认 `"."`） |

### 返回值

成功返回 `true`，失败返回 `false, error_message`。

### 示例

```lua
local archive = require("lunax.archive")

-- 解压到当前目录
local ok = archive.unzip("backup.zip")
if ok then
    print("解压完成")
end

-- 解压到指定目录
local ok, err = archive.unzip("backup.zip", "restore/")
if not ok then
    print("解压失败:", err)
end
```

### 底层命令

- **Unix:** `unzip -q <src> -d <dst>`
- **Windows:** `powershell Expand-Archive -Path '<src>' -DestinationPath '<dst>' -Force`

错误消息会自动去除 OS 特定前缀（`unzip error:` / `Expand-Archive:`）。

### 错误处理

参数类型不匹配时抛出错误：

```
bad argument #1 to 'zip' (string expected, got table)
bad argument #1 to 'unzip' (string expected, got number)
```
