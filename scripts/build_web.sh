#!/usr/bin/env bash
set -euo pipefail

FLUTTER_VERSION="3.47.2"
FLUTTER_DIR=".flutter-sdk"
ARCHIVE="/tmp/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  rm -rf "${FLUTTER_DIR}" /tmp/flutter
  curl -fsSL "${URL}" -o "${ARCHIVE}"
  mkdir -p /tmp/flutter
  tar -xJf "${ARCHIVE}" -C /tmp
  mv /tmp/flutter "${FLUTTER_DIR}"
fi

git config --global --add safe.directory "/vercel/path0/${FLUTTER_DIR}" 2>/dev/null || true
git config --global --add safe.directory "$(pwd)/${FLUTTER_DIR}" 2>/dev/null || true

"${FLUTTER_DIR}/bin/flutter" config --enable-web
"${FLUTTER_DIR}/bin/flutter" pub get

if [ -n "${BASE_HREF:-}" ]; then
  "${FLUTTER_DIR}/bin/flutter" build web --release --base-href "${BASE_HREF}"
else
  "${FLUTTER_DIR}/bin/flutter" build web --release
fi
