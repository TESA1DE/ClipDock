#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
output="${1:-/tmp/ClipDock-Setup}"
if [[ -e "$output" ]]; then
  echo "Output already exists: $output" >&2
  exit 1
fi
xcodebuild -project ClipDock.xcodeproj -scheme ClipDock -configuration Release \
  -derivedDataPath /tmp/ClipDock-SetupBuild ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
mkdir -p "$output/Install ClipDock.app/Contents/MacOS" "$output/Install ClipDock.app/Contents/Resources"
/usr/bin/ditto --norsrc --noextattr /tmp/ClipDock-SetupBuild/Build/Products/Release/ClipDock.app "$output/ClipDock.app"
work=$(mktemp -d /tmp/ClipDock-InstallerBuild.XXXXXX)
trap 'rm -rf "$work"' EXIT
for arch in arm64 x86_64; do
  xcrun swiftc -swift-version 5 -parse-as-library -O -target "$arch-apple-macosx14.0" \
    Tools/Installer/InstallerEngine.swift Tools/Installer/InstallerApp.swift -o "$work/installer-$arch"
done
xcrun lipo -create "$work/installer-arm64" "$work/installer-x86_64" -output "$output/Install ClipDock.app/Contents/MacOS/ClipDockInstaller"
cp Tools/Installer/Info.plist "$output/Install ClipDock.app/Contents/Info.plist"
cp ClipDock/Resources/ClipDock.icns "$output/Install ClipDock.app/Contents/Resources/ClipDock.icns"
cp Tools/Installer/README.txt "$output/INSTALL.txt"
cp LICENSE "$output/LICENSE.txt"
codesign --force --sign - --options runtime --timestamp=none "$output/Install ClipDock.app"
codesign --verify --deep --strict "$output/ClipDock.app"
codesign --verify --deep --strict "$output/Install ClipDock.app"
"$output/Install ClipDock.app/Contents/MacOS/ClipDockInstaller" --self-test
printf '\nSetup folder: %s\n' "$output"
