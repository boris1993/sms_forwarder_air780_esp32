local air780_helper = {}

local sys = require("sys")
local constants = require("constants")
local pdu_helper = require("pdu_helper")
local utils = require("utils")

local uart_timeout = 100

-- 使用UART 1接口与Air780E通信
-- ESP32 <--> Air780E
-- 02(UART1_TX) <--> 31(UART1_RXD)
-- 03(UART1_RX) <--> 30(UART1_TXD)
local uart_id = 1
local uart_setup_result = uart.setup(uart_id, 115200, 8, 1)
if uart_setup_result ~= 0 then
    log.error("air780_helper", "UART初始化失败，返回值："..uart_setup_result.."，ESP32将重启")
    sys.wait(1000)
    rtos.reboot()
end

-- 串口读缓冲区
local send_queue = {}

-- 注册串口接收事件回调
uart.on(uart_id, "receive", function(id, length)
    local s = ""

    repeat
        s = uart.read(id, length)
        if #s > 0 then
            table.insert(send_queue, s)
            sys.timerStart(sys.publish, uart_timeout, constants.uart_ready_message)
        end
    until s == ""
end)

-- 发送AT指令
function air780_helper.send_at_command(command)
    uart.write(uart_id, command)
    -- 如果是PDU模式下的短信内容，直接返回
    if command:sub(1, 6) == "001110" then
        return
    end
    uart.write(uart_id, "\r\n")
    log.debug("air780_helper", "发送AT指令\""..command.."\"")
end

sys.subscribe(constants.uart_ready_message, function()
    -- 拼接所有收到的数据
    local data = table.concat(send_queue)
    log.debug("air780_helper", data)

    -- 读取完成后清空缓冲区
    utils.clear_table(send_queue)

    data = data:gsub("\n", "\r")
    data = data:split("\r")

    while #data > 0 do
        local current_line = table.remove(data, 1)

        -- 响应指令"AT"，用于检测连接Air780E是否成功
        if current_line == "AT" then
            sys.publish(constants.air780_message_topic_at_received)
            return
        end

        -- 响应设定短消息格式指令
        if current_line:find("AT+CMGF", 1, true) then
            sys.publish(constants.air780_message_topic_sms_format_set)
            return
        end

        -- 响应设定字符集指令
        if current_line:find("AT+CSCS", 1, true) then
            sys.publish(constants.air780_message_topic_charset_configured)
            return
        end

        -- 响应配置新消息提示指令
        if current_line:find("AT+CNMI", 1, true) then
            sys.publish(constants.air780_message_topic_new_message_notification_configured)
            return
        end

        -- 响应发送短信指令
        if current_line:find(">", 1, true) then
            -- log.debug("air780_helper", "捕获到短信发送提示符")
            sys.publish(constants.air780_helper_sms_send_ready)
            return
        end

        -- 响应发送短信成功
        if current_line:find("+CMGS:", 1, true) then
            -- log.debug("air780_helper", "捕获到短信发送成功")
            sys.publish(constants.air780_send_sms_success)
            return
        end

        local urc = current_line:match("^%+(%w+)")

        if urc then -- URC上报
            if urc == "CGATT" then
                -- 基站附着状态
                sys.publish(constants.air780_message_topic_network_connected, current_line:match("%+CGATT: *(%d)") == "1")
            elseif urc == "CMT" then
                -- 收到短信
                local pdu_length = tonumber(current_line:match("%+CMT: *, *(%d+)"))

                repeat
                    local line = table.remove(data, 1)
                    if #line > 0 then
                        local phone_number, sms_content, receive_time, is_long_sms, total, current_id, sms_id = pdu_helper.decode_pdu(line, pdu_length)
                        log.info("air780_helper", "于 "..receive_time.." 收到短信，来自号码"..phone_number..", 内容：\""..sms_content.."\"")

                        sys.publish(
                            constants.air780_message_topic_new_sms_received,
                            phone_number,
                            sms_content,
                            receive_time,
                            is_long_sms,
                            total,
                            current_id,
                            sms_id)
                        break
                    end
                until #data == 0
            end
        else -- 其他命令
            local cmd = current_line:match("^AT%+(%w+)")
            if cmd then--命令回复
                if cmd == "CPIN" then
                    -- 检查卡
                    repeat
                        local l = table.remove(data, 1)
                        if #l > 0 then
                            if l:find("READY") then
                                -- 找到卡了
                                sys.publish(constants.air780_message_topic_sim_detected, true)
                                return
                            elseif l:find("CME ERROR") then
                                -- 没卡？
                                sys.publish(constants.air780_message_topic_sim_detected, false)
                                return
                            end
                        end
                    until #data == 0
                end
            end
        end
    end
end)

-- 发送AT指令并等待指定topic
function air780_helper.send_at_command_and_wait(command, topic_listen_to, timeout)
    while true do
        air780_helper.send_at_command(command)
        local is_successful, r1, r2, r3 = sys.waitUntil(topic_listen_to, timeout or 1000)
        if is_successful then
            return r1, r2, r3
        end
    end
end

function air780_helper.topic_wait(topic, timeout)
    local is_successful, r1, r2, r3 = sys.waitUntil(topic, timeout or 1000)
    return is_successful
end

function air780_helper.sent_sms(to, text)
    local logging_tag = "air780_helper.sent_sms"
    local data, len = pdu_helper.encode_pdu(to, text)
    if not data or not len then
        log.error(logging_tag, "短信编码失败")
        return false
    end
    air780_helper.send_at_command("AT+CMGS=" .. len)
    
    -- 增加调试信息
    log.debug(logging_tag, "等待短信发送提示符")
    local result = air780_helper.topic_wait(constants.air780_helper_sms_send_ready, 3000)
    if not result then
        log.error(logging_tag, "短信发送失败，AT+CMGS=" .. len .. " 超时")
        return false
    end

    air780_helper.send_at_command(data .. "\x1A")
    local result = air780_helper.topic_wait(constants.air780_send_sms_success, 5000)
    if result then
        log.info(logging_tag, "短信发送成功")
        return true
    else
        log.error(logging_tag, "短信发送失败")
        return false
    end
end
return air780_helper
