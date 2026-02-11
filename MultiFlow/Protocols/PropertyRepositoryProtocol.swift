import Foundation

protocol PropertyRepositoryProtocol: AnyObject {
    func fetchProperties(for userId: String) async throws -> [Property]
    func addProperty(_ property: Property, userId: String) async throws
    func updateProperty(_ property: Property, userId: String) async throws
    func deleteProperty(id: String, userId: String) async throws
    func startListening(for userId: String, onChange: @escaping @Sendable () -> Void) async throws
    func stopListening() async
}
