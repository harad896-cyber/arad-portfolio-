#!/usr/bin/env bash
set -euo pipefail

APK="${GITHUB_WORKSPACE:-$PWD}/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -s "$APK" ]]; then
  echo "Release APK is missing or empty: $APK" >&2
  exit 1
fi

ADB_BIN="$(command -v adb || true)"
if [[ -z "$ADB_BIN" ]]; then
  echo "adb is not available in PATH" >&2
  exit 1
fi
SDK_ROOT="$(cd "$(dirname "$ADB_BIN")/.." && pwd)"
BUILD_TOOLS_ROOT="$SDK_ROOT/build-tools"
if [[ ! -d "$BUILD_TOOLS_ROOT" ]]; then
  echo "Android build-tools directory not found: $BUILD_TOOLS_ROOT" >&2
  exit 1
fi
BUILD_TOOLS="$(find "$BUILD_TOOLS_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
if [[ -z "$BUILD_TOOLS" || ! -x "$BUILD_TOOLS/aapt" ]]; then
  echo "aapt not found under Android build-tools: $BUILD_TOOLS_ROOT" >&2
  exit 1
fi

# Do not exit awk early: with pipefail enabled, that can SIGPIPE aapt and
# make command substitution fail with status 141 before the emulator test.
APP_ID="$("$BUILD_TOOLS/aapt" dump badging "$APK" | awk -F"'" '/^package: name=/ && !found { print $2; found=1 }')"
if [[ -z "$APP_ID" ]]; then
  echo "Could not read Android application ID from APK" >&2
  exit 1
fi

echo "Installing $APK (applicationId=$APP_ID)"
adb install -r "$APK"
# Start the launcher activity directly. Monkey can abort when a background
# emulator system service (such as com.android.phone) stalls under CI load.
adb shell am start -W -a android.intent.action.MAIN \
  -c android.intent.category.LAUNCHER -p "$APP_ID"
sleep 12
APP_PID="$(adb shell pidof "$APP_ID" | tr -d "\r")"
if [[ -z "$APP_PID" ]]; then
  echo "GapResan process did not remain running after launch" >&2
  exit 1
fi

# Inspect only the app process. The emulator can emit unrelated system-service
# crashes (for example Bluetooth) which must not fail the GapResan smoke test.
if adb logcat -d --pid="$APP_PID" | grep -E "FATAL EXCEPTION|Fatal signal"; then
  echo "Fatal crash detected in GapResan process (pid=$APP_PID)" >&2
  exit 1
fi

echo "Android emulator install and launch smoke test passed."
