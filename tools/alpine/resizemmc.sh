#!/bin/sh
# https://stackoverflow.com/a/68546843
echo -e "resizepart 1 100%\nYes\nquit" | parted /dev/mmcblk0 ---pretend-input-tty && resize2fs /dev/mmcblk0p1 && echo "resize done, please reboot" || echo "resize failed!"
