import Foundation

protocol GradeProfileRepositoryProtocol: AnyObject {
    func fetchProfiles(for userId: String) async throws -> [GradeProfile]
    func fetchDefaultProfileId(for userId: String) async throws -> String?
    func addProfile(_ profile: GradeProfile, userId: String) async throws -> String
    func updateProfile(_ profile: GradeProfile, userId: String) async throws
    func deleteProfile(id: String, userId: String) async throws
    func setDefaultProfileId(_ profileId: String?, userId: String) async throws
    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws
    func stopListening() async
}
