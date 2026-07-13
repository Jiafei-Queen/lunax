# `lunax.curl` — HTTP 请求

对 cURL 的封装，支持 HTTP 方法、自定义请求头、请求体以及输出文件。基于 `lunax.popen` 实现。

## 导入

```lua
local curl = require("lunax.curl")
```

## `curl.http(url, req, conf)`

发送 HTTP 请求并返回响应。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `url` | string | 目标 URL |
| `req` | string | HTTP 方法（如 `"GET"`、`"POST"`、`"PUT"`、`"DELETE"`） |
| `conf` | table | 可选配置 |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `header` | string \| string[] \| nil | 请求头，单个字符串或字符串数组（对应 `-H` 参数） |
| `data` | string \| string[] \| nil | 请求体数据（对应 `-d` 参数）。仅当 `req ~= 'GET'` 时生效 |
| `output` | string \| boolean \| nil | `string` = 输出到文件（`-o <path>`），`true` = 使用 URL 派生文件名（`-O`），`nil` = 无输出标志 |

### 返回值

返回两个值：`exit_info, response_data`。

`exit_info` 为 `popen:close()` 的结果 table：

| 字段 | 类型 | 说明 |
|------|------|------|
| `ok` | boolean | 退出码是否为 0 |
| `ext` | string \| nil | 退出状态类型 |
| `code` | integer | 退出码 |

`response_data` 的具体内容取决于请求结果：

| 情况 | 返回值 |
|------|--------|
| 请求成功 (exit.ok) | HTTP 响应体字符串 |
| HTTP 错误 (exit.code == 22) | HTTP 状态码（数字） |
| 其他 cURL 错误 | cURL 错误消息字符串 |

### 底层命令

构建的 cURL 命令格式：`curl -sS -f -X <req> [-H <header>...] [-d <data>...] [-o <path>|-O] <url>`

- `-sS` — 静默模式但显示错误
- `-f` — HTTP 错误时 exit code 为 22

### 示例

```lua
local curl = require("lunax.curl")

-- 简单 GET 请求
local exit, body = curl.http("https://api.example.com/users", "GET")
if exit.ok then
    print("响应:", body)
else
    print("错误:", body)
end

-- POST 请求带请求头和数据
local exit, res = curl.http("https://api.example.com/data", "POST", {
    header = { "Content-Type: application/json", "Authorization: Bearer token123" },
    data = '{"key": "value"}',
})

-- 下载文件
local exit, msg = curl.http("https://example.com/file.zip", "GET", {
    output = "/tmp/file.zip",
})
if exit.ok then
    print("下载成功")
end

-- 使用 URL 派生文件名
local exit, msg = curl.http("https://example.com/file.zip", "GET", {
    output = true,  -- 等效于 curl -O
})
```

### 错误处理

参数类型不匹配时抛出错误：

```
bad argument #1 to 'http' (string expected, got number)
bad argument #2 to 'http' (string expected, got table)
bad argument #3 for 'http(_,_,conf.header)': string|array? expected, got map
bad argument #3 for 'http(_,_,conf.output)': string|boolean? expected, got number
```
