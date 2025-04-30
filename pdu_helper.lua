--[[
PDU helper
大部分代码来自 https://github.com/chenxuuu/sms_forwarding/blob/master/script/pdu.lua
--]]
local pdu_helper = {}

local constants = require("constants")

--[[
GSM字符集
https://en.wikipedia.org/wiki/GSM_03.38#GSM_7-bit_default_alphabet_and_extension_table_of_3GPP_TS_23.038_/_GSM_03.38
--]]
local charmap = {
    [0] = 0x40, 0xa3, 0x24, 0xa5, 0xe8, 0xE9, 0xF9, 0xEC, 0xF2, 0xC7, 0x0A, 0xD8, 0xF8, 0x0D, 0xC5, 0xE5
    , 0x0394, 0x5F, 0x03A6, 0x0393, 0x039B, 0x03A9, 0x03A0, 0x03A8, 0x03A3, 0x0398, 0x039E, 0x1B, 0xC6, 0xE5, 0xDF, 0xA9
    , 0x20, 0x21, 0x22, 0x23, 0xA4, 0x25, 0x26, 0x27, 0x28, 0x29, 0x2A, 0x2B, 0x2C, 0x2D, 0x2E, 0x2F
    , 0x30, 0x31, 0x32, 0x33, 0x34, 0x35, 0x36, 0x37, 0x38, 0x39, 0x3A, 0x3B, 0x3C, 0x3D, 0x3E, 0x3F
    , 0xA1, 0x41, 0x42, 0x43, 0x44, 0x45, 0x46, 0x47, 0x48, 0x49, 0x4A, 0x4B, 0x4C, 0x4D, 0x4E, 0x4F
    , 0X50, 0x51, 0x52, 0x53, 0x54, 0x55, 0x56, 0x57, 0x58, 0x59, 0x5A, 0xC4, 0xD6, 0xD1, 0xDC, 0xA7
    , 0xBF, 0x61, 0x62, 0x63, 0x64, 0x65, 0x66, 0x67, 0x68, 0x69, 0x6A, 0x6B, 0x6C, 0x6D, 0x6E, 0x6F
    , 0x70, 0x71, 0x72, 0x73, 0x74, 0x75, 0x76, 0x77, 0x78, 0x79, 0x7A, 0xE4, 0xF6, 0xF1, 0xFC, 0xE0}

--[[
GSM扩展字符集
https://en.wikipedia.org/wiki/GSM_03.38#GSM_7-bit_default_alphabet_and_extension_table_of_3GPP_TS_23.038_/_GSM_03.38
--]]
local charmap_ext = {[10] = 0x0C, [20] = 0x5E, [40] = 0x7B, [41] = 0x7D, [47] = 0x5C, [60] = 0x5B, [61] = 0x7E
    , [62] = 0x5D, [64] = 0x7C, [101] = 0xA4}

local function number_to_bcd_number(number)
    local number_length = #number
    local prefix
    local converted_number = ""

    if string.sub(number, 1, 1) == "+" then
        prefix = constants.pdu_sms_center_type.global
        number_length = number_length - 1
        number = number:sub(2, -1)
    else
        prefix = constants.pdu_sms_center_type.domestic
    end

    -- 每次取两位，前后颠倒后，拼接至converted_number
    for i = 1, (number_length - (number_length % 2)) / 2 do
        converted_number = converted_number..number:sub(i * 2, i * 2)..number:sub(i * 2 - 1, i * 2 - 1)
    end

    -- 如果号码长度为奇数，那么在末尾补一个F
    if number_length % 2 ~= 0 then
        converted_number = converted_number.."F"..number:sub(number_length, number_length)
    end

    return prefix..converted_number
end

-- 解码GSM 8-bit编码
local function gsm_8bit_decode(data)
    local ucs_data = ""
    local lpcnt = #data / 2

    for i = 1, lpcnt do
        ucs_data = ucs_data.."00"..data:sub((i - 1) * 2 + 1, i * 2)
    end

    return ucs_data, lpcnt
end

-- 解码GSM 7-bit编码
local function gsm_7bit_decode(data, longsms)
    local ucsdata, lpcnt, tmpdata, resdata, nbyte, nleft, ucslen, olddat = "", #data / 2, 0, 0, 0, 0, 0

    if longsms then
        tmpdata = tonumber("0x" .. data:sub(1, 2))
        resdata = tmpdata >> 1
        if olddat == 27 then
            if charmap_ext[resdata] then --特殊字符
                olddat, resdata = resdata, charmap_ext[resdata]
                ucsdata = ucsdata:sub(1, -5)
            else
                olddat, resdata = resdata, charmap[resdata]
            end
        else
            olddat, resdata = resdata, charmap[resdata]
        end
        ucsdata = ucsdata .. string.format("%04X", resdata)
    else
        tmpdata = tonumber("0x" .. data:sub(1, 2))
        resdata = ((tmpdata<<nbyte)|nleft)&0x7f
        if olddat == 27 then
            if charmap_ext[resdata] then --特殊字符
                olddat, resdata = resdata, charmap_ext[resdata]
                ucsdata = ucsdata:sub(1, -5)
            else
                olddat, resdata = resdata, charmap[resdata]
            end
        else
            olddat, resdata = resdata, charmap[resdata]
        end
        ucsdata = ucsdata .. string.format("%04X", resdata)

        nleft = tmpdata >> (7 - nbyte)
        nbyte = nbyte + 1
        ucslen = ucslen + 1
    end

    for i = 2, lpcnt do
        tmpdata = tonumber("0x" .. data:sub((i - 1) * 2 + 1, i * 2))
        if tmpdata == nil then break end
        resdata = ((tmpdata<<nbyte)|nleft)&0x7f
        if olddat == 27 then
            if charmap_ext[resdata] then --特殊字符
                olddat, resdata = resdata, charmap_ext[resdata]
                ucsdata = ucsdata:sub(1, -5)
            else
                olddat, resdata = resdata, charmap[resdata]
            end
        else
            olddat, resdata = resdata, charmap[resdata]
        end
        ucsdata = ucsdata .. string.format("%04X", resdata)

        nleft = tmpdata >> (7 - nbyte)
        nbyte = nbyte + 1
        ucslen = ucslen + 1

        if nbyte == 7 then
            if olddat == 27 then
                if charmap_ext[nleft] then --特殊字符
                    olddat, nleft = nleft, charmap_ext[nleft]
                    ucsdata = ucsdata:sub(1, -5)
                else
                    olddat, nleft = nleft, charmap[nleft]
                end
            else
                olddat, nleft = nleft, charmap[nleft]
            end
            ucsdata = ucsdata .. string.format("%04X", nleft)
            nbyte, nleft = 0, 0
            ucslen = ucslen + 1
        end
    end

    return ucsdata, ucslen
end

local function ucs2_to_utf8(s)
    local temp = {}
    for i=1, #s, 2 do
        local d1, d2 = s:byte(i), s:byte(i + 1)
        if d1 == 0 and d2 <= 0x7f then  --不大于0x007F
            table.insert(temp, string.char(d2))
        elseif d1 < 0x07 then  --不大于0x07FF  00000aaa bbbbbbbb ==> 110aaabb 10bbbbbb
            table.insert(temp, string.char(0xc0 + (d1 << 2) + (d2 >> 6), 0x80 + (d2 & 0x3f)))
        else    --aaaaaaaa bbbbbbbb ==> 1110aaaa 10aaaabb 10bbbbbb
            table.insert(temp,string.char(0xe0 + (d1 >> 4), 0x80 + ((d1 & 0x0f) << 2) + (d2 >> 6), 0x80 + (d2 & 0x3f)))
        end
    end
    return table.concat(temp)
end

local function utf8_to_ucs2(s)
    local ucsdata = ""
    local i = 1
    while i <= #s do
        local c = string.byte(s, i)
        local resdata = 0
        local nbyte = 0
        if c < 128 then
            resdata = c
            nbyte = 1
        elseif c < 224 then
            resdata = (c - 192) * 64 + (string.byte(s, i + 1) - 128)
            nbyte = 2
        elseif c < 240 then
            resdata = (c - 224) * 4096 + (string.byte(s, i + 1) - 128) * 64 + (string.byte(s, i + 2) - 128)
            nbyte = 3
        elseif c < 248 then
            resdata = (c - 240) * 262144 + (string.byte(s, i + 1) - 128) * 4096 + (string.byte(s, i + 2) - 128) * 64 + (string.byte(s, i + 3) - 128)
            nbyte = 4
        end
        ucsdata = ucsdata .. string.format("%04X", resdata):fromHex()
        i = i + nbyte
    end
    return ucsdata
end

-- 解析address digits
local function bcd_number_to_ascii(bcd_number, sender_address_length_raw)
    local length = #bcd_number
    local prefix = ""
    local converted_number = ""

    if length % 2 ~= 0 then
        log.warn("pdu_helper", "BCD数字\""..bcd_number.."\"无效")
        return
    end

    -- 解析字母数字
    if bcd_number:sub(1, 2) == constants.pdu_sms_center_type.alphanumeric then
        log.debug("pdu_helper", "这是一个Alphanumeric（字母数字）"..bcd_number)
        -- 提取address digits部分
        bcd_number = bcd_number:sub(3, -1)
        local decoded_number = gsm_7bit_decode(bcd_number, false)
        log.debug("pdu_helper", "GSM-7 decoded, data: \""..decoded_number.."\"")
        decoded_number = decoded_number:fromHex()
        local decoded_number_in_utf8 = ucs2_to_utf8(decoded_number)
        log.debug("pdu_helper", "number in UTF-8: "..decoded_number_in_utf8)

        -- 取出decoded_number_in_utf8中的有效字符 = sender_address_length_raw * 4 / 7 向下取整
        decoded_number_in_utf8 = decoded_number_in_utf8:sub(1, math.floor(sender_address_length_raw * 4 / 7))

        return decoded_number_in_utf8
    end

    if bcd_number:sub(1, 2) == constants.pdu_sms_center_type.global then
        prefix = "+"
    end

    -- 去掉本地/国际标识部分
    length = length - 2
    bcd_number = bcd_number:sub(3, -1)

    -- 每次取两位，前后颠倒后，拼接至converted_number
    for i = 1, (length - (length % 2)) / 2 do
        converted_number = converted_number..bcd_number:sub(i * 2, i * 2)..bcd_number:sub(i * 2 - 1, i * 2 - 1)
    end

    if converted_number:sub(length, length):upper() == "F" then
        converted_number = converted_number:sub(1, -2)
    end

    return prefix..converted_number
end

--[[
    解析PDU短信

    返回值：
    发送者号码
    短信内容
    接收时间
    是否为长短信
    如果为长短信，分了几包
    如果为长短信，当前是第几包
    如果为长短信，短信 ID
--]]
function pdu_helper.decode_pdu(pdu, len)
    collectgarbage("collect")

    log.debug("pdu_helper", "原始PDU信息：\""..pdu.."\"，长度："..len)

    --[[
    不包括短信息中心号码的PDU数据

    计算：
    1. #pdu / 2
    字符串中每两个字符为1位16进制数，即计算完整PDU的字节数

    2. (#pdu / 2 - len)
    len为从PDU报头开始计算的报文字节数，如此相减即可得到PDU First Octet的上一字节的位置

    3. (#pdu / 2 - len) * 2 + 1
    乘二，得到PDU First Octet上一字节在PDU字符串中的位置；加一将偏移量指向PDU First Octet的第一个字符
    --]]
    pdu = pdu:sub((#pdu / 2 - len) * 2 + 1)

    local long_sms = false
    -- TP-Message-Type-Indicator
    -- https://www.cnblogs.com/dajianshi/archive/2013/01/25/2876151.html
    local first_octet = tonumber("0x"..pdu:sub(1, 1))
    log.debug("pdu_helper", "First Octet: "..first_octet)
    if first_octet & 0x4 ~= 0 then
        long_sms = true
        log.debug("pdu_helper", "Long SMS")
    end

    local offset = 3

    -- 源地址数字个数
    local sender_address_length = tonumber(string.format("%d", "0x"..pdu:sub(offset, offset + 1)))
    -- 发件人号码长度(原始值)
    local sender_address_length_raw = sender_address_length
    log.debug("pdu_helper", "sender address length: "..sender_address_length)
    offset = offset + 2

    -- 加上号码类型2位，如果号码长度为奇数，那么再加1位F
    sender_address_length = sender_address_length % 2 == 0 and sender_address_length + 2 or sender_address_length + 3
    local sender_number_bcd = pdu:sub(offset, offset + sender_address_length - 1)
    local sender_number = bcd_number_to_ascii(sender_number_bcd, sender_address_length_raw)
    log.debug("pdu_helper", "sender_number: "..sender_number)

    offset = offset + sender_address_length

    -- 协议标识 (TP-PID)
    local protocol_identifier = tonumber(string.format("%d", "0x"..pdu:sub(offset, offset + 1)))
    log.debug("pdu_helper", "TP-PID: "..protocol_identifier)
    offset = offset + 2

    -- 用户信息编码方式
    local dcs = tonumber(string.format("%d", "0x"..pdu:sub(offset, offset + 1)))
    log.debug("pdu_helper", "Data Coding Scheme: "..dcs)
    offset = offset + 2

    local timestamp = pdu:sub(offset, offset + 13)--时区7个字节
    log.debug("pdu_helper", "timestamp: "..timestamp)
    offset = offset + 14

    local sms_receive_time = ""
    for i = 1, 6 do
        sms_receive_time = sms_receive_time .. timestamp:sub(i * 2, i * 2) .. timestamp:sub(i * 2 - 1, i * 2 - 1)

        if i <= 3 then
            sms_receive_time = i < 3 and (sms_receive_time .. "/") or (sms_receive_time .. ",")
        elseif i < 6 then
            sms_receive_time = sms_receive_time .. ":"
        end
    end

    local timezone = timestamp:sub(13,14)
    timezone = tonumber(timezone, 16)
    local tzNegative = (timezone & 0x08) == 0x08
    timezone = timezone & 0xF7 -- 按位与 1111 0111
    timezone = tonumber(string.format("%x", timezone):sub(2,2) .. string.format("%x", timezone):sub(1,1)) * 15 / 60

    if tzNegative then
        timezone = -timezone
    end
    sms_receive_time = sms_receive_time..string.format("%+03d",timezone)

    -- 短信文本长度
    local content_length = tonumber(string.format("%d", "0x"..pdu:sub(offset, offset + 1)))
    log.debug("pdu_helper", "Content Length: "..content_length)
    offset = offset + 2

    local sms_id
    local current_idx
    local total_message_count
    if long_sms then
        local header_length = tonumber(pdu:sub(offset, offset + 1), 16)
        log.debug("pdu_helper", "Header length: "..header_length)

        -- 指针走到header中的长短信 ID
        -- 2 位 UDH 长度，2 位类型，2 位信息长度
        offset = offset + 2 + 4

        -- 指针走到header中的长短信总条数
        -- header有两种，6位header的剩余协议头长度为5，7位header的剩余协议头长度为6
        if header_length == 5 then
            sms_id = tonumber(pdu:sub(offset, offset+1), 16)
            offset = offset + 2
        else
            sms_id = tonumber(pdu:sub(offset, offset+3), 16)
            offset = offset + 4
        end

        total_message_count = tonumber(pdu:sub(offset, offset + 1), 16)
        offset = offset + 2
        current_idx = tonumber(pdu:sub(offset, offset + 1), 16)
        offset = offset + 2

        log.debug("pdu_helper", "current index: "..current_idx..", total: "..total_message_count)
    end

    -- 短信文本
    local data = pdu:sub(offset, offset + content_length * 2 - 1)

    local decoded_sms_content
    local sms_content_in_utf8
    if dcs == 0x00 then -- 7bit encode
        log.debug("pdu_helper", "Incoming GSM-7 data: "..data..", is long SMS: "..tostring(long_sms))
        decoded_sms_content = gsm_7bit_decode(data, long_sms)
        log.debug("pdu_helper", "GSM-7 decoded, data: \""..decoded_sms_content.."\"")
        decoded_sms_content = decoded_sms_content:fromHex()
        sms_content_in_utf8 = ucs2_to_utf8(decoded_sms_content)
        log.debug("pdu_helper", "SMS content in UTF-8: "..sms_content_in_utf8)
    elseif dcs == 0x04 then -- 8bit encode
        log.debug("pdu_helper", "Incoming 8 bit data:", data)
        decoded_sms_content = gsm_8bit_decode(data)
        log.debug("pdu_helper", "GSM-8 decoded, data: \""..decoded_sms_content.."\"")
        sms_content_in_utf8 = decoded_sms_content:fromHex()
        log.debug("pdu_helper", "SMS content in UTF-8: "..sms_content_in_utf8)
    elseif dcs == 0x08 then -- UCS2
        log.debug("pdu_helper", "Incoming UCS2 data: "..data)
        sms_content_in_utf8 = data:fromHex()
        sms_content_in_utf8 = ucs2_to_utf8(sms_content_in_utf8)
        log.debug("pdu_helper", "Decoded UCS2 data: "..sms_content_in_utf8)
    end

    return sender_number, sms_content_in_utf8, sms_receive_time, long_sms, total_message_count, current_idx, sms_id
end

-- 生成PDU短信编码
-- 仅支持单条短信，传入数据为utf8编码
-- 返回值为pdu编码与长度
function pdu_helper.encode_pdu(num,data)
    data = utf8_to_ucs2(data):toHex()
    local numlen, datalen, pducnt, pdu, pdulen, udhi = string.format("%02X", #num), #data / 2, 1, "", "", ""
    if datalen > 140 then--短信内容太长啦
        data = data:sub(1, 140 * 2)
    end
    datalen = string.format("%02X", datalen)
    pdu = "001110" .. numlen .. number_to_bcd_number(num) .. "000800" .. datalen .. data
    return pdu, #pdu // 2 - 1
end

return pdu_helper
