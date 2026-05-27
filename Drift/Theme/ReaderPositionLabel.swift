import Foundation

/// 1-based screen position for the tap overlay (`42` or `42 / 1,204`).
enum ReaderPositionLabel {
    static func text(
        currentIndex: Int,
        totalScreens: Int,
        isComplete: Bool
    ) -> String? {
        guard totalScreens > 0,
              currentIndex >= 0,
              currentIndex < totalScreens else { return nil }

        let current = currentIndex + 1
        if isComplete {
            return "\(current) / \(totalScreens)"
        }
        return "\(current)"
    }
}
