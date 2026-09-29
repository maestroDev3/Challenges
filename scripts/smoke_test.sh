#!/bin/bash
# Starttest auf dem Emulator: frische Installation und Update über die
# Vorversion. Schlägt fehl, wenn die App abstürzt oder nicht mehr läuft.
# usage: smoke_test.sh NEUE_APK VORVERSION_APK
set -u
PKG=de.maestrodev.challenges
NEW=$1
OLD=$2
LOG=smoke.log
: > "$LOG"
fail=0

launch() {
  adb logcat -c
  adb shell monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null
}

check() {
  sleep 25
  local pid
  pid=$(adb shell pidof "$PKG" | tr -d '\r')
  adb logcat -d > "logcat_$1.txt"
  local crash
  crash=$(grep -E "FATAL EXCEPTION|E/flutter|Unhandled Exception|ANR in $PKG" "logcat_$1.txt" | head -5)
  echo "== $1: pid='${pid}'" >> "$LOG"
  if [ -z "$pid" ] || [ -n "$crash" ]; then
    echo "FEHLER: $1" >> "$LOG"
    grep -A45 "FATAL EXCEPTION" "logcat_$1.txt" | head -120 >> "$LOG"
    grep -E -A12 "E/flutter|Unhandled Exception" "logcat_$1.txt" | head -80 >> "$LOG"
    grep -E "AndroidRuntime|$PKG" "logcat_$1.txt" | tail -40 >> "$LOG"
    fail=1
  else
    echo "OK: $1" >> "$LOG"
  fi
}

adb shell settings put global package_verifier_enable 0 || true

# 1) Frische Installation
timeout 240 adb install -r "$NEW" >> "$LOG" 2>&1
launch
check frisch

# 2) Update über die Vorversion (wie am Handy)
adb uninstall "$PKG" > /dev/null 2>&1
timeout 240 adb install "$OLD" >> "$LOG" 2>&1
launch
sleep 20
adb shell am force-stop "$PKG"
timeout 240 adb install -r "$NEW" >> "$LOG" 2>&1
launch
check update

cat "$LOG"
exit $fail
