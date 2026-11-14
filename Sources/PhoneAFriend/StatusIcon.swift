import AppKit

enum StatusIcon {
    // Menu bar icons are normally template images that macOS tints to match the bar; the
    // pending state opts out of that so the orange actually shows.
    static func image(pending: Bool) -> NSImage {
        let symbol = NSImage(systemSymbolName: "phone.fill", accessibilityDescription: "Phone a Friend") ?? NSImage()
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
