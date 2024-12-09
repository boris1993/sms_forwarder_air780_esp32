# Air780E短信转发

利用ESP32驱动Air780E实现短信转发，兼容合宙ESP32S3和ESP32C3。

**⚠ 仅支持联通、移动网络，不支持电信网络 ⚠**

# 功能

- [x] 自动转发收到的短信，短信内容支持多种语言（其实就是ASCII和UCS-2字符集），目前已测试过英文、中文、日语、俄语字符
- [x] 支持多个推送平台，目前接入：
  - [x] [LuatOS社区提供的推送服务器](https://push.luatos.org/)
  - [x] Bark
  - [x] Server酱
  - [x] 钉钉机器人
  - [x] 推送加 PushPlus
  - [x] Telegram（感谢 [@wongJG](https://github.com/wongJG) 的 Pull Request）
  - [x] 飞书机器人（感谢 [@mmdjiji](https://github.com/mmdjiji) 的 Pull Request）
  - [x] 邮件 (SMTP协议，需自行开启邮箱的SMTP功能，使用SMTP协议，在刷写脚本时需要使用 "firmware\LuatOS-SoC_V1007_ESP32C3.soc"，点击“下载底层和脚本”)

# 使用方法

## 硬件组装

- 短接POW键上方的焊盘实现通电即开机

![](/image/shorting_soldering_pad_for_power_key.jpg)

- 按照下图方向为Air780e和ESP32焊上排针和排座。注意合宙不送排座，需要自己买。

| Air780E                  | ESP32S3                  |
|--------------------------|--------------------------|
| ![](/image/air780e.jpeg) | ![](/image/esp32s3.jpeg) |

- 按图示方向插入SIM卡

![](/image/sim_card_direction.jpeg)

- 按图示方向将Air780E和ESP32组合

![](/image/put_together.jpeg)

## 为Air780e刷入AT固件

USB连接Air780e，选择 `Luatools/resource/618_lua_lod/版本号` 目录下的AT固件，将其烧录到Air780e。

## 修改脚本，刷入ESP32

- 修改[`config.lua`](config.lua)
  - 修改`config.board_type`为正确的型号，可选值见注释
  - 修改`config.wifi`，填入无线网络的SSID和密码
  - 修改`config.notification_channel`，将要启用的通知通道的`enabled`配置置为`true`，并填写推送平台相关配置
- 烧录脚本
  - 将[`firmware`](firmware)目录中对应的固件烧入开发板
  - 将所有`lua`脚本下载至开发板
![](/image/burning_firmware_and_scripts.png)
  - 将开发板上电开机，等待初始化完成后，即可转发短信到配置的通知通道

# LED灯状态含义

- ESP32
  - C3的`D4`或S3的`LED A`为初始化状态灯，闪烁代表正在初始化，常亮代表初始化完成，准备转发短信
  - C3的`D5`或S3的`LED B`为工作状态灯，平时长灭，收到新短信后高频闪烁，转发完成后熄灭

| ESP32C3                     | ESP32S3                     |
|-----------------------------|-----------------------------|
| ![](/image/esp32c3_led.jpg) | ![](/image/esp32s3_led.png) |

- Air780
  - `POW`灯为电源指示灯，通电后常亮。注意，这个LED不代表开机状态，只要板子有电这个灯就会亮
  - `NET`灯为网络状态指示灯，长亮短灭代表正在初始化蜂窝网络，短亮长灭代表网络注册成功，可以接收短信

# Firmware目录下的文件说明

- `LuatOS-SoC_V1004_ESP32C3_classic.soc`对应`ESP32C3 经典款`
- `LuatOS-SoC_V1004_ESP32C3_lite.soc`对应`ESP32C3 简约款`
- `LuatOS-SoC_V1004_ESP32S3.soc`对应`ESP32S3`
- `LuatOS-SoC_V1007_ESP32C3.soc`对应`ESP32C3官方最新完整版固件(使用SMTP时需刷入此固件)`

固件均通过[合宙云编译](https://wiki.luatos.com/develop/compile/Cloud_compilation.html)精简掉了不需要的功能，以保证内存空间充足。`LuaTools`自动下载的固件不能用，系统启动之后内存就不够用了，发不出去HTTP请求。

目前固件包含`gpio`、`uart`、`pwm`、`wdt`、`crypto`、`rtc`、`network`、`sntp`、`tls`、`wlan`、`pm`、`cjson`、`ntp`、`shell`、`dbg`。

# 保活 API 说明

API 提供 GET 和 POST 请求支持。

- GET 请求返回 POST 请求存储的时间戳
- POST 请求接收 `{ "expiry": "1732622763" }`，并存储

# 致谢

本项目参考[低成本短信转发器](https://github.com/chenxuuu/sms_forwarding)而来，尤其是PDU相关代码，没有`chenxuuu`的这份项目和[50元内自制短信转发器（Air780E+ESP32C3）](https://www.chenxublog.com/2022/10/28/19-9-sms-forwarding-air780e-esp32c3.html)这篇文章，我不会这么快就完成开发。

# 赞助

| 支付宝 | 微信 | Bitcoin |
| ------ | ---- | ------- |
| ![](https://sat02pap001files.storage.live.com/y4mQubRjj6HwFcaRN5WA43bM81G13d2xI-3OAoLSsXXDxJQZ_inF6qA_OFDB51Pg3yfjXu8CSyioCTUI3StB_Dltd7vmBWNHRT0Ok8zMd9Rf_WU42mgDY-pJW_yCrJ0KEUsd32yi5xqB1wjR4lv8jzMboKmpphgwoeOpPR5xgnfhNbfU8ozvDcfnnEiCpvZ6rLk?width=548&height=542&cropmode=none) | ![](https://sat02pap001files.storage.live.com/y4mRChq9zMZbQZK0gVO19Smbyt74YG1QWTI9RAgewZpJKn6BOEg0GK-_AgR9LwdjDSJriEgnz05YSc9fYUiH09i-PKnb40lZI0AqbvtcyXJvqVSdiWbGpeqPFmIktJb2t-bjIXqrupCzZxXWPXmrrFXXdFzgSWstjebkOujhr-ByhKWoLvgn3GHu2WpnGzbKgXs?width=602&height=599&cropmode=none) | ![3H8yBE359vkbpvC4nSP5xwafWThUh4JvGB](https://sat02pap001files.storage.live.com/y4m7ll7ouERuCbkCXI1x-PQJMYTzonfgpFoEL7Odz8HwPC-O2DngJrulJd23PzD6dJnucGf1zC6zGp4PFyVZjJecRWVT69c06Y4OPdjpEh5Z3E6qkRNg1ZMuP9bxQ3R_YKt2HtjzG_BD3_a9gUkRwHm-zmNH1gxJxnSbysa_qbS8xoiFenQioB4RcU-tMZn71z8?width=1044&height=1098&cropmode=none) |
