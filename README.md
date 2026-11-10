# ClipDock

A small native macOS menu-bar utility for clipboard history, launching apps, and
explicitly triggered local actions. Swift, SwiftUI and AppKit; no external packages,
account, analytics or AI service.

## Requirements

macOS 14 or later, Apple Silicon or Intel. Xcode is needed only to build from source.
A personal open-source project under active development. Version 0.3.0 is experimental.

[Download pre-releases](https://github.com/TESA1DE/ClipDock/releases) · [Verification status](docs/VERIFICATION.md) · [Changelog](CHANGELOG.md)

## Install

Open `ClipDock-0.3.0.dmg`, drag **ClipDock** onto **Applications**, then eject the
image and launch the installed app. Look for the icon in the menu bar. Enable
launch at login in Settings only if desired. Run one copy at a time.

This build is ad-hoc signed, **not Developer ID signed or notarized**. Gatekeeper
may block it on another Mac. Follow [Apple's instructions](https://support.apple.com/102445)
only if you trust the source. Do not disable Gatekeeper or remove quarantine.
Downloads are available under [Releases](https://github.com/TESA1DE/ClipDock/releases).
Pre-releases are intended for testing, not as a claim of complete hardware validation.

## Features

- Search clipboard history, pin entries, preview and reuse text, links, images and files.
- Configurable limits and expiry; pinned items survive ordinary history cleanup.
- Optional clipboard expiry avoids clearing newer clipboard content.
- Drag saved text, files and images into compatible applications.
- Optional paste into the previously focused editable field, with user-granted Accessibility access.
- Quick app launcher, configurable global shortcut and panel position.
- System, light, dark, tinted and frosted-glass appearances.
- Password-manager exclusions and concealed/transient clipboard marker handling.
- Actions editor: name, description, application/script picker, global shortcut, Run, Edit, Delete.
- Launch or gracefully quit an app; execute Bash `.sh`/`.command` scripts;
  paired ON/OFF scripts with session state and exit status.
- Assisted Game Mode: manual keyboard confirmation and LinearMouse management.

## Actions

Open **Actions…** in the panel menu, then **Add action…**. Choose an app or a
trusted local UTF-8 Bash script. Toggle actions need separate ON and OFF scripts.
Assign a shortcut using Command, Option or Control. Shortcut conflicts are reported.
Click Run or press the shortcut. Scripts always show a confirmation with the full
source; loading or editing a configuration never runs code.

Scripts run as your user with Bash, a minimal environment and their directory as
working directory. They are **not sandboxed** and can modify your files. ClipDock
requests no root access. Input is closed and output is discarded; the result shows
the exit code. Scripts are limited to 128 KiB. Stop sends SIGTERM to the direct
process; descendants or a script ignoring SIGTERM require manual cleanup.
Turn toggled actions OFF before quitting. Actions and shortcuts persist; runtime
state does not. After an unclean exit, a recovery warning reminds you to restore
external effects manually. Do not use toggles for irreversible operations.

Examples: create a Launch app action for your editor; a Quit app action for an
optional utility; select `examples/hello.sh` to test an explicit script run.
No example runs automatically. Shell scripts should be noninteractive.

## Game Mode (assisted, not automatic F-key switching)

Assign a shortcut in Actions or run `GameMode.command` after installing ClipDock.
The command delegates to `clipdock://game-mode`; it does not duplicate the logic.
Every request opens a confirmation. Websites cannot silently toggle Game Mode.

1. Note the original keyboard setting, then manually enable standard F1–F12 in
   System Settings → Keyboard → Keyboard Shortcuts → Function Keys.
2. Confirm the change in ClipDock. LinearMouse is opened if installed.
3. Invoke again, restore the original keyboard setting manually, and confirm OFF.
   ClipDock requests a graceful quit only for the LinearMouse process it launched.
   A previously running instance is left alone.

On the development host (macOS 27.0.1), no reliable public automatic switching
mechanism was established. ClipDock does not write `com.apple.keyboard.fnState`,
use private APIs, automate screen coordinates, or modify SIP. The supported
alternative is [Apple's manual setting](https://support.apple.com/en-euro/guide/mac-help/mchlp2596/27/mac/27).
Keyboard behavior and full Game Mode cycling are **UNVERIFIED_MANUAL**.
If LinearMouse is missing or fails to launch, restore the keyboard setting yourself.
After a crash, restore settings and close LinearMouse manually. This is not Apple's
system Game Mode and does not change scheduling, GPU or performance settings.

## Build and test

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
swift test --scratch-path /tmp/ClipDock-tests
./scripts/build-app.sh
./scripts/build-dmg.sh /tmp/ClipDock-Release/ClipDock.app /tmp/ClipDock-0.3.0.dmg
```

The build creates a universal app outside iCloud directories, whose metadata can
invalidate code signatures. Open `ClipDock.xcodeproj` to develop in Xcode; run
`python3 scripts/generate-project.py` after adding Swift source files.
No third-party dependencies or developer-specific source paths are required.

Architecture: `Models` contains Codable data/storage and history logic; `Services`
contains clipboard, actions, app launch and keyboard integration; `Views` contains
SwiftUI screens with AppKit bridges. Actions are stored separately from clipboard
metadata to preserve older libraries. Tests cover model persistence and native
clipboard boundaries; see [verification status](docs/VERIFICATION.md).

## Uninstall

Turn OFF active actions/Game Mode, disable launch at login, quit ClipDock and move
`/Applications/ClipDock.app` (or `~/Applications/ClipDock.app`) to Trash.
To also remove personal data, delete `~/Library/Application Support/com.clipdock.app`
and the `com.clipdock.app` preferences through your normal macOS tools. This deletes
clipboard history and action definitions; back them up first. Remove Accessibility
permission from System Settings if granted. No background helper is installed.

## Known limitations

- UI/physical keyboard validation and clean-machine testing remain manual.
- Paste requires Accessibility and depends on the destination app's supported types.
- Script execution is trusted local execution, not a security sandbox or scheduler.
- App quit can be deferred by unsaved-document prompts; ClipDock never force-quits.
- Game Mode requires manual F-key setup/restoration; runtime state cannot infer
  whether an external change still applies after a crash or reboot.
- macOS 14 and Intel builds compile, but physical hardware checks are pending.
- No notarization certificate is available on the build host.

## License

[MIT](LICENSE). No Apple affiliation. LinearMouse is a separate application and is
not bundled with ClipDock.

## Continuous integration

A [GitHub Actions template](docs/github-actions-template.yml) is included. CI is not
enabled yet: the publishing token does not have workflow permission. To enable it,
place this file at `.github/workflows/build.yml` using credentials with that permission.
