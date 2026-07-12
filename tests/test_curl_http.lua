local curl = require('lunax.curl')
local logger = require('lunax.logger')

local URL = 'https://httpbin.org'

local exit, res = curl.http(URL..'/get', 'GET', {
    header = 'Test: JUST TEST',
})

local mode = exit.ok and 'RESPONCE' or 'ERROR'
logger.debug('test_curl_http', ('--> %s\n\n'):format(mode), res, '\n')