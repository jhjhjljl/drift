#if DEBUG
import Foundation

/// Temporary open-path timing (`[DEBUG-open]`). Grep and remove when no longer needed.
enum OpenDiagnostics {
    private(set) static var openStart: CFAbsoluteTime?
    private static var loggedFirstScreen = false

    static func beginOpen() {
        openStart = CFAbsoluteTimeGetCurrent()
        loggedFirstScreen = false
    }

    static func elapsed(since start: CFAbsoluteTime) -> Int {
        Int((CFAbsoluteTimeGetCurrent() - start) * 1000)
    }

    static func log(_ phase: String, ms: Int, extra: String? = nil) {
        if let extra {
            print("[DEBUG-open] \(phase): \(ms)ms (\(extra))")
        } else {
            print("[DEBUG-open] \(phase): \(ms)ms")
        }
    }

    static func logFirstScreenReady(extra: String? = nil) {
        guard !loggedFirstScreen, let openStart else { return }
        loggedFirstScreen = true
        log("first screen ready", ms: elapsed(since: openStart), extra: extra)
    }
}
#endif
