#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
source_app="${1:-/tmp/ClipDock-Release/ClipDock.app}"
output="${2:-/tmp/ClipDock-0.3.0.dmg}"
if [[ ! -d "$source_app" || -e "$output" ]]; then
  echo 'Provide an existing ClipDock.app and an output path that does not exist.' >&2
  exit 1
fi
/usr/bin/codesign --verify --deep --strict "$source_app"
stage=$(mktemp -d /tmp/ClipDock-DMG.XXXXXX)
trap 'rm -rf "$stage"' EXIT
/usr/bin/ditto --norsrc --noextattr "$source_app" "$stage/ClipDock.app"
ln -s /Applications "$stage/Applications"
cp Tools/Installer/README-DMG.txt "$stage/INSTALL.txt"
cp GameMode.command "$stage/GameMode.command"
cp LICENSE "$stage/LICENSE.txt"
/usr/bin/hdiutil create -volname 'ClipDock' -srcfolder "$stage" -format UDZO -ov "$output"
/usr/bin/hdiutil verify "$output"
printf '\nDMG: %s\n' "$output"
