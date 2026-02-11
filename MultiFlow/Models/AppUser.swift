import Foundation

struct AppUser: Equatable, Sendable {
    let id: String
    let email: String?
    let isAnonymous: Bool
}
