#!/bin/bash
#
# telegraf-pi-get-throttled.sh
#
# Get and parse RPi throttled state to produce single Grok-ready string.
#
# * Root access is required for this script to run properly, since it relies on vcgencmd to poll the VideoCore mailbox for the throttle state.

### Data Acquisition
# Poll the VideoCore mailbox using vcgencmd to get the throttle state then use sed to grab just the hex digits
throttle_state_hex=$(sudo /opt/vc/bin/vcgencmd get_throttled | sed -e 's/.*=0x\([0-9a-fA-F]*\)/\U\1/')

### Example vars for testing
## Debug: uv=1 uvb=1 afc=0 afcb=0 tr=1 trb=0 str=0 (null) strb=0 (null)
# throttle_state_hex=50005
## Debug: uv=0 uvb=1 afc=0 afcb=0 tr=0 trb=0 str=0 (null) strb=0 (null)
# throttle_state_hex=50000
## Debug: uv=1 uvb=1 afc=1 afcb=1 tr=1 trb=1 str=1 strb=1
# throttle_state_hex=F000F
## Debug: uv=1 uvb=1 afc=0 afcb=1 tr=0 trb=1 str=0 strb=1
# throttle_state_hex=F0008
## Debug: uv=0 uvb=1 afc=0 afcb=1 tr=0 trb=1 str=1 strb=1
# throttle_state_hex=F0001

### Command Examples
## dc: Convert hex to dec or binary (useful for get_throttled output)
# Example: dc -e 16i2o50005p
# Syntax: dc -e <base_in>i<base_out>o<input>p
#   i = push base_in (previous var) to stack
#   o = push base_out (previous var) to stack
#   p = print conversion output with newline to stdout

get_base_conversion () {
  args=${1}i${2}o${3}p
  binary=$(dc -e $args)
  if [[ $(echo $binary | wc -c) -le 20 ]]; then
    printf %020d $binary
  else
    printf $binary
  fi
}

throttle_state_bin=$(get_base_conversion 16 2 $throttle_state_hex)

binpattern="[0-1]{20}"
if [[ $throttle_state_bin =~ $binpattern ]]; then
## Reference: get_throttled bit flags
  # https://github.com/raspberrypi/firmware/commit/404dfef3b364b4533f70659eafdcefa3b68cd7ae#commitcomment-31620480
  #
  # NOTE: These ref numbers are reversed compared to vcencmd output.
  #
  # Since Boot          Now
  #  |                   |  
  # 0101 0000 0000 0000 0101
  # ||||                ||||_ [19] throttled
  # ||||                |||_ [18] arm frequency capped
  # ||||                ||_ [17] under-voltage
  # ||||                |_ [16] soft temperature capped
  # ||||_ [3] throttling has occurred since last reboot
  # |||_ [2] arm frequency capped since last reboot
  # ||_ [1] under-voltage has occurred since last reboot
  # |_ [0] soft temperature reached since last reboot

  strb=${throttle_state_bin:0:1}
  uvb=${throttle_state_bin:1:1}
  afcb=${throttle_state_bin:2:1}
  trb=${throttle_state_bin:3:1}
  str=${throttle_state_bin:16:1}
  uv=${throttle_state_bin:17:1}
  afc=${throttle_state_bin:18:1}
  tr=${throttle_state_bin:19:1}

  echo "uv=${uv:-0} uvb=${uvb:-0} afc=${afc:-0} afcb=${afcb:-0} tr=${tr:-0} trb=${trb:-0} str=${str:-0} strb=${strb:-0}"
fi
