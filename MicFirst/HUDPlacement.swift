import AppKit

/// Clamp only the visible capsule. Keep the own anchor unless a system banner occupies
/// its row; then take the nearest free position in that same row.
struct HUDPlacement {
    func frame(
        anchoredAt anchor: CGRect,
        capsuleSize: CGSize,
        on screen: CGRect,
        screenInset: CGFloat = 6,
        avoiding obstacles: [CGRect] = [],
        keeping current: CGRect? = nil,
        gap: CGFloat = 12
    ) -> CGRect? {
        guard screen.width >= capsuleSize.width + 2 * screenInset,
              screen.height >= capsuleSize.height + 2 * screenInset else { return nil }
        let capsule = CGRect(
            x: (anchor.width - capsuleSize.width) / 2,
            y: (anchor.height - capsuleSize.height) / 2,
            width: capsuleSize.width, height: capsuleSize.height
        )
        // Transparent hosting margins may extend off screen. Constraining them
        // instead of the visible capsule shifts the HUD away from its anchor.
        let minX = screen.minX + screenInset - capsule.minX
        let maxX = screen.maxX - screenInset - capsule.maxX
        var frame = anchor
        frame.origin.x = min(max(frame.minX, minX), maxX)
        frame.origin.y = min(max(frame.minY, screen.minY + screenInset - capsule.minY), screen.maxY - screenInset - capsule.maxY)

        // Window origins that would put the capsule closer than `gap` to a banner in its row.
        let rowMinY = frame.minY + capsule.minY
        let blocked = obstacles
            .filter { $0.minY < rowMinY + capsule.height && $0.maxY > rowMinY }
            .map { ($0.minX - gap - capsule.maxX, $0.maxX + gap - capsule.minX) }
        func isFree(_ x: CGFloat) -> Bool {
            x >= minX && x <= maxX && !blocked.contains { x > $0.0 && x < $0.1 }
        }
        // A HUD that already moved aside stays there; it does not slide back when the banner leaves.
        if let current, current.minY == frame.minY, current.size == frame.size, isFree(current.minX) {
            return current
        }
        let candidates = [frame.minX] + blocked.flatMap { [$0.0, $0.1] }
        guard let x = candidates.filter(isFree).min(by: { abs($0 - frame.minX) < abs($1 - frame.minX) }) else {
            // No same-row space: skip this HUD instead of overlapping or lowering it.
            return nil
        }
        frame.origin.x = x
        return frame
    }
}
