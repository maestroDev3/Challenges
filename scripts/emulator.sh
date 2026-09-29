#!/bin/bash
# Startet einen Android-Emulator (ohne Fenster) und führt den Starttest aus.
set -eux
SDK="$ANDROID_HOME/cmdline-tools/latest/bin"
IMAGE="system-images;android-34;google_apis;x86_64"
export PATH="$ANDROID_HOME/platform-tools:$ANDROID_HOME/emulator:$PATH"
yes | "$SDK/sdkmanager" --licenses > /dev/null || true
"$SDK/sdkmanager" --install "platform-tools" "emulator" "$IMAGE" | grep -v "^\[" | tail -5
ls -la /dev/kvm
df -h /
echo no | "$SDK/avdmanager" create avd -n smoke -k "$IMAGE" --force
emulator -avd smoke -no-window -no-audio -no-boot-anim -no-snapshot \
  -gpu swiftshader_indirect -memory 3072 > emulator-run.log 2>&1 &
timeout 300 adb wait-for-device || { echo "Emulator kommt nicht hoch"; tail -80 emulator-run.log; exit 1; }
for i in $(seq 1 90); do
  [ "$(adb shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')" = "1" ] && break
  sleep 5
done
[ "$(adb shell getprop sys.boot_completed | tr -d '\r')" = "1" ] || { echo "Boot nicht fertig"; tail -80 emulator-run.log; exit 1; }
echo "Emulator bereit"
adb shell input keyevent 82 || true
set +e
bash scripts/smoke_test.sh apks/new.apk apks/old.apk
