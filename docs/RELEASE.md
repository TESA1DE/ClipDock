# Release preparation

## Automated checks

- `swift test`
- `./scripts/build-app.sh`
- Universal xcodebuild command in README; inspect both architectures with `lipo -archs`.
- Confirm no source compiler warnings. App Intents metadata extraction may report that no AppIntents dependency exists; ClipDock does not implement App Intents.

## Manual acceptance checks

Use synthetic data. Never record or publish personal clipboard contents.

- [ ] Fresh install: menu bar icon, welcome buttons, no Dock icon by default.
- [ ] Copy text, URL, path, files, JSON, hex color, image; inspect previews and copy back.
- [ ] Search by text, filename, path, and accented characters.
- [ ] Deduplicate repeated values, including a pinned value.
- [ ] Pin, unpin, delete, clear history, and confirm/cancel Clear Everything.
- [ ] Restart and check pins, app order, disabled apps, preferences, and saved history.
- [ ] Disable history persistence, restart, and confirm only pins remain.
- [ ] Add actual apps with the picker; enable/disable, reorder, launch, activate, reveal, remove.
- [ ] Deleted or moved app path: resolve by bundle ID or display an error.
- [ ] Option + Space from another application focuses search; type immediately.
- [ ] Change shortcut, test conflict handling, restore default.
- [ ] Arrow keys, Return, Command + P/Delete/F/1/2, Tab, Escape, app numbers.
- [ ] Grant Accessibility manually, focus a TextEdit/browser/chat field, open ClipDock, then select text/image/file and confirm insertion where supported.
- [ ] With permission denied or a non-editable destination, confirm copy-only fallback without sending keystrokes.
- [ ] Change destination focus before selection: confirm automatic paste cancels safely.
- [ ] Drag text, PNG, one file, and multiple files into compatible targets; cancel a drag and confirm the panel remains usable.
- [ ] Automatic/light/dark/tinted/transparent themes, all tint colors, Reduce Transparency override.
- [ ] Age labels at 59 seconds, 1 minute, 59 minutes, 1 hour, and 1 hour 1 minute.
- [ ] Expire history with pins; confirm optional system clipboard expiration never clears a newer value.
- [ ] Upgrade a v1 library: confirm history, custom hotkey, app order, and preferences survive.
- [ ] Light/dark/system, compact rows, increased contrast, reduced motion, VoiceOver.
- [ ] Center/menu bar/cursor placement on multiple monitors, Spaces, full-screen apps.
- [ ] Login registration from Applications, approval and removal in System Settings.
- [ ] Excluded app before/after polling boundary; concealed and transient pasteboard markers.
- [ ] Large image/text input, missing image, unreadable or corrupt metadata, full disk.
- [ ] Idle CPU/memory over a long session; large unlimited library search latency.
- [ ] macOS 14 physical Apple Silicon and Intel systems.

## Distribution

1. Set release version/build number in `ClipDock/Resources/Info.plist`.
2. Archive using a Developer ID Application identity and your Apple developer team.
3. Export a Developer ID-signed app with hardened runtime enabled.
4. Submit a zipped app to Apple's notary service using your own credential profile.
5. Staple the accepted notarization ticket, verify Gatekeeper assessment, and test a clean-machine install.
6. Publish the signed archive, checksums, release notes, and synthetic-data screenshots.

Do not commit signing certificates, keychain exports, credentials, or build artifacts. Local ad-hoc signing is not a substitute for notarization.
