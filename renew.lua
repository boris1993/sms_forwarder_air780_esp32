local renew = {}

local sys = require("sys")
local sysplus = require("sysplus")
local air780 = require("air780_helper")
local config = require("config")

-- 获取到期时间
-- GET https://api.example.com/sim/expiry 1732622763
function renew.get_expire_date()
    local code, headers, body = http.request("GET", config.renew_api, {["User-Agent"] = "LuatOS/1.0.0 (Lua; ESP32; Air780)"}, nil, {ipv6=true}).wait()

    -- 如果 code 为负数，说明请求失败
    if code < 0 or code ~= 200 then
        log.error("renew", "获取到期时间", "code=" .. code)
        return nil
    end
    
    -- 尝试将 body 转换为数字
    local date = tonumber(body)
    if not date then
        log.error("renew", "获取到期时间", "未知时间格式：" .. tostring(body))
        return nil
    end

    return date
end

-- 更新到期时间
-- POST https://api.example.com/sim/expiry { "expiry": "1732622763" }
function renew.update_expire_date(date)
    local body = { expiry = date }
    local code, headers, body = http.request("POST", config.renew_api, {["Content-Type"] = "application/json", ["User-Agent"] = "LuatOS/1.0.0 (Lua; ESP32; Air780)"}, json.encode(body), {ipv6=true}).wait()
    if code ~= 200 then
        log.error("renew", "更新到期时间", "code=" .. code)
        return false
    end
    return true
end

-- 发送短信
-- 发送短信后，更新到期时间，到期时间为当前时间戳 + config.renew_day
function renew.send_sms()
    if air780.sent_sms(config.renew_number, config.renew_content) then
        log.info("renew", "保活短信发送成功")
        if renew.update_expire_date(os.time() + config.renew_day * 24 * 60 * 60) then
            log.info("renew", "更新到期时间成功")
            return true
        else
            log.error("renew", "更新到期时间失败")
            return false
        end
    else
        log.error("renew", "发送短信失败")
        return false
    end
    return true
end

-- 保活
-- 如果 date 为空，则发送短信
-- 如果当前时间戳大于等于 date，则发送短信
-- 检查间隔为 config.renew_check_interval 单位小时
function renew.renew()
    while true do
        local date = renew.get_expire_date()
        if date == nil then
            log.error("renew", "获取到期时间失败")
            goto continue
        end
        if date == "" or os.time() >= date then
            log.info("renew", "已到期，开始保活")
            if renew.send_sms() then
                log.info("renew", "保活成功")
            else
                log.error("renew", "保活失败")
            end

            goto continue
        end
        log.debug("renew", "时间未到，无需保活")

        ::continue::
        sys.wait(config.renew_check_interval * 60 * 60 * 1000)
    end
end

return renew
