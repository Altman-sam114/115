/// Presentation-only sizing. A layout change cannot authorize or send a task.
enum ClawWorkspaceLayout {
    static let minimumReviewColumnWidth: Double = 900

    static func usesReviewColumn(width: Double, accessibilitySize: Bool) -> Bool {
        width.isFinite && width >= minimumReviewColumnWidth && !accessibilitySize
    }

    static func leadingColumnWidth(for width: Double) -> Double {
        guard width.isFinite, width > 0 else { return 330 }
        return min(max(width * 0.36, 330), 440)
    }
}
