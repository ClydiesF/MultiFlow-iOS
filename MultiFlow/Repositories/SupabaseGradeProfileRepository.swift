import Foundation
import Supabase

final class SupabaseGradeProfileRepository: GradeProfileRepositoryProtocol {
    private let client: SupabaseClient
    private var profilesChannel: RealtimeChannelV2?
    private var defaultsChannel: RealtimeChannelV2?
    private var listenTasks: [Task<Void, Never>] = []

    init(client: SupabaseClient) {
        self.client = client
    }

    convenience init() {
        self.init(client: SupabaseManager.shared.client)
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
        do {
            let inserted: GradeProfileRow = try await client
                .from("profiles")
                .insert(row)
                .select()
                .single()
                .execute()
                .value
            return inserted.id ?? ""
        } catch {
            guard shouldRetryLegacyProfileWrite(error) else { throw error }
            let legacyRow = LegacyGradeProfileRow(model: profile, userId: userId)
            let inserted: LegacyGradeProfileRow = try await client
                .from("profiles")
                .insert(legacyRow)
                .select()
                .single()
                .execute()
                .value
            return inserted.id ?? ""
        }
    }

    func updateProfile(_ profile: GradeProfile, userId: String) async throws {
        guard let id = profile.id else { return }
        let row = GradeProfileRow(model: profile, userId: userId)
        do {
            _ = try await client
                .from("profiles")
                .update(row)
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
        } catch {
            guard shouldRetryLegacyProfileWrite(error) else { throw error }
            let legacyRow = LegacyGradeProfileRow(model: profile, userId: userId)
            _ = try await client
                .from("profiles")
                .update(legacyRow)
                .eq("id", value: id)
                .eq("user_id", value: userId)
                .execute()
        }
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

private func shouldRetryLegacyProfileWrite(_ error: Error) -> Bool {
    let message = error.localizedDescription.lowercased()
    return message.contains("schema cache")
        || message.contains("could not find")
        || message.contains("enabled_cap_rate")
        || message.contains("enabled_cash_on_cash")
        || message.contains("enabled_dcr")
        || message.contains("enabled_cash_flow")
        || message.contains("enabled_equity_gain")
        || message.contains("enabled_noi")
        || message.contains("weight_noi")
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
    let weightNoi: Double
    let enabledCashOnCash: Bool
    let enabledDcr: Bool
    let enabledCapRate: Bool
    let enabledCashFlow: Bool
    let enabledEquityGain: Bool
    let enabledNoi: Bool
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
        case weightNoi = "weight_noi"
        case enabledCashOnCash = "enabled_cash_on_cash"
        case enabledDcr = "enabled_dcr"
        case enabledCapRate = "enabled_cap_rate"
        case enabledCashFlow = "enabled_cash_flow"
        case enabledEquityGain = "enabled_equity_gain"
        case enabledNoi = "enabled_noi"
        case colorHex = "color_hex"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        userId = try container.decode(String.self, forKey: .userId)
        name = try container.decode(String.self, forKey: .name)
        weightCashOnCash = try container.decode(Double.self, forKey: .weightCashOnCash)
        weightDcr = try container.decode(Double.self, forKey: .weightDcr)
        weightCapRate = try container.decode(Double.self, forKey: .weightCapRate)
        weightCashFlow = try container.decode(Double.self, forKey: .weightCashFlow)
        weightEquityGain = try container.decode(Double.self, forKey: .weightEquityGain)
        weightNoi = try container.decodeIfPresent(Double.self, forKey: .weightNoi) ?? 10
        enabledCashOnCash = try container.decodeIfPresent(Bool.self, forKey: .enabledCashOnCash) ?? true
        enabledDcr = try container.decodeIfPresent(Bool.self, forKey: .enabledDcr) ?? true
        enabledCapRate = try container.decodeIfPresent(Bool.self, forKey: .enabledCapRate) ?? true
        enabledCashFlow = try container.decodeIfPresent(Bool.self, forKey: .enabledCashFlow) ?? true
        enabledEquityGain = try container.decodeIfPresent(Bool.self, forKey: .enabledEquityGain) ?? true
        enabledNoi = try container.decodeIfPresent(Bool.self, forKey: .enabledNoi) ?? true
        colorHex = try container.decode(String.self, forKey: .colorHex)
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
        self.weightNoi = model.weightNoi
        self.enabledCashOnCash = model.enabledCashOnCash
        self.enabledDcr = model.enabledDcr
        self.enabledCapRate = model.enabledCapRate
        self.enabledCashFlow = model.enabledCashFlow
        self.enabledEquityGain = model.enabledEquityGain
        self.enabledNoi = model.enabledNoi
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
            weightNoi: weightNoi,
            enabledCashOnCash: enabledCashOnCash,
            enabledDcr: enabledDcr,
            enabledCapRate: enabledCapRate,
            enabledCashFlow: enabledCashFlow,
            enabledEquityGain: enabledEquityGain,
            enabledNoi: enabledNoi,
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

private struct LegacyGradeProfileRow: Codable {
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
}
