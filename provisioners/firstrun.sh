#!/bin/bash
set -e

# Redirect all stdout/stderr to a logfile on the boot partition
exec > /boot/firstrun.log 2>&1

echo "==== firstrun.sh starting at $(date) ===="

# Just make something super obvious
echo "Hello from firstrun!" > /boot/HELLO_FIRSTRUN.txt

# Mark completion so you know it fired once
touch /boot/FIRSTRUN_COMPLETED

echo "==== firstrun.sh finished at $(date) ===="

# Clean up so it doesn't keep running forever
sed -i 's| systemd.run=.*||g' /boot/cmdline.txt
rm -f /boot/firstrun.sh

# Reboot to continue normal boot flow
reboot