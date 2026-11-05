import CoreText
import Foundation
import UIKit

/// Registers bundled fonts in code, so no `UIAppFonts` / `.xcodeproj` change is needed.
/// Registration runs once, the first time a custom-font token is used.
enum DSFontRegistrar {
    static let architectsDaughter = "ArchitectsDaughter-Regular"

    /// `true` when the font is available. On failure, callers fall back to SF Pro.
    static var isArchitectsDaughterAvailable: Bool { architectsDaughterRegistered }

    private static let architectsDaughterRegistered: Bool = register(architectsDaughter, ext: "ttf")

    private static func register(_ name: String, ext: String) -> Bool {
        if UIFont(name: name, size: 12) != nil { return true }
        guard let url = Bundle.main.url(forResource: name, withExtension: ext) else { return false }
        // Errors (e.g. already registered) are not fatal; availability is checked below.
        CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        return UIFont(name: name, size: 12) != nil
    }
}
