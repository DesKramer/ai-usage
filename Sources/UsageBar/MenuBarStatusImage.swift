import AppKit

@MainActor
enum MenuBarStatusImage {
    static func make(claudeValue: String, codexValue: String) -> NSImage {
        let iconSize = NSSize(width: 14, height: 14)
        let height: CGFloat = 18
        let iconTextGap: CGFloat = 3
        let providerGap: CGFloat = 9
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 13, weight: .regular),
            .foregroundColor: NSColor.black,
        ]
        let claudeText = claudeValue as NSString
        let codexText = codexValue as NSString
        let claudeTextSize = claudeText.size(withAttributes: attributes)
        let codexTextSize = codexText.size(withAttributes: attributes)
        let width = ceil(
            iconSize.width + iconTextGap + claudeTextSize.width
                + providerGap
                + iconSize.width + iconTextGap + codexTextSize.width)

        let claudeIcon = BrandIcon.image(for: .claude, size: iconSize)
        let codexIcon = BrandIcon.image(for: .codex, size: iconSize)
        let image = NSImage(size: NSSize(width: width, height: height), flipped: true) { _ in
            let iconY = (height - iconSize.height) / 2
            let claudeTextY = (height - claudeTextSize.height) / 2
            let codexTextY = (height - codexTextSize.height) / 2
            var x: CGFloat = 0

            claudeIcon?.draw(
                in: NSRect(origin: NSPoint(x: x, y: iconY), size: iconSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1)
            x += iconSize.width + iconTextGap
            claudeText.draw(at: NSPoint(x: x, y: claudeTextY), withAttributes: attributes)
            x += claudeTextSize.width + providerGap

            codexIcon?.draw(
                in: NSRect(origin: NSPoint(x: x, y: iconY), size: iconSize),
                from: .zero,
                operation: .sourceOver,
                fraction: 1)
            x += iconSize.width + iconTextGap
            codexText.draw(at: NSPoint(x: x, y: codexTextY), withAttributes: attributes)
            return true
        }
        image.isTemplate = true
        return image
    }
}
