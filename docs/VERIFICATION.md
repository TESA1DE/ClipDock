# Verification — 0.3.0 candidate

Environment: macOS 27.0.1, Xcode macOS 27 SDK, Apple Silicon development host.

## Automated

- Existing 25 tests: core history/settings/persistence and native clipboard
  integration passed during this change.
- Action round-trip/edit/delete, corrupt/future data preservation and duplicate ID
  rejection tested in temporary directories.
- Script validation checks format, bounded reads, NUL rejection and paths with spaces.
- Script execution uses a harmless fixture in a temporary directory; no user scripts run.
- Release builds target both arm64 and x86_64; ad-hoc bundle integrity is verified.

## UI observed on development host

- App launched outside Xcode; Settings titlebar covers the full width.
- Actions editor and asynchronous file picker opened successfully.
- Created a temporary Calculator launch action, saved it, ran it (success shown),
  then deleted the temporary definition.

## UNVERIFIED_MANUAL — release gates

- Editing existing actions, shortcut recording and conflicts.
- Confirm/cancel scripts through the GUI; ON/OFF cycling and exit-status display.
- App launch/quit including unsaved documents and permission denial.
- Physical F1–F12 behavior; manual original-setting restoration.
- Game Mode ON/OFF with LinearMouse absent, already running and launched by ClipDock.
- Crash/restart recovery warning and manual cleanup of external effects.
- Accessibility-approved paste and destination-dependent drag acceptance.
- Clean-machine install, macOS 14, Intel hardware and Gatekeeper behavior.
- GitHub Actions and release downloads should be checked for each tag.

Automated success is not proof of these manual behaviors. This candidate must not
be represented as a fully verified public release until the gates are completed.
No screenshots are included because no new, synthetic-data UI capture was verified.
