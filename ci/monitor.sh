#!/bin/sh
# Polls the app and engine processes while Vyrax Free connects.
for i in 1 2 3 4 5 6; do
  sleep 40
  echo "=== t=$((i * 40))s ===" >> state.txt
  adb shell pidof com.amyrax.vyrax >> state.txt || echo "app-dead" >> state.txt
  adb shell pidof com.amyrax.vyrax:uacpow >> state.txt || echo "engine-dead" >> state.txt
  adb shell dumpsys window | grep mCurrentFocus >> state.txt || true
  adb exec-out screencap -p > "06-connect-$((i * 40))s.png"
  adb logcat -d -s VyraxPow:V | tail -8 >> state.txt || true
done
adb shell ls -l /data/tombstones > tombstones.txt 2>&1 || true
adb shell sh -c 'cat /data/tombstones/tombstone_* 2>/dev/null | head -300' > tombstone.txt 2>&1 || true
adb shell dumpsys activity processes > processes.txt 2>&1 || true
adb logcat -d > logcat-full.txt || true
adb shell dmesg > dmesg.txt 2>&1 || true
