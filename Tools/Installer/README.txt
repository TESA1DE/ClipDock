ClipDock 0.3.0 — folder installer

Requires macOS 14+, Apple Silicon or Intel. Xcode is not required.
Keep ClipDock.app and Install ClipDock.app together in this folder.
Open Install ClipDock.app, choose a destination and click Install.
The default is ~/Applications, without an administrator password.
Installing for all users requires write access to /Applications.

Updates ask for confirmation, close running copies and preserve history/settings.
The installer stages and verifies the bundle and attempts rollback on failure.
It does not import the sender's clipboard data. After installation, this folder
can be deleted. You can also drag ClipDock.app to Applications yourself.

This build is ad-hoc signed, without Apple Developer ID or notarization.
If macOS blocks it, follow https://support.apple.com/102445 only if you trust it.
Do not disable Gatekeeper. Managed Macs may prohibit running it.
Automatic paste requires user-granted Accessibility access; otherwise use Command-V.

Project and limitations: https://github.com/TESA1DE/ClipDock
