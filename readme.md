# my snorkelling dashboard (wip)

i will probably hardcode everything here so you may not find this useful unless you live exactly where i do


# getting it on kindle

1. jailbreak

2. kual

3. linkss (the screensaver hack) - not 100% i actually need this if using KOreader

4. online screensaver
https://www.mobileread.com/forums/showthread.php?t=236104

5. for PW1 in bin/config.sh, set the URL to the right one and then also
`SCREENSAVERFILE=$SCREENSAVERFOLDER/bg_ss00.png` (maybe)
`RTC=1` (coz 0 doesn't have a wakealarm)
... this is not actually enough it's a massive palava. i replaced wait_for() in utils.sh with
`lipc-send-event com.lab126.powerd.debug dbg_power_button_pressed; sleep $1; lipc-send-event com.lab126.powerd.debug dbg_power_button_pressed # this is more promising...`
mais il reste a voir if that works. and i think it will get angry when i try to use the kindle.

it doesn't work :(

https://www.mobileread.com/forums/showthread.php?t=235821&page=3 is a promising thread

https://github.com/Kuhno92/onlinescreensaverPW2 maybe?

6. turn on auto updating on that online screensaver (do not actually do this if you have messed with utils.sh)

7. in KOreader -> settings -> screen -> sleep screen -> wallpaper -> show custom image (pick your image)


# plan b

1. copy scratch/kindle_wgetter.sh to /mnt/us/scratch/kindle_wgetter.sh

2. add 

```
* * * * * /mnt/us/scratch/kindle_wgetter.sh 2>&1 > /mnt/us/scratch/kindle_wgetter.log
```
to /etc/crontab/root

3. kill crond `kill $(ps aux | grep crond | awk '{print $2}')` and it will magically restart

# todo: 

- check if onlinescreensaver actually updates with KOreader running. (it does not on my pw1)
- it'd be nice if the ticks lined up with midday
- given the current workflow of "turn on the kindle and wait for it to go back on standby" it'd be nice if the image was rotated 90 degrees so that i could press the button without taking it out the mount


