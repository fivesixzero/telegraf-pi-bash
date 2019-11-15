# telegraf-pi-bash

Telegraf scripts and configs for monitoring Raspberry Pi internals.

* Throttle States
  * `vcgencmd get_throttled`
  * `/sys/devices/platform/soc/soc:firmware/get_throttled`
* SOC Temperature
  * `vcgencmd measure_temp`
  * `/sys/class/thermal/thermal_zone0/temp`
* CPU and SDRAM Voltages
  * `vcgencmd measure_volts *`
* Onboard Clocks
  * `vcgencmd measure_clock *`
* Pi-Specific Memory Spaces
  * `vcgencmd get_mem *`

## Requirements

The script is written for a default Raspbian Buster environment with a few changes.

* `bin` directory for scripts under the Pi user's home directory
  * `/home/pi/bin`
* `telegraf` installed via `influxdata` repo
  * <https://docs.influxdata.com/telegraf/v1.12/introduction/installation/>

## Usage

* Copy contents of `telegraf.d` into `/etc/telegraf/telegraf.d/`
  * `sudo cp ./telegraf.d /etc/telegraf/telegraf.d`
* Copy contents of `sudoers.d` into `/etc/sudoers.d`
  * `sudo cp ./sudoers.d/* /etc/sudoers.d`
* Copy contents of `scripts` into `/home/pi/bin`
  * `cp ./scripts/* /home/pi/bin`
* Restart `telegraf` service
  * `sudo service telegraf restart`

## Reference Data and Links

### Throttling on the Raspberry Pi platform

In general, the throttlign features of the Pi provide thermal and voltage stability protection. When voltages get too low or temperatures get too high, the SOC will reduce frequencies for the CPU, GPU and other components to reduce temperatures and load on the power supply. Often, these mitigations can prevent a total system failue even in adverse conditions at the cost of reducing performance.

Throttling has four different component states.

* **Soft Temp Limit Reached**
  * When the firmware soft temp limit is reached, the CPU frequency is reduced by 200 MHz to avoid additional temperature increase
  * Set via: `temp_soft_limit` in `/boot/config.txt`, default `60`
* **ARM Frequency Capped**
  * "Capping just limits the arm frequency (somewhere between 600MHz and 1200MHz) to try to avoid throttling."
  * This happens when the temperature reaches 80 C
* **Under-voltage**
  * If the voltage drops below 4.63V, the Pi considers itself "under-volted" and will engage throttling to reduce load
* **Throttling**
  * "Throttling removes turbo mode, which reduces core voltage, and sets arm and gpu frequencies to non-turbo value."
  * "Over-temperature occurs with temp > 85'C. The Pi is throttled"

There are also two temporal states.

* **Since Boot**
  * This indicates whether or not a throttling state has been activated since last system boot
* **Current**
  * This reflects the current state, with a rolling 3 second window.

### Getting and Using Throttle State

The current throttle state can be easily viewed via command line using `vcgencmd` or via `/sys/devices/platform/soc/soc:firmware/get_throttled` on newer Raspbian distros. The state is displayed in as a hexidecimal number representing 20 bits of relevant data. Converting this hex number to binary reveals the status bitfields.

Example: Throttled and Undervolted

```sh
pi@raspberrypi:~ $ sudo vcgencmd get_throttled
throttled=0x50005
```

Converting this output to binary using many methods will typically ignore leading zeroes though. Getting the proper 

```sh
pi@raspberrypi:~ $ dc -e '16i2o50005p'
1010000000000000101‬
```

Front-padding the output with zeroes will provide a usable binary number for bitfield analysis.

```sh
printf %020d `dc -e '16i2o50005p'`
01010000000000000101‬
```

### Throttle Flag Decoding

The throttle flags are reported by `vcgencmd` as a 20-bit hex number that provides space for 20 bitflags. Of these 20 bitflags, 8 are used as of kernel `4.14.70`. Prior to that kernel version only six flags were in use.

Most of the documentation I found via Googling appeared to be out of date or incorrect. Based on testing, this is the value map I've come up with.

```txt
Since Boot          Now
 |                   |  
0101 0000 0000 0000 0101‬
||||                ||||_ [19] throttled
||||                |||_ [18] arm frequency capped
||||                ||_ [17] under-voltage
||||                |_ [16] soft temperature capped
||||_ [3] throttling has occurred since last reboot
|||_ [2] arm frequency capped since last reboot
||_ [1] under-voltage has occurred since last reboot
|_ [0] soft temperature reached since last reboot
```

### Ref Links

<https://www.raspberrypi.org/forums/viewtopic.php?t=155379>
<https://www.raspberrypi.org/forums/viewtopic.php?t=217056>
<https://github.com/raspberrypi/firmware/commit/404dfef3b364b4533f70659eafdcefa3b68cd7ae#commitcomment-31620480>
<https://github.com/raspberrypi/linux/commit/be3035e3627d2570de4c2c612ecd095968986437>
<https://github.com/raspberrypi/linux/commit/fe7f80496fa5ae525f4153c94cedee05f1656ee9>
<https://github.com/raspberrypi/linux/blob/e2d2941326922b63d722ebc46520c3a2287b675f/drivers/hwmon/raspberrypi-hwmon.c>
<https://github.com/raspberrypi/linux/issues/2367#issuecomment-364178453>

## TODOs and Ideas

* Write a proper Golang plugin for Telegraf
  * Identify and document hardware monitoring related mailboxes for direct access
  * Find or write a Go library for reading data via mailboxes
* Move from `vcgencmd` to using `sysfs` across as many items as possible
