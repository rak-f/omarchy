echo "Disable NMI watchdog to save power and free a PMU counter"

watchdog=/proc/sys/kernel/nmi_watchdog
dropin=/etc/sysctl.d/99-omarchy-nmi-watchdog.conf

[[ -r $watchdog ]] || exit 0

# A dev checkout can run ahead of omarchy-settings: stay pending until the
# drop-in lands so the setting persists across reboots too.
if [[ ! -r $dropin ]]; then
  echo "Waiting for omarchy-settings to ship $dropin"
  exit 75
fi

current=$(<"$watchdog")
if [[ $current == "0" ]]; then
  exit 0
fi

sudo /usr/lib/systemd/systemd-sysctl "$dropin"
