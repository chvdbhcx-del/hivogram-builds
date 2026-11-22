#!/usr/bin/env bash
# Emulator side of the UX exploration: install, Russian pack, offline, data snapshot, explore.
set -x
PKG=app.hivogram.android
ACT=$PKG/org.telegram.ui.LaunchActivity
OUT=${OUT:-ux}; mkdir -p "$OUT"
adb wait-for-device
adb root; sleep 3; adb wait-for-device
adb install -r -g "$APK" || exit 1
adb shell cmd uimode night ${NIGHT:-yes}
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
adb shell am start -W -n $ACT
sleep 10
adb shell am force-stop $PKG
APPUID=$(adb shell stat -c %u /data/data/$PKG | tr -d '\r')
if [ -s ru.xml ]; then
  adb shell mkdir -p /data/data/$PKG/files
  adb push ru.xml /data/data/$PKG/files/hivogram_ru.xml
fi
adb shell svc wifi disable
adb shell svc data disable
adb shell cmd connectivity airplane-mode enable || adb shell settings put global airplane_mode_on 1
# one demo start so the demo accounts exist, then snapshot the app's data
adb shell am start -W -n $ACT --ez hivogram_demo true --es hivogram_screen chats
sleep 15
adb shell am force-stop $PKG
adb shell chown -R $APPUID:$APPUID /data/data/$PKG
adb shell "tar -cf /data/local/tmp/hv.tar -C /data/data/$PKG ."
python3 .github/ux-explore/explore.py "$SCREENS"
adb logcat -d -b crash > "$OUT/crash.txt" 2>&1 || true
adb logcat -d > "$OUT/logcat.txt" 2>&1 || true
ls "$OUT" | wc -l
