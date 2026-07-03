import AppKit
import ApplicationServices
import BetterWindowsCore

/// Glues drag events to zone hit-testing and the overlay preview. This slice
/// deliberately stops short of writing window frames: the dragged window is
/// never touched, and releasing just dismisses the preview — the
/// single-write commit is the next slice.
final class DragCoordinator {
    /// Window movement must match the cursor within this tolerance to count
    /// as a title-bar move-drag (the window lags the cursor between events).
    private static let moveMatchTolerance: CGFloat = 20
    /// If the cursor travels this far and the window still has not followed,
    /// the drag is something else (text selection, resizing) — give up.
    private static let qualificationDeadline: CGFloat = 60

    private let settings: AppSettings
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

    init(settings: AppSettings) {
        self.settings = settings
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

    private func handle(_ event: DragMonitor.Event) {
        guard settings.isEnabled else {
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
            overlay.show(cgFrame: target)
        } else {
            overlay.hide()
        }
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
        overlay.hide()
    }
}
