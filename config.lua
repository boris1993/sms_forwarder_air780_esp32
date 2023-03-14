local config = {}

config.log_level = log.LOG_INFO

-- ESP32板子型号
-- esp32c3 / esp32s3
config.board_type = "esp32s3"

-- 是否禁止RNDIS
-- 禁止RNDIS可以防止流量流失
config.disable_rndis = true

config.wifi = {
    ssid = "Wi-Fi名",
    password = "Wi-Fi密码"
}

config.notification_channel = {
    -- 合宙推送服务器
    luatos = {
        enabled = true,
        token = ""
    },
    -- Bark
    bark = {
        enabled = true,
        api_key = ""
    },
    -- Server酱
    server_chan = {
        enabled = false,
        send_key = ""
    },
    -- 钉钉Webhook机器人
    ding_talk = {
        enabled = true,
        -- Webhook地址
        webhook_url = "",
        -- 机器人安全设定中的关键词
        keyword = ""
    },
    -- PushPlus 推送加
    pushplus = {
        enabled = true,
        token = ""
    }
}

return config
