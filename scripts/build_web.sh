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

# Keep the Flutter asset used by splash/UI in sync with the launcher SVG.
python3 -m pip install --quiet pillow cairosvg
python3 - <<'PY'
import cairosvg
from PIL import Image
cairosvg.svg2png(url='assets/app_icon.svg', write_to='/tmp/gapresan_icon.png', output_width=1024, output_height=1024)
Image.open('/tmp/gapresan_icon.png').convert('RGB').save('assets/app_icon.jpg', quality=95)
print('Regenerated assets/app_icon.jpg from assets/app_icon.svg')
PY

"${FLUTTER_DIR}/bin/flutter" config --enable-web
"${FLUTTER_DIR}/bin/flutter" pub get

APP_VERSION="$(awk '/^version:/ {print $2; exit}' pubspec.yaml | tr -d "'\"")"
test -n "${APP_VERSION}"

if [ -n "${BASE_HREF:-}" ]; then
  "${FLUTTER_DIR}/bin/flutter" build web --release --no-wasm-dry-run --base-href "${BASE_HREF}" --dart-define="APP_VERSION=${APP_VERSION}"
else
  "${FLUTTER_DIR}/bin/flutter" build web --release --no-wasm-dry-run --dart-define="APP_VERSION=${APP_VERSION}"
fi
