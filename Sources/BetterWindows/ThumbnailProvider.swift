import AppKit
import ScreenCaptureKit
import BetterWindowsCore

/// Captures switcher thumbnails with ScreenCaptureKit. One-shot screenshots
/// per window, taken concurrently at invocation time; results land on the
/// main thread via the caller's callback as they complete, so the panel can
/// show placeholders instantly and fill in.
///
/// AX windows carry no CGWindowID, so entries are matched to SCWindows by
/// owning pid + on-screen frame (title as tiebreaker) — both APIs report
/// global top-left-origin coordinates.
final class ThumbnailProvider {
    /// Thumbnails need Screen Recording; without it the switcher stays in
    /// icons + titles mode.
    static func isAvailable() -> Bool {
        PermissionProbes.screenRecordingGranted()
    }

    private var cache = ThumbnailCache<WindowKey, NSImage>()

    /// The latest capture for a window, however old — placeholder use.
    /// Also the only thumbnail a minimized window can get: it is not on
    /// screen, so only its pre-minimize capture exists.
    func cachedImage(for key: WindowKey) -> NSImage? {
        cache.image(for: key)
    }

    func prune(keeping live: [WindowKey]) {
        cache.prune(keeping: live)
    }

    /// Starts a new generation and captures every non-minimized entry as of
    /// now. `onCapture` runs on the main thread once per completed capture.
    func refresh(entries: [SwitcherEntry], onCapture: @escaping (WindowKey, NSImage) -> Void) {
        cache.beginInvocation()

        let targets: [(key: WindowKey, pid: pid_t, frame: CGRect, title: String)] =
            entries.compactMap { entry in
                guard !entry.isMinimized,
                      let frame = WindowControl.frame(of: entry.window)
                else { return nil }
                return (entry.key, entry.pid, frame, entry.title)
            }
        guard !targets.isEmpty else { return }

        Task { [weak self] in
            guard let content = try? await SCShareableContent.excludingDesktopWindows(
                true,
                onScreenWindowsOnly: true
            ) else { return }
            guard let self else { return }

            await withTaskGroup(of: (WindowKey, CGImage)?.self) { group in
                for target in targets {
                    guard let scWindow = Self.match(
                        pid: target.pid,
                        frame: target.frame,
                        title: target.title,
                        in: content.windows
                    ) else { continue }
                    group.addTask {
                        guard let image = try? await SCScreenshotManager.captureImage(
                            contentFilter: SCContentFilter(desktopIndependentWindow: scWindow),
                            configuration: Self.configuration(for: scWindow.frame.size)
                        ) else { return nil }
                        return (target.key, image)
                    }
                }
                for await captured in group {
                    guard let (key, cgImage) = captured else { continue }
                    await self.deliver(key: key, cgImage: cgImage, onCapture: onCapture)
                }
            }
        }
    }

    /// Stores the capture and hands it to the panel — on the main thread,
    /// which owns the cache.
    @MainActor
    private func deliver(
        key: WindowKey,
        cgImage: CGImage,
        onCapture: (WindowKey, NSImage) -> Void
    ) {
        let image = NSImage(cgImage: cgImage, size: .zero)
        cache.store(image, for: key)
        onCapture(key, image)
    }

    // MARK: Matching and capture configuration

    private static func match(
        pid: pid_t,
        frame: CGRect,
        title: String,
        in windows: [SCWindow]
    ) -> SCWindow? {
        let sameApp = windows.filter { $0.owningApplication?.processID == pid }
        let sameFrame = sameApp.filter {
            abs($0.frame.minX - frame.minX) <= 2
                && abs($0.frame.minY - frame.minY) <= 2
                && abs($0.frame.width - frame.width) <= 2
                && abs($0.frame.height - frame.height) <= 2
        }
        if sameFrame.count > 1, let byTitle = sameFrame.first(where: { $0.title == title }) {
            return byTitle
        }
        return sameFrame.first
    }

    private static func configuration(for windowSize: CGSize) -> SCStreamConfiguration {
        // Twice the panel's thumbnail area, for Retina sharpness.
        let maxWidth: CGFloat = 432
        let maxHeight: CGFloat = 280
        let scale = min(
            maxWidth / max(windowSize.width, 1),
            maxHeight / max(windowSize.height, 1),
            2
        )
        let configuration = SCStreamConfiguration()
        configuration.width = max(1, Int(windowSize.width * scale))
        configuration.height = max(1, Int(windowSize.height * scale))
        configuration.showsCursor = false
        configuration.scalesToFit = true
        return configuration
    }
}
