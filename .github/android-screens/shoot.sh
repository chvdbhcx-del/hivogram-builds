#!/usr/bin/env bash
# Demo screenshots of native Android Hivogram on an emulator: invented accounts, no login, no network.
set -x
PKG=app.hivogram.android
ACT=$PKG/org.telegram.ui.LaunchActivity
OUT=${OUT:-shots}
mkdir -p "$OUT"
adb wait-for-device
adb install -r -g "$APK" || exit 1
# dark system theme, clean status bar
adb shell cmd uimode night yes
adb shell settings put global sysui_demo_allowed 1
adb shell am broadcast -a com.android.systemui.demo -e command enter
adb shell am broadcast -a com.android.systemui.demo -e command clock -e hhmm 1200
adb shell am broadcast -a com.android.systemui.demo -e command battery -e level 100 -e plugged false
adb shell am broadcast -a com.android.systemui.demo -e command network -e wifi show -e level 4
adb shell am broadcast -a com.android.systemui.demo -e command notifications -e visible false
# first start creates the app's files folder, then the Russian language file goes there
adb shell am start -W -n $ACT
sleep 10
adb shell am force-stop $PKG
# the full Russian pack goes into the app's private files (root on the google_apis image)
if [ -s ru.xml ]; then
  adb root; sleep 3; adb wait-for-device
  APPUID=$(adb shell stat -c %u /data/data/$PKG | tr -d '\r')
  adb shell mkdir -p /data/data/$PKG/files
  adb push ru.xml /data/data/$PKG/files/hivogram_ru.xml
  adb shell chown -R $APPUID:$APPUID /data/data/$PKG/files
  adb shell restorecon -R /data/data/$PKG/files || true
  adb shell ls -l /data/data/$PKG/files/hivogram_ru.xml
fi
# offline: demo accounts must never reach Telegram
adb shell svc wifi disable
adb shell svc data disable
adb shell cmd connectivity airplane-mode enable || adb shell settings put global airplane_mode_on 1

n=0
for screen in chats inbox inbox_sort crm group account calls settings prefs tabs accounts search broadcasts broadcast_edit templates chat_templates groups lock chat; do
  n=$((n+1))
  adb shell am force-stop $PKG
  adb shell am start -W -n $ACT --ez hivogram_demo true --es hivogram_screen $screen
  [ $n = 1 ] && sleep 12
  sleep 9
  adb exec-out screencap -p > "$OUT/$(printf %02d $n)-$screen.png"
done
adb logcat -d > "$OUT/logcat.txt" 2>&1 || true
ls -l "$OUT"
