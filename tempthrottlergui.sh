#!/bin/bash

# based on temp-throttle (http://github.com/Sepero/temp-throttle/) 
# original script by Sepero 2013 (sepero 111 @ gmail . com)

# getXuser found in acpi scripts
# preamble largely based on yad notification example

# NAME:         tempthrottlergui.sh
# VERSION:      0.1
# AUTHOR:       (c) 2013 Glutanimate
# DESCRIPTION:  simple GUI frontend for temp-throttle
# FEATURES:     - GUI selection of temperature limit
#               - systray indicator with information on current throttle/unthrottle
#                 (hover to show as a tooltip)
#               - original frequency is restored on exit
#
# DEPENDENCIES: yad libnotify-bin
#               (yad is an advanced Zenity fork (https://code.google.com/p/yad/). It has yet to be
#                packaged in the official Ubuntu repos but can be installed from the following 
#                webupd8 PPA: y-ppa-manager)
#
# LICENSE:      GNU GPL 2.0
#
# NOTICE:       THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
#               INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR
#               PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE
#               LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, 
#               TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE 
#               OR OTHER DEALINGS IN THE SOFTWARE.
#
#
# WARNING:      This script is probably kind of crude in some parts.
# USAGE:        1.) The script has to be executed with root privileges. `gksudo` will not work.
#                   (CLI: `sudo tempthrottlergui.sh`, GUI: `pkexec --user root tempthrottlergui.sh` or
#                    `sh -c "pkexec --user root tempthrottlergui.sh"`)
#               2.) Select the desired temperature limit and hit OK
#               3.) the temp-throttle code should now do its magic. You can check the current status
#                   of the script by hovering over the systray indicator
#               4.) you can exit the script from the right click menu of the indicator. CPU frequencies
#                   will be restored.


######## Basic parameters for yad ##########

TITLE="Temperature throttler"
WMCLASS="tempthrottler"
ICON=utilities-system-monitor # Define application icon
TRAYICON=utilities-system-monitor # Define systray icon

######## Check if script has Root privileges ########

if [ "$(whoami)" != "root" ]; then
  echo "Not root. Restarting"
  pkexec --user root "$0"
  exit
fi

####### Set environment variables required for Root ###########

getXuser() {
        user=`pinky -fw | awk '{ if ($2 == ":'$displaynum'" || $(NF) == ":'$displaynum'" ) { print $1; exit; } }'`
        if [ x"$user" = x"" ]; then
                startx=`pgrep -n startx`
                if [ x"$startx" != x"" ]; then
                        user=`ps -o user --no-headers $startx`
                fi
        fi
        if [ x"$user" = x"" ]; then
               user=$(pinky -fw | awk '{ print $1; exit; }')
        fi
        if [ x"$user" != x"" ]; then
                userhome=`getent passwd $user | cut -d: -f6`
                export XAUTHORITY=$userhome/.Xauthority
        else
                export XAUTHORITY=""
        fi
        export XUSER=$user
}


for x in /tmp/.X11-unix/*; do
   displaynum=`echo $x | sed s#/tmp/.X11-unix/X##`
   getXuser;
      if [ x"$XAUTHORITY" != x"" ]; then
        export DISPLAY=":$displaynum"
      fi
done

######## FUNCTIONS ##########

# Generic  function for printing an error and exiting.
err_exit () {
	echo ""
	echo "Error: $@" 1>&2
	su "$user" -c "notify-send -i \"$ICON\" \"Temperature throttler\" \"ERROR: $@\""
	exit 128
}

#set global variables

setglobvar () {
# The frequency will increase when low temperature is reached.
LOW_TEMP=$(($MAX_TEMP - 5))

CORES=$(nproc) # Get number of CPU cores.
CORES=$(($CORES - 1)) # Subtract 1 from $CORES for easier counting later.

# Temperatures internally are calculated to the thousandth.
MAX_TEMP=${MAX_TEMP}000
LOW_TEMP=${LOW_TEMP}000

FREQ_FILE="/sys/devices/system/cpu/cpu0/cpufreq/scaling_available_frequencies"
FREQ_MIN="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_min_freq"
FREQ_MAX="/sys/devices/system/cpu/cpu0/cpufreq/cpuinfo_max_freq"

# Store an array of the available cpu frequencies in FREQ_LIST.
if [ -f $FREQ_FILE ]; then
	# If $FREQ_FILE exists, get frequencies from it.
	FREQ_LIST=$(cat $FREQ_FILE) || err_exit "Could not read available cpu frequencies from file $FREQ_FILE"
elif [ -f $FREQ_MIN -a -f $FREQ_MAX ]; then
	# Else if $FREQ_MIN and $FREQ_MAX exist, generate a list of frequencies between them.
	FREQ_LIST=$(seq $(cat $FREQ_MAX) -100000 $(cat $FREQ_MIN)) || err_exit "Could not compute available cpu frequencies"
else
	err_exit "Could not determine available cpu frequencies"
fi

FREQ_LIST_LEN=$(echo $FREQ_LIST | wc -w)

# CURRENT_FREQ will save the index of the currently used frequency in FREQ_LIST.
CURRENT_FREQ=2
}


# Set the maximum frequency for all cpu cores.
set_freq () {
	FREQ_TO_SET=$(echo $FREQ_LIST | cut -d " " -f $CURRENT_FREQ)
	echo $FREQ_TO_SET
	for i in $(seq 0 $CORES); do
		echo $FREQ_TO_SET > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
	done
}

# Restore maximum frequency
restore_freq () {
        if [ "$NORESTORE" = 1 ]; then
          exit
        fi
        su "$user" -c "notify-send -i \"$ICON\" \"Temperature throttler\" \"Frequency restored.\""
	FREQ_TO_SET=$(cat $FREQ_MAX)
	for i in $(seq 0 $CORES); do
		echo $FREQ_TO_SET > /sys/devices/system/cpu/cpu$i/cpufreq/scaling_max_freq
	done
	echo "restoring to $FREQ_TO_SET"
}

# Will reduce the frequency of cpus if possible.
throttle () {
	if [ $CURRENT_FREQ -lt $FREQ_LIST_LEN ]; then
		CURRENT_FREQ=$(($CURRENT_FREQ + 1))
		set_freq $CURRENT_FREQ
		echo "tooltip:throttled to $FREQ_TO_SET" >&3
	fi
}

# Will increase the frequency of cpus if possible.
unthrottle () {
	if [ $CURRENT_FREQ -ne 1 ]; then
		CURRENT_FREQ=$(($CURRENT_FREQ - 1))
		set_freq $CURRENT_FREQ
		echo "tooltip:unthrottled to $FREQ_TO_SET" >&3
	fi
}


# Get the system temperature.
get_temp () {

	# If one of these doesn't work, then try uncommenting another.
	
	TEMP=$(cat /sys/class/thermal/thermal_zone0/temp)
	#TEMP=$(cat /sys/class/hwmon/hwmon0/temp1_input)
	#TEMP=$(cat /sys/class/hwmon/hwmon1/device/temp1_input)
}

# Mainloop
mainloop () {
su "$user" -c "notify-send -i \"$ICON\" \"Temperature throttler\" \"Throttler activated.\""
while true; do
	get_temp
	if   [ $TEMP -gt $MAX_TEMP ]; then # Throttle if too hot.
		throttle
	elif [ $TEMP -le $LOW_TEMP ]; then # Unthrottle if cool.
		unthrottle

	fi
	sleep 3
done
}


# select maximum temperature
tempselect () {
MAX_TEMP=$(yad --title="$TITLE" \
          --image=$ICON \
          --window-icon=$ICON \
          --class="$WMCLASS" \
          --text="Please set a temperature limit (°C)." \
          --scale \
          --value=80 \
          --min-value=70 \
          --max-value=95 \
          --step=1 \
          --mark=recommended:80 \
          --mark=MAX:95 \
          --mark=MIN:70 \
          --button="Throttle":0 \
          --button="Abort":1)
RET=$?

if [ "$RET" = 252 ] || [ "$RET" = 1 ]  # WM-Close or "Abort"
  then
      NORESTORE=1
      kill -s TERM $TOP_PID
fi

echo "$MAX_TEMP"
}


systray () {
MENU="Exit!kill -s TERM $TOP_PID!exit"

echo "menu:$MENU" >&3

yad --notification \
--image="$TRAYICON" \
--listen --no-middle \
--command="" <&3
}


######## Preamble ##########

# Store parent PID
export TOP_PID=$$

# create a FIFO file, used to manage the I/O redirection from shell
PIPE=$(mktemp -u --tmpdir ${0##*/}.XXXXXXXX)
mkfifo $PIPE

# attach a file descriptor to the file
exec 3<> $PIPE

trap "restore_freq; echo "quit" >&3; rm -f $PIPE; kill -s TERM $TOP_PID" EXIT


######## Execution ##########

tempselect
setglobvar
systray&
mainloop
