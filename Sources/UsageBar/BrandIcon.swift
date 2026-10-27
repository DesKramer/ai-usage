import AppKit
import SwiftUI

struct BrandIcon: View {
    enum Brand: String {
        case claude = "Claude"
        case codex = "Codex"
    }

    let brand: Brand

    static func image(for brand: Brand, size: NSSize? = nil) -> NSImage? {
        guard let url = Bundle.main.url(forResource: brand.rawValue, withExtension: "svg"),
              let image = NSImage(contentsOf: url)
        else { return nil }
        image.isTemplate = true
        if let size { image.size = size }
        return image
    }

    var body: some View {
        if let image = Self.image(for: brand) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .scaledToFit()
        } else {
            Color.clear
        }
    }
}
