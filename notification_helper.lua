local notification_helper = {}

local sys = require("sys")
local sysplus = require("sysplus")
local constants = require("constants")
local config = require("config")
local utils = require("utils")

-- https://tutorialspots.com/lua-urlencode-and-urldecode-5528.html
local function urlencode(str)
    str = string.gsub(
        str,
        "([^0-9a-zA-Z !'()*._~-])", -- locale independent
        function(c)
            return string.format ("%%%02X", string.byte(c))
        end)
    str = string.gsub (str, " ", "+")
    return str
 end

local function bark(sender_number, content)
    if not config.notification_channel.bark.enabled then
        return
    end

    if utils.is_empty(config.notification_channel.bark.api_key) then
        log.warn("notification_helper", "Bark API key为空，跳过调用Bark API")
        return
    end

    log.info("notification_helper", "正在发送Bark通知")

    local url = "https://api.day.app/"..config.notification_channel.bark.api_key
    log.debug("notification_helper", "Calling Bark API: "..url)

    local request_body = {
        title = sender_number,
        body = content,
        level = "timeSensitive",
    }

    local code, headers, body = http.request(
        "POST",
        url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body),
        {ipv6=true}
    ).wait()
    if code ~= 200 then
        log.warn("notification_helper", "Bark API返回值不是200，HTTP状态码："..code.."，响应内容："..(body or ""))
    end

    log.info("notification_helper", "Bark通知发送完成")
end

local function luatos_notification(sender_number, content)
    if not config.notification_channel.luatos.enabled then
        return
    end

    if utils.is_empty(config.notification_channel.luatos.token) then
        log.warn("notification_helper", "合宙推送平台token为空，跳过调用合宙推送平台API")
        return
    end

    log.info("notification_helper", "正在发送合宙推送平台通知")

    local url = "https://push.luatos.org/"..config.notification_channel.luatos.token..".send/"..urlencode(sender_number).."/"..urlencode(content)
    log.debug("notification_helper", "Calling LuatOS notification API: "..url)

    local code, headers, body = http.request("GET", url, nil, nil, {ipv6=true}).wait()
    if code ~= 200 then
        log.warn("notification_helper", "合宙推送API返回值不是200，HTTP状态码："..code.."，响应内容："..(body or ""))
    end

    log.info("notification_helper", "合宙推送平台通知发送完成")
end

local function server_chan(sender_number, content)
    if not config.notification_channel.server_chan.enabled then
        return
    end

    if utils.is_empty(config.notification_channel.server_chan.send_key) then
        log.warn("notification_helper", "Server酱的SendKey为空，跳过调用Server酱API")
        return
    end

    log.info("notification_helper", "正在发送Server酱通知")

    local url = "https://sctapi.ftqq.com/"..config.notification_channel.server_chan.send_key..".send"
    log.debug("notification_helper", "Calling ServerChan API: "..url)

    local request_body = {
        title = sender_number,
        desp = content
    }
    local request_body_json, json_error = json.encode(request_body)

    if json_error then
        log.warn("notification_helper", "Server酱请求序列化失败，错误信息："..json_error)
        return
    end

    log.debug("notification_helper", "ServerChan request body: "..request_body_json)

    local code, headers, response_body = http.request(
        -- Method
        "POST",
        -- URL
        url,
        -- Headers
        {["Content-Type"] = "application/json"},
        request_body_json,
        {ipv6=true}
    ).wait()

    if code ~= 200 then
        log.warn("notification_helper", "Server酱API返回值不是200，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end

    log.info("notification_helper", "Server酱通知发送完成")
end

local function ding_talk_bot(sender_number, content)
    if not config.notification_channel.ding_talk.enabled then
        return
    end

    if utils.is_empty(config.notification_channel.ding_talk.webhook_url) then
        log.warn("notification_helper", "钉钉机器人webhook URL未填写，跳过调用钉钉机器人webhook")
        return
    elseif utils.is_empty(config.notification_channel.ding_talk.keyword) then
        log.warn("notification_helper", "钉钉机器人关键词未填写，跳过调用钉钉机器人webhook")
        return
    end

    log.info("notification_helper", "正在发送钉钉机器人通知")

    local url = config.notification_channel.ding_talk.webhook_url
    local keyword = config.notification_channel.ding_talk.keyword

    local request_body = {
        msgtype = "markdown",
        markdown = {
            title = keyword,
            text = "收到来自 **"..sender_number.."** 的短信，内容：\n\n"..content
        }
    }

    local code, headers, response_body = http.request(
        "POST",
        url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body),
        {ipv6=true}
    ).wait()

    if code ~= 200 then
        log.warn("notification_helper", "钉钉webhook返回值不是200，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end

    log.info("notification_helper", "钉钉机器人通知发送完成")
end

local function pushplus(sender_number, content)
    if not config.notification_channel.pushplus.enabled then
        return
    elseif utils.is_empty(config.notification_channel.pushplus.token) then
        log.warn("notification_helper", "PushPlus token未填写，跳过调用PushPlus")
        return
    end

    log.info("notification_helper", "正在发送PushPlus通知")

    local url = "http://www.pushplus.plus/send"
    local request_body = {
        token = config.notification_channel.pushplus.token,
        title = sender_number,
        content = content
    }

    local code, headers, response_body = http.request(
        "POST",
        url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body),
        {ipv6=true}
    ).wait()

    if code ~= 200 then
        log.warn("notification_helper", "PushPlus API返回值不是200，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end

    log.info("notification_helper", "PushPlus通知发送完成")
end

local function telegram_bot(sender_number, content)
    if not config.notification_channel.telegram.enabled then
        return
    end

    if utils.is_empty(config.notification_channel.telegram.webhook_url) then
        log.warn("notification_helper", "Telegram URL未填写，跳过调用Telegram bot")
        return
    elseif utils.is_empty(config.notification_channel.telegram.chat_id) then
        log.warn("notification_helper", "Telegram chat_id 未填写，跳过调用Telegram bot")
        return
    end

    log.info("notification_helper", "正在发送Telegram bot通知")

    local url = config.notification_channel.telegram.webhook_url
    local chat_id = config.notification_channel.telegram.chat_id

    local request_body = {
        chat_id = chat_id,
        parse_mode = "Markdown",
        text = "*"..sender_number.."*\n"..content
    }

    local code, headers, response_body = http.request(
        "POST",
        url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body),
        {ipv6=true}
    ).wait()

    if code ~= 200 then
        log.warn("notification_helper", "telegram api返回值不是200，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end

    log.info("notification_helper", "telegram bot通知发送完成")
end

local function feishu_bot(sender_number, content)
    if not config.notification_channel.feishu.enabled then
        return
    end
    if utils.is_empty(config.notification_channel.feishu.app_id) or utils.is_empty(config.notification_channel.feishu.app_secret) then
        log.warn("notification_helper", "飞书机器人app_id或app_secret未填写，跳过调用飞书机器人")
        return
    end
    if utils.is_empty(config.notification_channel.feishu.receive_id) then
        log.warn("notification_helper", "飞书机器人receive_id未填写，跳过调用飞书机器人")
        return
    end
    local app_id = config.notification_channel.feishu.app_id
    local app_secret = config.notification_channel.feishu.app_secret
    local receive_id = config.notification_channel.feishu.receive_id
    local token_url = "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal"
    local request_body = {
        app_id = app_id,
        app_secret = app_secret
    }
    local code, headers, response_body = http.request(
        "POST",
        token_url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body),
        {ipv6=true}
    ).wait()
    if code ~= 200 then
        log.warn("notification_helper", "飞书机器人获取access_token失败，HTTP状态码："..code.."，响应内容："..(response_body or ""))
        return
    end
    local data = json.decode(response_body)
    local access_token = data.tenant_access_token
    if utils.is_empty(access_token) then
        log.warn("notification_helper", "飞书机器人获取access_token失败，响应内容："..(response_body or ""))
        return
    end
    log.info("notification_helper", "正在发送飞书机器人通知")
    local url = "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=email"
    local request_body = {
        msg_type = "text",
        content = json.encode({
            text = "收到来自 **"..sender_number.."** 的短信，内容：\n\n"..content
        }),
        receive_id = receive_id
    }
    local code, headers, response_body = http.request(
        "POST",
        url,
        {["Content-Type"] = "application/json", ["Authorization"] = "Bearer "..access_token},
        json.encode(request_body),
        {ipv6=true}
    ).wait()
    if code ~= 200 then
        log.warn("notification_helper", "飞书机器人发送消息失败，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end
    log.info("notification_helper", "飞书机器人通知发送完成")
end

local function wecom_bot(sender_number, content)
    if not config.notification_channel.wecom.enabled then
        return
    end
    if utils.is_empty(config.notification_channel.wecom.url) then
        log.warn("notification_helper", "企业微信机器人推送 URL 未填写，跳过调用飞书机器人")
        return
    end
    log.info("notification_helper", "正在发送企业微信机器人通知")
    local request_body = {
        msgtype = "text",
        text = {
            content = "收到来自 "..sender_number.." 的短信，内容：\n\n"..content
        }
    }
    local code, headers, response_body = http.request(
        "POST",
        config.notification_channel.wecom.url,
        {["Content-Type"] = "application/json"},
        json.encode(request_body)
    ).wait()
    if code ~= 200 then
        log.warn("notification_helper", "企业微信机器人发送消息失败，HTTP状态码："..code.."，响应内容："..(response_body or ""))
    end
    log.info("notification_helper", "企业微信机器人通知发送完成")
end

local notification_channels = {
    bark = bark,
    luatos_notification = luatos_notification,
    server_chan = server_chan,
    ding_talk_bot = ding_talk_bot,
    pushplus = pushplus,
    telegram_bot = telegram_bot,
    feishu_bot = feishu_bot,
    wecom_bot = wecom_bot,
}

local function call_notification_channels(sender_number, content)
    for _, notification_channel in pairs(notification_channels) do
        sys.taskInit(function()
            notification_channel(sender_number, content)
        end)
    end
end

sys.subscribe(constants.air780_message_topic_new_notification_request,
function(sender_number, content)
    call_notification_channels(sender_number, content)
end)

return notification_helper
