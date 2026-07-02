# BetterWindows

Windows-style window management for macOS: drag-to-edge snapping with an overlay preview, customizable hotkeys, and an Option-Tab window switcher with live thumbnails. A from-scratch replacement for 1Piece.

**Status:** early development. The repo currently contains the app skeleton (menu-bar app, unit tests, CI). See the [PRD](https://github.com/davidkpipe/betterwindows/issues/1) and open issues for the roadmap.

## Requirements

- macOS 14 or later (developed against macOS 26)
- Xcode command line tools with Swift 5.9+ (any recent Xcode)

## Build and run

```sh
git clone https://github.com/davidkpipe/betterwindows.git
cd betterwindows
swift build
swift run
```

BetterWindows is menu-bar-only: look for the window icon in the menu bar — there is no Dock icon. The menu contains an **Enabled** toggle (persisted across relaunches) and **Quit**.

To develop in Xcode instead, open the package directory (`File > Open…` on the repo root) — no project file needed.

## Tests

```sh
swift test
```

Unit tests cover the OS-independent core (`BetterWindowsCore`). CI builds and tests on every push to `main` and every pull request.
