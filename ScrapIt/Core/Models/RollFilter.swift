import Foundation

enum RollFilter: String, Codable, CaseIterable, Identifiable {
    case cinematicBW400 = "cinematic_bw_400"
    case colorPrint200 = "color_print_200"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cinematicBW400:
            return "Cinematic 400 Pro 35 Black & White"
        case .colorPrint200:
            return "200 Color Print"
        }
    }

    var shortLabel: String {
        switch self {
        case .cinematicBW400:
            return "PRO 35 B&W 400"
        case .colorPrint200:
            return "COLOR PRINT 200"
        }
    }
}
