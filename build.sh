#!/bin/zsh
# Builds WeChat Privacy as a universal (arm64 + x86_64) macOS app.
#
#   ./build.sh                # 1.0.0 (build 10)
#   ./build.sh 1.2.0 12       # custom version / build number
#
# Output: dist/WeChat Privacy.app  and  dist/WeChatPrivacy-<version>.zip
set -eu
cd "${0:A:h}"

VERSION="${1:-1.0.0}"
BUILD="${2:-10}"
MIN_MACOS="14.0"
DIST="dist"
APP="$DIST/WeChat Privacy.app"
CACHE="/tmp/wechat-privacy-module-cache"
STAGE="/tmp/wechat-privacy-stage"

rm -rf "$DIST" "$STAGE"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$STAGE/SeeNoEvil.iconset"

echo "==> compiling (swiftc, universal)"
for arch in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -O \
    -target "${arch}-apple-macos${MIN_MACOS}" \
    -module-cache-path "$CACHE" \
    Sources/WeChatPrivacy.swift \
    -o "$STAGE/WeChatPrivacy-$arch" \
    -framework AppKit -framework SwiftUI -framework LocalAuthentication \
    -framework LocalAuthenticationEmbeddedUI -framework CoreGraphics
done
lipo -create -output "$APP/Contents/MacOS/WeChatPrivacy" \
  "$STAGE/WeChatPrivacy-arm64" "$STAGE/WeChatPrivacy-x86_64"

echo "==> rendering app icon"
xcrun swift -module-cache-path "$CACHE" tools/make-icon.swift "$STAGE/SeeNoEvil.iconset"

echo "==> packing .icns"
python3 - "$STAGE" "$APP" <<'ICON'
import struct, sys
from pathlib import Path
stage, app = Path(sys.argv[1]), Path(sys.argv[2])
iconset = stage / 'SeeNoEvil.iconset'
entries = [('icp4', 'icon_16x16.png'), ('icp5', 'icon_32x32.png'), ('icp6', 'icon_32x32@2x.png'),
           ('ic07', 'icon_128x128.png'), ('ic08', 'icon_256x256.png'), ('ic09', 'icon_512x512.png'),
           ('ic10', 'icon_512x512@2x.png')]
chunks = []
for kind, name in entries:
    data = (iconset / name).read_bytes()
    chunks.append(kind.encode('ascii') + struct.pack('>I', len(data) + 8) + data)
body = b''.join(chunks)
(app / 'Contents/Resources/SeeNoEvil.icns').write_bytes(b'icns' + struct.pack('>I', len(body) + 8) + body)
ICON

echo "==> writing Info.plist"
python3 - "$APP" "$VERSION" "$BUILD" "$MIN_MACOS" <<'PLIST'
import plistlib, sys
from pathlib import Path
app, version, build, minimum = Path(sys.argv[1]), sys.argv[2], sys.argv[3], sys.argv[4]
info = {
    'CFBundleIdentifier': 'local.wechat.privacy',
    'CFBundleName': 'WeChat Privacy',
    'CFBundleDisplayName': 'WeChat Privacy',
    'CFBundleExecutable': 'WeChatPrivacy',
    'CFBundlePackageType': 'APPL',
    'CFBundleShortVersionString': version,
    'CFBundleVersion': build,
    'LSMinimumSystemVersion': minimum,
    'CFBundleIconFile': 'SeeNoEvil.icns',
    'LSUIElement': True,
    'NSHighResolutionCapable': True,
}
(app / 'Contents/Info.plist').write_bytes(plistlib.dumps(info))
PLIST

echo "==> signing (ad-hoc)"
# Finder/iCloud metadata blocks codesign; strip it before sealing the bundle.
find "$APP" -name '.DS_Store' -delete 2>/dev/null || true
xattr -cr "$APP"
codesign --force --deep --sign - "$APP"
codesign --verify --deep --strict "$APP"

echo "==> self-test"
"$APP/Contents/MacOS/WeChatPrivacy" --self-test

echo "==> zipping"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$DIST/WeChatPrivacy-$VERSION.zip"

lipo -info "$APP/Contents/MacOS/WeChatPrivacy"
du -sh "$DIST/WeChatPrivacy-$VERSION.zip"
echo "==> done: $DIST/WeChatPrivacy-$VERSION.zip"
