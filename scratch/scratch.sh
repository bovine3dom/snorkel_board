ssh kindle
/mnt/us/extensions/onlinescreensaver/bin/update.sh # update screensaver
cd /mnt/us/extensions/onlinescreensaver/bin/

vi /mnt/us/extensions/onlinescreensaver/bin/config.sh
# [root@kindle bin]# eips -f -g /mnt/us/linkss/screensavers/bg_ss00.png  # eugh this is stretched
# https://www.mobileread.com/forums/showthread.php?t=276225 # need to force bit depth to 4. which i don't think i can do.
# but koreader displays it just fine...

wget "http://192.168.1.61:53113/graph" -O hello.png

# wakealarm doesn't work, makes onlinescreensaver update every single second lol

"
1745686810
sh: -eq: argument expected
Sat Apr 26 17:56:10 GMT+1:1100 2025: Failure setting alarm on rtc1, wanted 1745686810, got
com.lab126.powerd failed to set value for property deferSuspend (0x100 lipcPropErrInvalidState)
mv: can't preserve ownership of '/mnt/us/linkss/screensavers//bg_ss00.png': Operation not permitted
Sat Apr 26 17:56:11 GMT+1:1100 2025: Screen saver image updated
Sat Apr 26 17:56:11 GMT+1:1100 2025: Schedule 06:00-22:00=5 used, next update in 5 minutes
Sat Apr 26 17:56:11 GMT+1:1100 2025: Next update in 5 minutes
"

echo 0 > /sys/class/rtc/rtc1/wakealarm
cat /sys/class/rtc/rtc1/wakealarm

echo $(( $(date +%s) + 10 )) > /sys/class/rtc/rtc1/wakealarm
cat /sys/class/rtc/rtc1/wakealarm

lipc-send-event com.lab126.powerd.debug dbg_power_button_pressed; sleep 5; lipc-send-event com.lab126.powerd.debug dbg_power_button_pressed # this is more promising...
# but obvs it might use loads of battery because it isn't real sleep? also means that when it's enabled we can't use the kindle for reading books, lol
rtcwake --device=/dev/rtc1 -m mem --seconds=10 # this seems to work?
# ... not any more. screen goes black. :(
# everyone on the internet is using "-m no" but that doesn't seem to do anything

lipc-set-prop -i com.lab126.powerd rtcWakeup 10

lipc-wait-event -s 10 com.lab126.powerd resuming

lipc-set-prop com.lab126.cmd wirelessEnable 0 # disable wifi once working

wait_for () { 
	# calculate the time we should return
	ENDWAIT=$(( $(currentTime) + $1 ))

	# disable/reset current alarm
	echo 0 > /sys/class/rtc/rtc$RTC/wakealarm

	# set new alarm
	echo $ENDWAIT > /sys/class/rtc/rtc$RTC/wakealarm

	# check whether we could set the alarm successfully
	if [ $ENDWAIT -eq `cat /sys/class/rtc/rtc$RTC/wakealarm` ]; then
		logger "Start waiting for timeout ($1 seconds)"

		# wait for timeout to expire
		while [ $(currentTime) -lt $ENDWAIT ]; do
			REMAININGWAITTIME=$(( $ENDWAIT - $(currentTime) ))
			if [ 0 -lt $REMAININGWAITTIME ]; then
				# wait for device to suspend or to resume - this covers the sleep period during which the
				# time counting does not work reliably
				logger "Starting to wait for timeout to expire"
				lipc-wait-event -s $REMAININGWAITTIME com.lab126.powerd resuming || true
			fi
		done

		logger "Finished waiting"
	else
       		logger "Failure setting alarm on rtc$RTC, wanted $ENDWAIT, got `cat /sys/class/rtc/rtc$RTC/wakealarm`"
	fi

	# not sure whether this is required
	lipc-set-prop com.lab126.powerd -i deferSuspend 1
}

#
sshfs kindle:/ kindle_remote
cd kindle_remote/mnt/us/scratch
