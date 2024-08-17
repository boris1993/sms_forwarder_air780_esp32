local config = {}

config.log_level = log.LOG_INFO

-- ESP32板子型号
-- esp32c3 / esp32s3
config.board_type = "esp32s3"

-- 是否关闭Air780e网络指示灯
config.disable_netled = true

-- 是否禁止RNDIS
-- 禁止RNDIS可以防止流量流失
config.disable_rndis = true

-- 是否在检查不到SIM卡时重试
-- 目前发现1118版本AT固件无法通过重试来检测到后插入的SIM卡
-- 而1156版本AT固件第一次检测有概率检测不到SIM卡，需要重试
config.retry_sim_detection = true

config.wifi = {
    {
        ssid = "Wi-Fi名",
        password = "Wi-Fi密码",
    },
    -- {
    --     ssid = "",
    --     password = "",
    -- }
}

-- 手动配置DNS服务器
-- 可以留空，也可以设定数个
-- 但是多了也没用，要自己设定的话，放一两个就够了
config.dns_servers = {
    "119.29.29.29",
    "223.5.5.5",
    "8.8.8.8",
    "1.1.1.1"
}

config.notification_channel = {
    -- resend邮箱
    resend = {
        enabled = false,
        api_token = "Bearer **********",
        fromEmail = '*********** <Air780@resend.dev>',
        toEmail = '**********@qq.com',
    },
    -- 合宙推送服务器
    luatos = {
        enabled = false,
        token = ""
    },
    -- Bark
    bark = {
        enabled = false,
        api_key = ""
    },
    -- Server酱
    server_chan = {
        enabled = false,
        send_key = ""
    },
    -- 钉钉Webhook机器人
    ding_talk = {
        enabled = false,
        -- Webhook地址
        webhook_url = "",
        -- 机器人安全设定中的关键词
        keyword = ""
    },
    -- telegram 机器人
    telegram = {
        enabled = false,
        -- Webhook地址
        webhook_url = "",
        -- chat_id, 通过 https://api.telegram.org/bot<token>/getUpdates 获取
        chat_id = ""
    },
    -- PushPlus 推送加
    pushplus = {
        enabled = false,
        token = ""
    },
    -- 飞书机器人
    feishu = {
        enabled = false,
        app_id = "",
        app_secret = "",
        receive_id="" -- 填写接收推送人的邮箱（通常飞书账户需要绑定邮箱）
    },
    wecom = {
        enabled = false,
        url = "https://qyapi.weixin.qq.com/cgi-bin/webhook/send?key=", -- 填写企业微信机器人推送 URL
    }
}

return config
