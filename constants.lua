local constants = {}

constants.gpio = {
    esp32c3 = {
        LED_A = 12,
        LED_B = 13
    },
    esp32s3 = {
        LED_A = 10,
        LED_B = 11
    }
}

constants.led_blink_duration = {
    working = 50,
    initializing = 500
}

constants.pdu_sms_center_type = {
    domestic = "81",
    global = "91",
    alphanumeric = "D0"
}

constants.uart_ready_message = "UART_RECV_ID"

constants.air780_message_topic_at_received = "AT_RECEIVED"
constants.air780_message_topic_sim_detected = "SIM_DETECTED"
constants.air780_message_topic_sms_format_set = "SMS_FORMAT_SET"
constants.air780_message_topic_charset_configured = "CHARSET_CONFIGURED"
constants.air780_message_topic_new_message_notification_configured = "NEW_MESSAGE_NOTIFICATION_CONFIGURED"
constants.air780_message_topic_network_connected = "NETWORK_CONNECTED"
constants.air780_message_topic_new_sms_received = "NEW_SMS_RECEIVED"
constants.air780_message_topic_new_notification_request = "NEW_NOTIFICATION_REQUEST"

return constants
