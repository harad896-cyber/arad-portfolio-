#!/usr/bin/env bash
set -euo pipefail

APK="${GITHUB_WORKSPACE:-$PWD}/build/app/outputs/flutter-apk/app-release.apk"
if [[ ! -s "$APK" ]]; then
  echo "Release APK is missing or empty: $APK" >&2
  exit 1
fi

ADB_BIN="$(command -v adb)"
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
  echo "aapt not found under Android build-tools" >&2
  exit 1
fi

APP_ID="$("$BUILD_TOOLS/aapt" dump badging "$APK" | sed -n "s/^package: name='\\([^']*\\)'.*/\\1/p" | head -n1)"
if [[ -z "$APP_ID" ]]; then
  echo "Could not read Android application ID from APK" >&2
  exit 1
fi

echo "Installing $APK (applicationId=$APP_ID)"
adb install -r "$APK"
adb shell monkey -p "$APP_ID" -c android.intent.category.LAUNCHER 1
sleep 20
if ! adb shell pidof "$APP_ID"; then
  echo "GapResan process did not remain running after launch" >&2
  exit 1
fi

if adb logcat -d -t 5000 | grep -E "FATAL EXCEPTION|Fatal signal"; then
  echo "Fatal Android crash detected during startup" >&2
  exit 1
fi

echo "Android emulator install and launch smoke test passed."
