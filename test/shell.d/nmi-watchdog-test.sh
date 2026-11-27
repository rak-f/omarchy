#!/bin/bash

set -euo pipefail

source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/base-test.sh"

test_tmp=$(mktemp -d)
trap 'rm -rf "$test_tmp"' EXIT

dropin="$ROOT/etc/sysctl.d/99-omarchy-nmi-watchdog.conf"
migration="$ROOT/migrations/1795775300.sh"

grep -qxF -- '-kernel.nmi_watchdog = 0' "$dropin" ||
  fail "nmi-watchdog sysctl drop-in disables kernel.nmi_watchdog with leading dash"
grep -qF 'etc/sysctl.d/99-omarchy-nmi-watchdog.conf' "$ROOT/default/settings-runtime-profile" ||
  fail "settings-runtime-profile documents 99-omarchy-nmi-watchdog.conf"
pass "nmi-watchdog drop-in and runtime profile entry are present"

stub_bin="$test_tmp/bin"
mkdir -p "$stub_bin"
cat >"$stub_bin/sudo" <<'SH'
#!/bin/bash
printf '%s\n' "$*" >>"$TEST_CALLS"
SH
chmod +x "$stub_bin/sudo"

calls="$test_tmp/calls"
watchdog="$test_tmp/nmi_watchdog"

# Missing /proc/sys/kernel/nmi_watchdog is a silent no-op (e.g. ARM kernels).
PATH="$stub_bin:$PATH" TEST_CALLS="$calls" \
  OMARCHY_NMI_WATCHDOG_PATH="$test_tmp/missing" \
  OMARCHY_NMI_WATCHDOG_DROPIN="$dropin" \
  bash -e "$migration" >/dev/null
[[ ! -e $calls ]] || fail "migration must not call sudo when nmi_watchdog is absent"
pass "migration is a no-op when nmi_watchdog is absent"

# Missing shipped drop-in defers with exit 75.
printf '1\n' >"$watchdog"
set +e
PATH="$stub_bin:$PATH" TEST_CALLS="$calls" \
  OMARCHY_NMI_WATCHDOG_PATH="$watchdog" \
  OMARCHY_NMI_WATCHDOG_DROPIN="$test_tmp/missing.conf" \
  bash -e "$migration" >/dev/null
status=$?
set -e
(( status == 75 )) || fail "migration must exit 75 when drop-in is not shipped yet (got $status)"
[[ ! -e $calls ]] || fail "migration must not call sudo when deferring"
pass "migration defers with exit 75 when drop-in is missing"

# Already disabled is a no-op.
printf '0\n' >"$watchdog"
PATH="$stub_bin:$PATH" TEST_CALLS="$calls" \
  OMARCHY_NMI_WATCHDOG_PATH="$watchdog" \
  OMARCHY_NMI_WATCHDOG_DROPIN="$dropin" \
  bash -e "$migration" >/dev/null
[[ ! -e $calls ]] || fail "migration must not call sudo when nmi_watchdog is already 0"
pass "migration is a no-op when nmi_watchdog is already 0"

# Enabled (1) invokes systemd-sysctl with the shipped drop-in.
printf '1\n' >"$watchdog"
PATH="$stub_bin:$PATH" TEST_CALLS="$calls" \
  OMARCHY_NMI_WATCHDOG_PATH="$watchdog" \
  OMARCHY_NMI_WATCHDOG_DROPIN="$dropin" \
  OMARCHY_SYSTEMD_SYSCTL="/usr/lib/systemd/systemd-sysctl" \
  bash -e "$migration" >/dev/null
[[ $(<"$calls") == "/usr/lib/systemd/systemd-sysctl $dropin" ]] ||
  fail "migration must invoke systemd-sysctl with drop-in" "$(cat "$calls" 2>/dev/null)"
pass "migration applies 99-omarchy-nmi-watchdog.conf via systemd-sysctl"
