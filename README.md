# BetterWindows

Windows-style window management for macOS: drag-to-edge snapping with an overlay preview, customizable hotkeys, and an Option-Tab window switcher with live thumbnails. A from-scratch replacement for 1Piece.

**Status:** early development. The repo currently contains the app skeleton plus hotkey-driven zone snapping (halves, quarters, maximize, center) via the Accessibility API. See the [PRD](https://github.com/davidkpipe/betterwindows/issues/1) and open issues for the roadmap.

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

## Usage

Default hotkeys (⌃⌥ is Control + Option):

| Keys | Action |
| --- | --- |
| ⌃⌥← / ⌃⌥→ | Left / right half |
| ⌃⌥↑ / ⌃⌥↓ | Top / bottom half |
| ⌃⌥Return | Maximize (visible frame — menu bar and Dock respected) |
| ⌃⌥U / ⌃⌥I | Top-left / top-right quarter |
| ⌃⌥J / ⌃⌥K | Bottom-left / bottom-right quarter |
| ⌃⌥C | Center (keeps the window's size) |

Every action applies to the focused window on whichever display it occupies. Drag-to-edge snapping arrives in a later slice.

Window control requires the macOS **Accessibility** permission (System Settings > Privacy & Security > Accessibility). Without it, invoking a hotkey shows guidance with a link to the right pane instead of failing silently. When running an unbundled dev build from a terminal, macOS may attribute the permission to the terminal app that launched it.

To develop in Xcode instead, open the package directory (`File > Open…` on the repo root) — no project file needed.

## Tests

```sh
swift test
```

Unit tests cover the OS-independent core (`BetterWindowsCore`). CI builds and tests on every push to `main` and every pull request.
