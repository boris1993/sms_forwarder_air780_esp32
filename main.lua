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
    log.info(logging_tag, "正在连接无线网络"..config.wifi.ssid)
    wlan.init()
    wlan.setMode(wlan.STATION)
    wlan.connect(config.wifi["ssid"], config.wifi.password)
    sys.waitUntil("IP_READY")
    local ip_address = wlan.getIP()
    log.info(logging_tag, "无线网络连接成功，IP地址："..ip_address)

    log.info(logging_tag, "配置DNS服务器")
    socket.setDNS(nil, 1, "119.29.29.29")
    socket.setDNS(nil, 2, "223.5.5.5")

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
    while true do
        at_command_result = air780.send_at_command_and_wait("AT+CPIN?", constants.air780_message_topic_sim_detected)
        if at_command_result then
            break
        else
            log.error(logging_tag, "未检测到SIM卡， 正在重试")
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

    log.info(logging_tag, "初始化完成，等待新短信...")

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

sys.subscribe(constants.air780_message_topic_new_sms_received,
function(phone_number, sms_content, _, is_long_message, total_message_number, current_message_id)
    led_helper.blink_working_led(constants.led_blink_duration.working)

    if is_long_message then
        log.info("main", "收到长短信，来自"..phone_number.."，正在将第"..current_message_id.."条存入缓冲区，共"..total_message_number.."条")

        if not long_sms_buffer[phone_number] then
            long_sms_buffer[phone_number] = {}
        end

        long_sms_buffer[phone_number][current_message_id] = sms_content

        if long_sms_buffer[phone_number] and #long_sms_buffer[phone_number] == total_message_number then
            local full_content = ""

            local message_ids = {}
            for key in pairs(long_sms_buffer[phone_number]) do
                table.insert(message_ids, key)
            end

            table.sort(message_ids)

            for _, id in ipairs(message_ids) do
                log.debug("main", "message id: "..id..", content: "..long_sms_buffer[phone_number][id])
                full_content = full_content..long_sms_buffer[phone_number][id]
            end

            -- 清空缓冲区
            utils.clear_table(long_sms_buffer[phone_number])
            message_ids = nil

            log.info("main", "长短信接收完成，完整内容："..full_content)
            sys.publish(
                constants.air780_message_topic_new_notification_request,
                phone_number,
                full_content)

            led_helper.shut_working_led()
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
