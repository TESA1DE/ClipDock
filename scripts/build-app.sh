#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Set DEVELOPER_DIR if your active developer directory points at CommandLineTools.
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
xcodebuild -project ClipDock.xcodeproj -scheme ClipDock -configuration Release \
  -derivedDataPath /tmp/ClipDock-DerivedData ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO CODE_SIGN_IDENTITY=- CODE_SIGNING_REQUIRED=NO build
mkdir -p /tmp/ClipDock-Release
/usr/bin/ditto --norsrc --noextattr /tmp/ClipDock-DerivedData/Build/Products/Release/ClipDock.app /tmp/ClipDock-Release/ClipDock.app
/usr/bin/codesign --verify --deep --strict /tmp/ClipDock-Release/ClipDock.app
printf '\nBuilt /tmp/ClipDock-Release/ClipDock.app\n'
