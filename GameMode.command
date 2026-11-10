#!/bin/bash
# Delegate to the installed app. ClipDock asks for confirmation before changes.
set -euo pipefail
if [[ ! -d /Applications/ClipDock.app && ! -d "$HOME/Applications/ClipDock.app" ]]; then
  printf 'Install ClipDock in Applications first.\n' >&2
  exit 1
fi
/usr/bin/open -b com.clipdock.app 'clipdock://game-mode'
