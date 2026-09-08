import AppKit

/// Clamp only the visible capsule. Prefer the own anchor; shift horizontally only when the predicted native region overlaps.
struct HUDPlacement {
    func frame(
        anchoredAt anchor: CGRect,
        capsuleSize: CGSize,
        on screen: CGRect,
        screenInset: CGFloat = 6,
        nativeAnchor: HUDSystemMenuAnchor? = nil,
        gap: CGFloat = 12
    ) -> CGRect? {
        guard screen.width >= capsuleSize.width + 2 * screenInset,
              screen.height >= capsuleSize.height + 2 * screenInset else { return nil }
        let capsule = CGRect(
            x: (anchor.width - capsuleSize.width) / 2,
            y: (anchor.height - capsuleSize.height) / 2,
            width: capsuleSize.width, height: capsuleSize.height
        )
        var frame = anchor
        // Transparent hosting margins may extend off screen. Constraining them
        // instead of the visible capsule shifts the HUD away from its anchor.
        frame.origin.x = min(max(frame.minX, screen.minX + screenInset - capsule.minX), screen.maxX - screenInset - capsule.maxX)
        frame.origin.y = min(max(frame.minY, screen.minY + screenInset - capsule.minY), screen.maxY - screenInset - capsule.maxY)
        if let native = nativeAnchor?.capsuleFrame(on: screen, size: capsuleSize, inset: screenInset) {
            let ownMinX = frame.minX + capsule.minX
            let ownMaxX = ownMinX + capsule.width
            if ownMinX < native.maxX + gap && ownMaxX > native.minX - gap {
                let right = native.maxX + gap
                let left = native.minX - gap - capsule.width
                if right + capsule.width <= screen.maxX - screenInset {
                    frame.origin.x = right - capsule.minX
                } else if left >= screen.minX + screenInset {
                    frame.origin.x = left - capsule.minX
                } else {
                    // No same-row space: skip this HUD instead of overlapping or lowering it.
                    return nil
                }
            }
        }
        return frame
    }
}
