# `lunax.curl` — HTTP / FTP / SFTP / SCP / SMTP / POP3 / IMAP

对 cURL 命令行的封装，基于 `lunax.popen` 实现。

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
```

---

## `curl.file_download(url, conf)`

从 FTP(S)/SFTP/SCP 服务器下载文件。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `url` | string | 文件 URL，支持 `ftp://` `ftps://` `sftp://` `scp://` |
| `conf` | table \| nil | 可选配置 |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `output` | string | 本地保存路径 |
| `user` | string | 用户名 |
| `password` | string | 密码 |
| `port` | number | 端口号 |
| `insecure` | boolean | 跳过 SSL 证书验证（`-k`） |
| `timeout` | number | 连接超时（秒） |
| `speed_limit` | number | 速度限制（KB/s） |
| `resume` | boolean | 断点续传（`-C -`） |
| `ssl_cert` | string | SSL 客户端证书路径 |
| `ssl_key` | string | SSL 客户端私钥路径 |
| `ssh_key` | string | SSH 私钥路径（SFTP/SCP） |
| `ssh_pub_key` | string | SSH 公钥路径（SFTP/SCP） |
| `progress` | boolean | 显示进度条 |

### 返回值

`exit_info, message`

- 成功：`exit.ok == true`，`message` 可能为空或包含下载内容
- 失败：`exit.ok == false`，`message` 为 cURL 错误描述

### 示例

```lua
local curl = require("lunax.curl")

-- FTP 下载
local exit, msg = curl.file_download("ftp://ftp.example.com/pub/file.zip", {
    user = "anonymous",
    password = "guest@",
    output = "/tmp/file.zip",
})

-- SFTP 下载（密钥认证）
local exit, msg = curl.file_download("sftp://example.com:/remote/path/file.txt", {
    user = "john",
    ssh_key = "~/.ssh/id_rsa",
    output = "/tmp/file.txt",
})
```

---

## `curl.file_upload(url, conf)`

上传文件到 FTP(S)/SFTP/SCP 服务器。

### 参数

| 参数 | 类型 | 说明 |
|------|------|------|
| `url` | string | 目标 URL，支持 `ftp://` `ftps://` `sftp://` `scp://` |
| `conf` | table | 配置（必选） |

### `conf` 配置项

| 字段 | 类型 | 说明 |
|------|------|------|
| `input` | string | **本地文件路径（必填）** |
| `user` | string | 用户名 |
| `password` | string | 密码 |
| `port` | number | 端口号 |
| `insecure` | boolean | 跳过 SSL 证书验证 |
| `timeout` | number | 连接超时（秒） |
| `speed_limit` | number | 速度限制（KB/s） |
| `ssl_cert` | string | SSL 客户端证书路径 |
| `ssl_key` | string | SSL 客户端私钥路径 |
| `ssh_key` | string | SSH 私钥路径（SFTP/SCP） |
| `ssh_pub_key` | string | SSH 公钥路径（SFTP/SCP） |
| `progress` | boolean | 显示进度条 |

### 返回值

`exit_info, message`

### 示例

```lua
local curl = require("lunax.curl")

-- FTP 上传
local exit, msg = curl.file_upload("ftp://ftp.example.com/upload/", {
    input = "/tmp/local-file.zip",
    user = "myuser",
    password = "mypass",
})
```

---

## `curl.mail_send(conf)`

通过 SMTP/SMTPS 发送邮件。

### 参数

`conf` 配置项：

| 字段 | 类型 | 说明 |
|------|------|------|
| `server` | string | **SMTP 服务器地址（必填）** |
| `port` | number | 端口（25/465/587，默认自动） |
| `user` | string | 用户名（用于验证） |
| `password` | string | 密码 |
| `from` | string | **发件人地址（必填）** |
| `to` | string \| string[] | **收件人（必填）** |
| `cc` | string \| string[] | 抄送 |
| `bcc` | string \| string[] | 密送（不会出现在邮件头中） |
| `subject` | string | **邮件主题（必填）** |
| `body` | string | **邮件正文（必填）** |
| `attachment` | string \| string[] | 附件文件路径 |
| `insecure` | boolean | 跳过 SSL 证书验证 |
| `starttls` | boolean | 使用 STARTTLS（端口 587 常用） |
| `timeout` | number | 连接超时（秒） |

### 返回值

`exit_info, message`

### 示例

```lua
local curl = require("lunax.curl")

-- 简单邮件
local exit, msg = curl.mail_send({
    server   = "smtp.gmail.com",
    port     = 587,
    user     = "user@gmail.com",
    password = "app-password",
    from     = "user@gmail.com",
    to       = "recipient@example.com",
    subject  = "Hello from lunax",
    body     = "This is a test email.",
    starttls = true,
})

-- 带附件
local exit, msg = curl.mail_send({
    server     = "mail.example.com",
    user       = "user",
    password   = "pass",
    from       = "user@example.com",
    to         = { "alice@example.com", "bob@example.com" },
    cc         = "boss@example.com",
    subject    = "Report",
    body       = "Please find the report attached.",
    attachment = "/tmp/report.pdf",
})
```

---

## `curl.mail_receive(conf)`

通过 POP3/IMAP 接收邮件。

### 参数

`conf` 配置项：

| 字段 | 类型 | 说明 |
|------|------|------|
| `server` | string | **邮件服务器地址（必填）** |
| `port` | number | 端口（POP3:110, POP3S:995, IMAP:143, IMAPS:993） |
| `user` | string | **用户名（必填）** |
| `password` | string | **密码（必填）** |
| `protocol` | string | `"pop3"` 或 `"imap"`，默认 `"pop3"` |
| `ssl` | boolean | 使用 SSL（端口 995/993 时自动启用） |
| `insecure` | boolean | 跳过 SSL 证书验证 |
| `mailbox` | string | IMAP 邮箱（默认 `"INBOX"`） |
| `uid` | string \| number | 获取指定 UID 的邮件 |
| `timeout` | number | 连接超时（秒） |

### 返回值

`exit_info, message`

- 成功：`exit.ok == true`，`message` 为邮件原始内容（RFC 2822）
- 指定 `uid` 时返回单封邮件内容
- 未指定 `uid` 时返回邮件列表

### 示例

```lua
local curl = require("lunax.curl")

-- POP3 获取所有邮件列表
local exit, list = curl.mail_receive({
    server   = "pop.example.com",
    user     = "user@example.com",
    password = "mypass",
})

-- POP3 获取指定邮件
local exit, mail = curl.mail_receive({
    server   = "pop.example.com",
    user     = "user@example.com",
    password = "mypass",
    uid      = 1,
})

-- IMAP 读取收件箱
local exit, mails = curl.mail_receive({
    server   = "imap.example.com",
    user     = "user@example.com",
    password = "mypass",
    protocol = "imap",
    mailbox  = "INBOX",
})
```

---

## 通用返回值约定

所有函数返回两个值：

| 值 | 类型 | 说明 |
|----|------|------|
| `exit_info` | table | `{ ok: boolean, ext: string?, code: integer }` — popen 退出信息 |
| `message` | string \| nil | 成功时返回数据，失败时返回错误描述 |

## 错误处理

参数类型不匹配时抛出错误：

```
bad argument #1 to 'file_download' (string expected, got number)
bad argument #1 to 'mail_send' (table expected, got string)
bad argument #2 to 'file_upload(_,conf.input)' (string expected, got nil)
```

## 依赖

- 系统需安装 [`curl`](https://curl.se/) 命令行工具
- 所有协议均由 cURL 原生支持，无需额外库
