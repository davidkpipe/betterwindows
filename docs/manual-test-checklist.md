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

## Option-Tab switcher

- [ ] Quick ⌥Tab (press and release together) flips to the previous window; a second quick ⌥Tab flips back
- [ ] Hold ⌥, press Tab repeatedly: selection advances and wraps; ⇧Tab goes backward and wraps
- [ ] Releasing ⌥ activates the highlighted window; Esc while holding ⌥ dismisses the panel and leaves focus unchanged
- [ ] Two windows of the same app appear as separate entries; switching between them via the panel works
- [ ] A minimized window appears (dimmed icon); selecting it and releasing ⌥ deminimizes and focuses it
- [ ] With the switcher enabled, the frontmost app never receives Option-Tab (check in a text editor where ⌥Tab would insert a character); ⌘-Tab still opens the system app switcher
- [ ] Toggle **Option-Tab Switcher** off in the status menu: ⌥Tab reaches the frontmost app natively; re-enable restores interception without a relaunch (same for the Settings checkbox)
- [ ] With a second display: the panel appears on the display of the focused window
- [ ] Windows on another Space do not appear; windows opened after the panel is up appear on the next invocation

## Switcher grid navigation

- [ ] With enough windows to wrap (or a narrow display): entries lay out as a grid, MRU order reading left-to-right, top-to-bottom
- [ ] → steps through entries in the same order as Tab and wraps from the last entry to the first; ← mirrors Shift-Tab
- [ ] ↓ moves down the column and wraps to the top; ↑ mirrors it; in a column the ragged last row lacks, ↓/↑ skip past the gap
- [ ] Hovering an entry moves the highlight — the same highlight the keys move, never a second one
- [ ] Opening the panel under a stationary cursor keeps the initial selection (the previous window) until the mouse actually moves
- [ ] Clicking an entry activates that window immediately (deminimizing if needed); still holding Option afterwards does nothing until a new Option-Tab
- [ ] Arrow keys while the panel is up never reach the frontmost app; with the panel closed, ⌃⌥-arrow snap hotkeys still work

## Switcher thumbnails (Screen Recording)

- [ ] With Screen Recording granted: entries show window-content thumbnails with an app-icon badge; type in a window, reopen the switcher — the thumbnail reflects the new contents (not the prior invocation's)
- [ ] The panel appears instantly; on the first invocation icons stand in and thumbnails fill in; on later invocations the previous captures stand in
- [ ] A minimized window shows its last-seen contents (dimmed) if it was captured before minimizing, else its app icon
- [ ] With Screen Recording denied: icons + titles rendering with the "Window previews need Screen Recording" footnote — no blank tiles, no crash
- [ ] Grant Screen Recording (relaunch if macOS requires it): thumbnails appear on the next invocation without any setting change

## Settings window

- [ ] Re-record a shortcut: it takes effect immediately (no relaunch) and survives relaunch
- [ ] Recording a combo already used by another action beeps and shows "Used by …" — the old assignment is untouched
- [ ] The drag-snap toggle disables edge previews live; re-enabling restores them without a relaunch
- [ ] (App bundle only) The launch-at-login toggle survives logout/login and reflects the real registration state when the window is reopened

## Onboarding & permission gate

- [ ] First launch with Accessibility missing: the welcome window opens automatically
- [ ] Grant Accessibility while it is open: the indicator flips to "Granted" within ~1s without a relaunch, and drag snapping starts working immediately
- [ ] The Screen Recording indicator likewise flips live when granted (nothing else changes today — it powers the future switcher thumbnails)
- [ ] Each button lands on the right System Settings pane: Accessibility, Screen Recording, Desktop & Dock
- [ ] macOS 15+: the tiling row shows On/Off matching "Drag windows to screen edges to tile"; toggling the setting updates the row while the window is open
- [ ] Close the window once: it no longer auto-opens on later launches, and the status menu's **Setup Guide…** reopens it
- [ ] With Accessibility revoked: any snap hotkey opens the welcome window — no silent failure
- [ ] After granting Accessibility with the welcome window closed: open the status menu once, then drag snapping and hotkeys work
