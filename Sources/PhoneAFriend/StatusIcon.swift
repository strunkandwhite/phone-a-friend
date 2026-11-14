import AppKit
import SwiftUI

struct StatusIcon: View {
    let pending: Bool

    var body: some View {
        Image(nsImage: Self.image(pending: pending))
    }

    // Menu bar icons are normally template images that macOS tints to match the bar; the
    // pending state opts out of that so the orange actually shows.
    static func image(pending: Bool) -> NSImage {
        let symbol = NSImage(systemSymbolName: "person.wave.2.fill", accessibilityDescription: "Phone a Friend")!
        guard pending else {
            symbol.isTemplate = true
            return symbol
        }
        let orange = NSImage.SymbolConfiguration(paletteColors: [.systemOrange])
        let colored = symbol.withSymbolConfiguration(orange) ?? symbol
        colored.isTemplate = false
        return colored
    }
}
