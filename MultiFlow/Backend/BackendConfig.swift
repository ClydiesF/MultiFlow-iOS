import Foundation

struct BackendConfig {
    private static let fallbackSupabaseURLString = "https://rmszsjyvjhtdmgvbliya.supabase.co"
    private static let fallbackSupabaseAnonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJtc3pzanl2amh0ZG1ndmJsaXlhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA1MTk2ODUsImV4cCI6MjA4NjA5NTY4NX0.5Nr1hDoeh1yS49MFr71Qt123dOsOKzbsig0q24IvZ24"

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

        if let url = URL(string: urlString), !anonKey.isEmpty {
            return BackendConfig(supabaseURL: url, supabaseAnonKey: anonKey)
        }

        let fallbackURL = URL(string: fallbackSupabaseURLString)!
        assertionFailure("Missing Supabase config. Falling back to embedded defaults.")
        return BackendConfig(supabaseURL: fallbackURL, supabaseAnonKey: fallbackSupabaseAnonKey)
    }
}
