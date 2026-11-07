import Foundation

nonisolated struct SupabaseConfig: Sendable, Equatable {
    let url: URL
    let anonKey: String

    static func load(
        bundle: Bundle = .main,
        resourceName: String = "SupabaseSecrets"
    ) -> SupabaseConfig? {
        guard let plistURL = bundle.url(forResource: resourceName, withExtension: "plist"),
              let raw = NSDictionary(contentsOf: plistURL) as? [String: Any] else {
            return nil
        }
        return parse(raw)
    }

    static func parse(_ dictionary: [String: Any]) -> SupabaseConfig? {
        guard let rawURL = (dictionary["SUPABASE_URL"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let rawKey = (dictionary["SUPABASE_ANON_KEY"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !rawURL.isEmpty,
              !rawKey.isEmpty,
              !isPlaceholder(rawURL),
              !isPlaceholder(rawKey),
              let url = URL(string: rawURL),
              let scheme = url.scheme?.lowercased(),
              (scheme == "https" || scheme == "http"),
              let host = url.host,
              !host.isEmpty else {
            return nil
        }
        return SupabaseConfig(url: url, anonKey: rawKey)
    }

    private static func isPlaceholder(_ value: String) -> Bool {
        let upper = value.uppercased()
        return upper.contains("YOUR_PROJECT_REF")
            || upper.contains("YOUR_SUPABASE_ANON_KEY")
            || upper.contains("<")
            || upper.contains(">")
    }
}
