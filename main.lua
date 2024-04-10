PROJECT = "sms_forwarder_wifi"
VERSION = "1.0.0"

local sys = require("sys")
local config = require("config")
local constants = require("constants")
local air780 = require("air780_helper")
local led_helper = require("led_helper")
local utils = require("utils")

require("sysplus")
require("notification_helper")

if wdt then
    wdt.init(9000)
    sys.timerLoopStart(wdt.feed, 3000)
end

log.setLevel(config.log_level)
log.style(1)

log.info("bsp", rtos.bsp())
log.info("mem_sys", rtos.meminfo("sys"))
log.info("mem_lua", rtos.meminfo("lua"))

-- 每秒完整GC一次，防止内存不足问题
sys.timerLoopStart(function()
    collectgarbage("collect")
end, 1000)

led_helper.blink_status_led(constants.led_blink_duration.initializing)

sys.taskInit(function()
    local logging_tag = "main - 初始化网络"
    for _, wifi in ipairs(config.wifi) do
        log.info(logging_tag, "正在连接无线网络" .. wifi.ssid)
        wlan.init()
        wlan.setMode(wlan.STATION)
        wlan.connect(wifi.ssid, wifi.password)
        sys.waitUntil("IP_READY", 30*1000)

        if wlan.ready() then
            local ip_address = wlan.getIP()
            log.info(logging_tag, "无线网络连接成功，IP地址："..ip_address)
            break
        end

        log.info(logging_tag, "无线网络连接失败！")
        wlan.disconnect()
        wlan.init()
        sys.wait(5*1000)
    end

    if not wlan.ready() then
        log.info(logging_tag, "所有无线网络均连接失败！模块重启。。。")
        rtos.reboot()
        return
    end

    for index, value in ipairs(config.dns_servers) do
        log.info(logging_tag, "配置第"..index.."个DNS服务器为"..value)
        socket.setDNS(nil, index, value)
    end

    log.info(logging_tag, "等待时间同步")
    sys.waitUntil("NTP_UPDATE")
    log.info(logging_tag, "时间同步完成")
end)

sys.taskInit(function ()
    local logging_tag = "main - 初始化Air780"

    local at_command_result

    log.info(logging_tag, "正在尝试连接Air780E")
    air780.send_at_command_and_wait("AT", constants.air780_message_topic_at_received)
    log.info(logging_tag, "Air780E已连接")

    log.info(logging_tag, "正在检查有无SIM卡")
    at_command_result = air780.send_at_command_and_wait("AT+CPIN?", constants.air780_message_topic_sim_detected)
    while not at_command_result do
        if not config.retry_sim_detection then
            log.error(logging_tag, "未检测到SIM卡，请检查SIM卡已插好，然后重启开发板")
            return
        else
            log.warn(logging_tag, "未检测到SIM卡， 正在重试")
            sys.wait(5000)
            at_command_result = air780.send_at_command_and_wait("AT+CPIN?", constants.air780_message_topic_sim_detected)
        end
    end

    log.info(logging_tag, "正在配置短信功能")
    -- 配置短消息格式为PDU格式
    air780.send_at_command_and_wait("AT+CMGF=0", constants.air780_message_topic_sms_format_set)
    -- 配置短信使用UCS2编码
    air780.send_at_command_and_wait("AT+CSCS=\"UCS2\"", constants.air780_message_topic_charset_configured)
    -- 配置短信内容直接上报，不缓存
    air780.send_at_command_and_wait("AT+CNMI=2,2,0,0,0", constants.air780_message_topic_new_message_notification_configured)
    log.info(logging_tag, "短信功能配置完成")

    if config.disable_rndis then
        log.info(logging_tag, "正在禁用RNDIS")
        air780.send_at_command("AT+RNDISCALL=0,0")
    end

    log.info(logging_tag, "检查GPRS附着状态")
    while true do
        local result = air780.send_at_command_and_wait("AT+CGATT?", constants.air780_message_topic_network_connected)
        if result then
            log.info(logging_tag, "GPRS已附着")
            break
        else
            log.info(logging_tag, "GPRS未附着，将在5秒后重新检查")
            sys.wait(5000)
        end
    end

    if config.disable_netled then
        log.info(logging_tag, "正在关闭NET灯闪烁")
        air780.send_at_command("AT+CNETLIGHT=0")
    end

    log.info(logging_tag, "初始化完成，等待新短信...")

    -- 测试短信推送，解除注释可开机时自动模拟推送一条，用于模块独立测试
    -- sys.publish(
    --     constants.air780_message_topic_new_notification_request,
    --     '10086',
    --     '测试短信内容')

    led_helper.light_status_led()
end)

--[[
long_sms_buffer = {
    [phone_number] = {
        [id] = "content"
    }
}
--]]
local long_sms_buffer = {}

local function concat_and_send_long_sms(phone_number, receive_time, sms_parts)
    local full_content = ""

    table.sort(sms_parts, function(a,b) return a.id < b.id end)

    for _, sms in ipairs(sms_parts) do
        log.debug("main", "message id: " .. sms.id .. ", content: ".. sms.sms_content)
        full_content = full_content..sms.sms_content
    end
    -- 清空缓冲区
    utils.clear_table(long_sms_buffer[phone_number][receive_time])
    log.info("main", "长短信接收完成，完整内容："..full_content)
    sys.publish(
        constants.air780_message_topic_new_notification_request,
        phone_number,
        full_content)
    led_helper.shut_working_led()
end

local function clean_sms_buffer(phone_number, receive_time)
    if not long_sms_buffer[phone_number] then
        return
    end

    if not long_sms_buffer[phone_number][receive_time] then
        return
    end

    log.warn("main", "长短信接收超时，来自 ".. phone_number .."，接收时间 ".. receive_time)
    if #long_sms_buffer[phone_number][receive_time] > 0 then
        concat_and_send_long_sms(phone_number, receive_time, long_sms_buffer[phone_number][receive_time])
        long_sms_buffer[phone_number][receive_time] = nil
    end
end

sys.subscribe(constants.air780_message_topic_new_sms_received,
function(phone_number, sms_content, receive_time, is_long_message, total_message_number, current_message_id)
    led_helper.blink_working_led(constants.led_blink_duration.working)

    if is_long_message then
        log.info("main", "收到长短信，来自"..phone_number.."，正在将第"..current_message_id.."条存入缓冲区，共"..total_message_number.."条")

        if not long_sms_buffer[phone_number] then
            long_sms_buffer[phone_number] = {}
        end

        if not long_sms_buffer[phone_number][receive_time] then
            long_sms_buffer[phone_number][receive_time] = {}
            sys.timerStart(clean_sms_buffer, 30*1000, phone_number, receive_time)
        end

        table.insert(long_sms_buffer[phone_number][receive_time], {id = current_message_id, sms_content = sms_content, receive_time = receive_time})

        if long_sms_buffer[phone_number][receive_time] and #long_sms_buffer[phone_number][receive_time] == total_message_number then
            concat_and_send_long_sms(phone_number, receive_time, long_sms_buffer[phone_number][receive_time])
            long_sms_buffer[phone_number][receive_time] = nil
            return
        end
    else
        log.info("main", "收到来自"..phone_number.."的短信，即将转发...")
        sys.publish(
            constants.air780_message_topic_new_notification_request,
            phone_number,
            sms_content)

        led_helper.shut_working_led()
        return
    end
end)

sys.run()
