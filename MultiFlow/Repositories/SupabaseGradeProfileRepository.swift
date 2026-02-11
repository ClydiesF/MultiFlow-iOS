import Foundation
import Supabase

final class SupabaseGradeProfileRepository: GradeProfileRepositoryProtocol {
    private let client: SupabaseClient
    private var profilesChannel: RealtimeChannelV2?
    private var defaultsChannel: RealtimeChannelV2?
    private var listenTasks: [Task<Void, Never>] = []

    init(client: SupabaseClient = SupabaseManager.shared.client) {
        self.client = client
    }

    func fetchProfiles(for userId: String) async throws -> [GradeProfile] {
        let rows: [GradeProfileRow] = try await client
            .from("profiles")
            .select()
            .eq("user_id", value: userId)
            .order("created_at", ascending: true)
            .execute()
            .value
        return rows.map { $0.toModel() }
    }

    func fetchDefaultProfileId(for userId: String) async throws -> String? {
        let rows: [ProfileDefaultRow] = try await client
            .from("profile_defaults")
            .select()
            .eq("user_id", value: userId)
            .limit(1)
            .execute()
            .value
        return rows.first?.defaultProfileId
    }

    func addProfile(_ profile: GradeProfile, userId: String) async throws -> String {
        let row = GradeProfileRow(model: profile, userId: userId)
        let inserted: GradeProfileRow = try await client
            .from("profiles")
            .insert(row)
            .select()
            .single()
            .execute()
            .value
        return inserted.id ?? ""
    }

    func updateProfile(_ profile: GradeProfile, userId: String) async throws {
        guard let id = profile.id else { return }
        let row = GradeProfileRow(model: profile, userId: userId)
        _ = try await client
            .from("profiles")
            .update(row)
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func deleteProfile(id: String, userId: String) async throws {
        _ = try await client
            .from("profiles")
            .delete()
            .eq("id", value: id)
            .eq("user_id", value: userId)
            .execute()
    }

    func setDefaultProfileId(_ profileId: String?, userId: String) async throws {
        let row = ProfileDefaultRow(userId: userId, defaultProfileId: profileId)
        _ = try await client
            .from("profile_defaults")
            .upsert(row)
            .execute()
    }

    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws {
        await stopListening()

        let profilesChannel = client.channel("public:profiles:\(userId)")
        let defaultsChannel = client.channel("public:profile_defaults:\(userId)")
        self.profilesChannel = profilesChannel
        self.defaultsChannel = defaultsChannel

        let profileTask = Task {
            let changes = profilesChannel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "profiles",
                filter: "user_id=eq.\(userId)"
            )
            for await _ in changes {
                onChange()
            }
        }

        let defaultsTask = Task {
            let changes = defaultsChannel.postgresChange(
                AnyAction.self,
                schema: "public",
                table: "profile_defaults",
                filter: "user_id=eq.\(userId)"
            )
            for await _ in changes {
                onChange()
            }
        }

        listenTasks = [profileTask, defaultsTask]

        try await profilesChannel.subscribe()
        try await defaultsChannel.subscribe()
    }

    func stopListening() async {
        listenTasks.forEach { $0.cancel() }
        listenTasks.removeAll()

        if let profilesChannel {
            await client.removeChannel(profilesChannel)
            self.profilesChannel = nil
        }

        if let defaultsChannel {
            await client.removeChannel(defaultsChannel)
            self.defaultsChannel = nil
        }
    }
}

private struct GradeProfileRow: Codable {
    let id: String?
    let userId: String
    let name: String
    let weightCashOnCash: Double
    let weightDcr: Double
    let weightCapRate: Double
    let weightCashFlow: Double
    let weightEquityGain: Double
    let colorHex: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case name
        case weightCashOnCash = "weight_cash_on_cash"
        case weightDcr = "weight_dcr"
        case weightCapRate = "weight_cap_rate"
        case weightCashFlow = "weight_cash_flow"
        case weightEquityGain = "weight_equity_gain"
        case colorHex = "color_hex"
    }

    init(model: GradeProfile, userId: String) {
        self.id = model.id
        self.userId = userId
        self.name = model.name
        self.weightCashOnCash = model.weightCashOnCash
        self.weightDcr = model.weightDcr
        self.weightCapRate = model.weightCapRate
        self.weightCashFlow = model.weightCashFlow
        self.weightEquityGain = model.weightEquityGain
        self.colorHex = model.colorHex
    }

    func toModel() -> GradeProfile {
        GradeProfile(
            id: id,
            userId: userId,
            name: name,
            weightCashOnCash: weightCashOnCash,
            weightDcr: weightDcr,
            weightCapRate: weightCapRate,
            weightCashFlow: weightCashFlow,
            weightEquityGain: weightEquityGain,
            colorHex: colorHex
        )
    }
}

private struct ProfileDefaultRow: Codable {
    let userId: String
    let defaultProfileId: String?

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case defaultProfileId = "default_profile_id"
    }
}
