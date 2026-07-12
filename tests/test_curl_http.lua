local curl = require('lunax.curl')
local logger = require('lunax.logger')
local ansi = require('lunax.ansi')

local URL = 'https://httpbin.org'

---- [ 1. 正常测试 ] ----
print(ansi.green('\n---- [ curl.http test ] ----'))

local exit, res = curl.http(URL..'/get', 'GET', {
    header = 'Test: JUST TEST',
})

local mode = exit.ok and 'RESPONCE' or 'ERROR'
logger.debug('test_curl_http', ('--> %s\n\n'):format(mode), res, '\n')