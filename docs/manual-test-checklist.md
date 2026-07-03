# Manual test checklist

Automated tests cover the pure modules (zone geometry, hit-testing, the drag
state machine, the restore ledger). Everything that crosses the Accessibility
API is verified manually with this checklist.

## Setup

- [ ] Build and launch: `swift run` (or a release build)
- [ ] Grant Accessibility (System Settings > Privacy & Security > Accessibility)
- [ ] Disable macOS native drag-to-edge tiling (System Settings > Desktop & Dock) to avoid double-snapping
- [ ] Status item visible; **Enabled** checked

## Apps for the matrix

Repeat the "Drag snapping" section in each of:

- [ ] Finder
- [ ] Safari
- [ ] An Electron app (e.g. VS Code, Slack)

## Drag snapping (the 1Piece revert bug — user story 5)

- [ ] Drag to the left edge: left-half preview appears; release → the window fills exactly the left half
- [ ] **Repeat the left-edge snap 20 consecutive times: the window lands in the zone every time — zero reverts to the pre-drag frame**
- [ ] Same for the right edge (right half) and the top edge (maximize), 20× each
- [ ] Drag into each corner: quarter preview; release commits the quarter
- [ ] The dragged window never resizes while the preview is showing — the frame changes only on release
- [ ] Release with no preview showing: the window stays exactly where the drag left it
- [ ] Press Esc mid-drag: the preview disappears; releasing afterwards changes nothing
- [ ] With a second display: the preview appears on the display under the cursor and the commit lands there

## Drag-away un-snap

- [ ] Snap a window (drag or hotkey), then drag it away from its zone: it returns to its pre-snap size, positioned under the cursor, while the drag continues
- [ ] Continue that drag into another zone and release: it snaps; ⌃⌥⌫ afterwards returns it to the torn-off (pre-snap-size) frame

## Hotkeys

- [ ] ⌃⌥← / → / ↑ / ↓ place halves exactly — no gaps, no menu bar/Dock overlap
- [ ] ⌃⌥U / I / J / K place quarters; ⌃⌥Return maximizes; ⌃⌥C centers without resizing
- [ ] Chained snaps (half → quarter → maximize) then ⌃⌥⌫ return the window to its original frame
- [ ] ⌃⌥⌫ on a never-snapped window does nothing
- [ ] With a second display: hotkeys act on the focused window's own display

## Stubborn windows

- [ ] A window with a large minimum size (e.g. System Settings) snapped into a quarter smaller than its minimum: lands at the zone origin at its closest allowed size — never half-moved, never bounced back
- [ ] Terminal (grid-resizing app): snaps land within a cell of the target and never revert
- [ ] Repeated snaps to the same zone are idempotent — the window never bounces

## Non-window drags (must never show a preview)

- [ ] Text selection drag inside a document, reaching a screen edge
- [ ] Scrollbar drag
- [ ] Window edge/corner resize drag
- [ ] Desktop rubber-band selection reaching an edge

## Permission gate

- [ ] With Accessibility revoked: any snap hotkey shows guidance with a working "Open System Settings" deep link — no silent failure
- [ ] After granting Accessibility (no relaunch): open the status menu once, then drag snapping and hotkeys work
