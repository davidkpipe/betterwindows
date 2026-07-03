# BetterWindows

Windows-style window management for macOS: drag-to-edge snapping with an overlay preview, customizable hotkeys, and an Option-Tab window switcher with live thumbnails. A from-scratch replacement for 1Piece.

**Status:** early development. Window snapping (v0.1 scope) is functional: hotkey-driven zone snapping (halves, quarters, maximize, center) with snap-and-restore, and full drag-to-edge snapping — overlay preview during the drag, single-write commit on release, drag-away un-snap. The Option-Tab switcher (v0.2) is not built yet. See the [PRD](https://github.com/davidkpipe/betterwindows/issues/1) and open issues for the roadmap.

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
| ⌃⌥⌫ | Restore pre-snap size and position |

Every action applies to the focused window on whichever display it occupies.

Dragging a window to a screen edge previews its zone as a translucent overlay on the display under the cursor — left/right edges → halves, top edge → maximize, corners → quarters. Moving away or pressing Esc dismisses the preview. Releasing inside a zone commits the window to exactly the previewed frame: the frame is written once, on release, never during the drag (the structural fix for the revert-on-release bug that motivated this project). Dragging a snapped window away from its zone restores its pre-snap size under the cursor.

Accessibility-dependent behavior is verified with the [manual test checklist](docs/manual-test-checklist.md).

Window control requires the macOS **Accessibility** permission (System Settings > Privacy & Security > Accessibility). Without it, invoking a hotkey shows guidance with a link to the right pane instead of failing silently. When running an unbundled dev build from a terminal, macOS may attribute the permission to the terminal app that launched it.

To develop in Xcode instead, open the package directory (`File > Open…` on the repo root) — no project file needed.

## Tests

```sh
swift test
```

Unit tests cover the OS-independent core (`BetterWindowsCore`). CI builds and tests on every push to `main` and every pull request.
