import Foundation

struct BackendConfig {
    let supabaseURL: URL
    let supabaseAnonKey: String

    init(supabaseURL: URL, supabaseAnonKey: String) {
        self.supabaseURL = supabaseURL
        self.supabaseAnonKey = supabaseAnonKey
    }

    static func load() -> BackendConfig {
        let info = Bundle.main.infoDictionary ?? [:]

        let urlString = (
            info["SUPABASE_URL"] as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_URL"]
            ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        let anonKey = (
            info["SUPABASE_ANON_KEY"] as? String
            ?? ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"]
            ?? ""
        ).trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: urlString), !anonKey.isEmpty else {
            fatalError("Missing Supabase config. Set SUPABASE_URL and SUPABASE_ANON_KEY in build settings / Info.plist.")
        }

        return BackendConfig(supabaseURL: url, supabaseAnonKey: anonKey)
    }
}
