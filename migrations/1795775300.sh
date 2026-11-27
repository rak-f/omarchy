echo "Disable NMI watchdog to save power and free a PMU counter"

watchdog=${OMARCHY_NMI_WATCHDOG_PATH:-/proc/sys/kernel/nmi_watchdog}
dropin=${OMARCHY_NMI_WATCHDOG_DROPIN:-/etc/sysctl.d/99-omarchy-nmi-watchdog.conf}
systemd_sysctl=${OMARCHY_SYSTEMD_SYSCTL:-/usr/lib/systemd/systemd-sysctl}

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

sudo "$systemd_sysctl" "$dropin"
