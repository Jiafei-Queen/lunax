# `lunax.hash` — 哈希计算

哈希计算模块，支持文件哈希、内存对象哈希以及内置 Adler32 / CRC32 算法。文件哈希通过系统命令实现，对象哈希通过临时文件配合系统工具处理。

## 导入

```lua
local hash = require("lunax.hash")
```

## 文件哈希

对文件计算哈希值，返回哈希字符串。

| 函数 | 说明 |
|------|------|
| `.md5_file(path)` | 计算文件 MD5 |
| `.sha256_file(path)` | 计算文件 SHA256 |
| `.sha512_file(path)` | 计算文件 SHA512 |

```lua
local md5 = hash.md5_file("/path/to/file.iso")
if md5 then
    print("MD5:", md5)
end

local sha256 = hash.sha256_file("package.tar.gz")
print("SHA256:", sha256)
```

失败时返回 `false` 及错误信息：

```lua
local ok, err = hash.md5_file("nonexistent.txt")
if not ok then
    print("错误:", err)
end
```

## 字符串哈希

对内存中的字符串数组计算哈希值。输入必须为纯数组 table（连续整数索引），每个元素会被 `tostring` 转换后独立计算哈希，返回哈希值数组。

| 函数 | 说明 |
|------|------|
| `.md5_buf(input)` | 计算字符串数组 MD5 |
| `.sha256_buf(input)` | 计算字符串数组 SHA256 |
| `.sha512_buf(input)` | 计算字符串数组 SHA512 |

```lua
local results = hash.sha256_buf({ "foo", "bar", "baz" })
-- {
--   [1] = "2c26b46b68ffc68ff99b453c1d30413413422d706483bfa0f98a5e886266e7ae",
--   [2] = "fcde2b2edba56bf408601fb721fe9b5c338d10ee429ea04fae5511b68fbf8fb9",
--   [3] = "baa5a0964d3320fbc0c6a922140453c8513ea24ab8fd0577034804a967248096",
-- }
```

## 内置算法

### `.adler32(data)`

计算字符串的 Adler-32 校验和，返回 32 位整数。

```lua
local cksum = hash.adler32("hello world")
print(string.format("%08x", cksum))  -- 12345678
```

### `.crc32(str)`

计算字符串的 CRC32 校验和（IEEE 802.3 标准，多项式 0xEDB88320），返回 32 位无符号整数。

```lua
local cksum = hash.crc32("hello world")
-- 与 zlib crc32 兼容
```

## 完整示例

```lua
local hash = require("lunax.hash")

-- 文件完整性校验
local expected_md5 = "5eb63bbbe01eeed093cb22bb8f5acdc3"
local actual_md5 = hash.md5_file("downloaded.zip")
if actual_md5 == expected_md5 then
    print("文件完整性验证通过")
else
    print("文件校验失败")
end

-- 批量字符串哈希
local creds = hash.sha256_buf({ "admin", "secret123" })
print("用户名哈希:", creds[1])
print("密码哈希:", creds[2])

-- 快速校验
local cksum = hash.crc32("hello world")
print("CRC32:", string.format("%08x", cksum))
```

## 跨平台说明

- **Unix:** 使用系统自带的 `md5sum` / `sha256sum` / `sha512sum` 命令
- **Windows:** 使用 `certutil -hashfile` 命令
