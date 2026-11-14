#!/usr/bin/env bash
set -euo pipefail

APK="${APK_PATH:-${GITHUB_WORKSPACE:-$PWD}/build/app/outputs/flutter-apk/app-release.apk}"
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
BUILD_TOOLS="$(find "$BUILD_TOOLS_ROOT" -mindepth 1 -maxdepth 1 -type d | sort -V | tail -n1)"
if [[ -z "$BUILD_TOOLS" || ! -x "$BUILD_TOOLS/aapt" ]]; then
  echo "Android aapt not found under: $BUILD_TOOLS_ROOT" >&2
  exit 1
fi

BADGING="$("$BUILD_TOOLS/aapt" dump badging "$APK")"
APP_ID="$(printf '%s\\n' "$BADGING" | awk -F"'" '/^package: name=/ && !found { print $2; found=1 }')"
ACTIVITY="$(printf '%s\\n' "$BADGING" | sed -n "s/^launchable-activity: name='\\([^']*\\)'.*/\\1/p" | head -n1)"
if [[ -z "$APP_ID" || -z "$ACTIVITY" ]]; then
  echo "Could not read Android application ID or launch activity from APK" >&2
  exit 1
fi

# adb occasionally returns Broken pipe immediately after the emulator boots.
# Retry transient transport failures instead of publishing a package that
# was never actually installed and launched.
adb_retry() {
  local attempt=1
  local output
  while (( attempt <= 5 )); do
    if output="$(adb "$@" 2>&1)"; then
      printf '%s\n' "$output"
      return 0
    fi
    printf 'adb attempt %s/5 failed: %s\n' "$attempt" "$output" >&2
    adb start-server >/dev/null 2>&1 || true
    sleep $((attempt * 2))
    ((attempt++))
  done
  return 1
}

adb_retry wait-for-device
adb_retry get-state
echo "Installing $APK (applicationId=$APP_ID)"
adb_retry install -r "$APK"
adb_retry shell am start -W -n "$APP_ID/$ACTIVITY"
sleep 12
APP_PID="$(adb shell pidof "$APP_ID" 2>/dev/null | tr -d '\r' || true)"
if [[ -z "$APP_PID" ]]; then
  adb logcat -d -t 500 > /tmp/gapresan-logcat.txt || true
  tail -n 100 /tmp/gapresan-logcat.txt || true
  echo "GapResan process did not remain running after launch" >&2
  exit 1
fi

if adb logcat -d --pid="$APP_PID" | grep -E "FATAL EXCEPTION|Fatal signal"; then
  echo "Fatal crash detected in GapResan process (pid=$APP_PID)" >&2
  exit 1
fi

echo "Android emulator install and launch smoke test passed."
