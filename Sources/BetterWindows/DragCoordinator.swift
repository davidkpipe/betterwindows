import AppKit
import ApplicationServices
import BetterWindowsCore

/// Glues drag events, zone hit-testing, the overlay preview, the restore
/// ledger, and WindowControl together. The structural fix for the 1Piece
/// revert-on-release bug lives here: the dragged window is never resized
/// during the drag, and releasing inside a previewed zone commits the frame
/// with a single write-verify-retry pass — exactly the frame the preview
/// showed. The one deliberate exception is drag-away un-snap, which writes
/// once at tear-off so a snapped window pops back to its pre-snap size.
final class DragCoordinator {
    /// Window movement must match the cursor within this tolerance to count
    /// as a title-bar move-drag (the window lags the cursor between events).
    private static let moveMatchTolerance: CGFloat = 20
    /// If the cursor travels this far and the window still has not followed,
    /// the drag is something else (text selection, resizing) — give up.
    private static let qualificationDeadline: CGFloat = 60

    private let settings: AppSettings
    private let snapTracker: SnapTracker
    private var session = DragSession()
    private let hitTester = SnapHitTester()
    private let overlay = OverlayController()
    private var monitor: DragMonitor?

    // State captured when a press first becomes a drag.
    private var draggedWindow: AXUIElement?
    private var initialWindowFrame: CGRect?
    private var captureCursor: CGPoint?
    private var qualified = false
    private var activeZone: SnapZone?
    private var previewTarget: CGRect?

    init(settings: AppSettings, snapTracker: SnapTracker) {
        self.settings = settings
        self.snapTracker = snapTracker
    }

    /// Creates the event tap if possible (requires Accessibility). Safe to
    /// call repeatedly — it no-ops once the tap is running.
    func startIfPossible() {
        guard monitor == nil, WindowControl.isTrusted() else { return }
        let monitor = DragMonitor { [weak self] event in
            self?.handle(event)
        }
        if monitor.start() {
            self.monitor = monitor
        }
    }

    /// Display layout changed or the machine woke: any in-flight preview
    /// targets stale geometry, and macOS may have silently disabled the
    /// tap. Cancel the former, re-assert the latter.
    func handleSystemStateChange() {
        if session.phase != .idle {
            session.cancel()
            clearDragState()
        }
        monitor?.reassert()
        startIfPossible()
    }

    private func handle(_ event: DragMonitor.Event) {
        guard settings.isEnabled, settings.isDragSnappingEnabled else {
            if session.phase != .idle {
                session.cancel()
                clearDragState()
            }
            return
        }
        switch event {
        case .down(let point):
            session.begin(at: point)
        case .moved(let point):
            updateSession(at: point)
        case .up:
            commitIfReleasedInZone()
            session.end()
            clearDragState()
        case .escape:
            guard session.phase == .pressed || session.phase == .dragging else { return }
            session.cancel()
            clearDragState()
        }
    }

    private func updateSession(at point: CGPoint) {
        guard session.move(to: point) == .dragging else { return }

        // First event past the threshold: find the window under the cursor
        // and baseline its frame. Doing this lazily keeps plain clicks free
        // of Accessibility lookups.
        if draggedWindow == nil {
            guard let (window, frame) = WindowControl.window(at: point) else {
                session.cancel()
                return
            }
            draggedWindow = window
            initialWindowFrame = frame
            captureCursor = point
            qualified = false
            return
        }

        guard let window = draggedWindow,
              let initialFrame = initialWindowFrame,
              let baseline = captureCursor
        else { return }

        if !qualified {
            switch qualification(of: window, initialFrame: initialFrame, cursor: point, baseline: baseline) {
            case .confirmed:
                qualified = true
                // Drag-away un-snap: a snapped window pops back to its
                // pre-snap size under the cursor and the drag continues
                // from the restored frame.
                if let torn = tearOff(window: window, cursor: point, snappedFrame: initialFrame, baseline: baseline) {
                    initialWindowFrame = torn
                    return
                }
            case .undecided:
                return
            case .rejected:
                session.cancel()
                clearDragState()
                return
            }
        }

        guard let display = Displays.under(point) else { return }
        let zone = hitTester.zone(at: point, in: display.frame, current: activeZone)
        guard zone != activeZone else { return }
        activeZone = zone
        if let zone {
            let target = SnapEngine.targetFrame(
                for: zone,
                visibleFrame: display.visibleFrame,
                windowFrame: initialFrame
            )
            previewTarget = target
            overlay.show(cgFrame: target)
        } else {
            previewTarget = nil
            overlay.hide()
        }
    }

    /// The single frame write of a completed drag: on release, inside a
    /// previewed zone, to exactly the previewed frame. Cancelled drags and
    /// releases outside a zone write nothing.
    private func commitIfReleasedInZone() {
        guard session.phase == .dragging, qualified,
              activeZone != nil,
              let target = previewTarget,
              let window = draggedWindow,
              let preSnapFrame = initialWindowFrame,
              let pid = WindowControl.pid(of: window)
        else { return }
        let app = AXUIElementCreateApplication(pid)
        snapTracker.noteSnap(of: window, pid: pid, preSnapFrame: preSnapFrame)
        WindowControl.setFrame(target, window: window, app: app)
    }

    /// Consumes the window's restore-ledger entry when a snapped window is
    /// dragged, writing its pre-snap size back under the cursor. Returns the
    /// torn-off frame, or nil when the window was not snapped.
    private func tearOff(
        window: AXUIElement,
        cursor: CGPoint,
        snappedFrame: CGRect,
        baseline: CGPoint
    ) -> CGRect? {
        guard let original = snapTracker.consumeRestoreFrame(of: window),
              let pid = WindowControl.pid(of: window)
        else { return nil }
        let torn = SnapEngine.tearOffFrame(
            originalSize: original.size,
            cursor: cursor,
            grabPoint: baseline,
            snappedFrame: snappedFrame
        )
        let app = AXUIElementCreateApplication(pid)
        WindowControl.setFrame(torn, window: window, app: app)
        return torn
    }

    private enum Qualification {
        case confirmed
        case undecided
        case rejected
    }

    /// A title-bar move-drag is recognized by behavior, not by guessing at
    /// title-bar geometry: the window's origin follows the cursor while its
    /// size stays fixed. Text selection, scrollbar drags, and edge resizes
    /// each fail one of those conditions.
    private func qualification(
        of window: AXUIElement,
        initialFrame: CGRect,
        cursor: CGPoint,
        baseline: CGPoint
    ) -> Qualification {
        guard let current = WindowControl.frame(of: window) else { return .rejected }
        let cursorDelta = CGPoint(x: cursor.x - baseline.x, y: cursor.y - baseline.y)
        let windowDelta = CGPoint(
            x: current.minX - initialFrame.minX,
            y: current.minY - initialFrame.minY
        )
        let sizeUnchanged = abs(current.width - initialFrame.width) <= 1
            && abs(current.height - initialFrame.height) <= 1
        let followsCursor = abs(windowDelta.x - cursorDelta.x) <= Self.moveMatchTolerance
            && abs(windowDelta.y - cursorDelta.y) <= Self.moveMatchTolerance
        let windowMoved = abs(windowDelta.x) > 0.5 || abs(windowDelta.y) > 0.5

        if sizeUnchanged && followsCursor && windowMoved {
            return .confirmed
        }
        if !sizeUnchanged || hypot(cursorDelta.x, cursorDelta.y) > Self.qualificationDeadline {
            return .rejected
        }
        return .undecided
    }

    private func clearDragState() {
        draggedWindow = nil
        initialWindowFrame = nil
        captureCursor = nil
        qualified = false
        activeZone = nil
        previewTarget = nil
        overlay.hide()
    }
}
