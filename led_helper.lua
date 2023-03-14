local led_helper = {}

local sys = require("sys")
local config = require("config")
local constants = require("constants")
local utils = require("utils")

local status_led = gpio.setup(
    constants.gpio[config.board_type].LED_A,
    0,
    gpio.PULLUP)

local working_led = gpio.setup(
    constants.gpio[config.board_type].LED_B,
    0,
    gpio.PULLUP
)

local function stop_and_clear_timer(timer)
    sys.timerStop(timer)
    timer = nil
end

local is_status_led_on = true
local status_led_blink_timer = nil
function led_helper.blink_status_led(duration)
    if status_led_blink_timer then
        stop_and_clear_timer(status_led_blink_timer)
    end

    status_led_blink_timer = sys.timerLoopStart(
        function ()
            status_led(is_status_led_on and 1 or 0)
            is_status_led_on = not is_status_led_on
        end,
        duration)
end

local is_working_led_on = true
local working_led_blink_timer = nil
function led_helper.blink_working_led(duration)
    if working_led_blink_timer then
        stop_and_clear_timer(working_led_blink_timer)
    end

    working_led_blink_timer = sys.timerLoopStart(
        function ()
            working_led(is_working_led_on and 1 or 0)
            is_working_led_on = not is_working_led_on
        end,
        duration
    )
end

function led_helper.light_status_led()
    if status_led_blink_timer then
        stop_and_clear_timer(status_led_blink_timer)
    end

    status_led(1)
end

function led_helper.shut_status_led()
    if status_led_blink_timer then
        stop_and_clear_timer(status_led_blink_timer)
    end

    status_led(0)
end

function led_helper.light_working_led()
    if working_led_blink_timer then
        stop_and_clear_timer(working_led_blink_timer)
    end

    working_led(1)
end

function led_helper.shut_working_led()
    if working_led_blink_timer then
        stop_and_clear_timer(working_led_blink_timer)
    end

    working_led(0)
end

return led_helper
