import Foundation
import MapKit
internal import Combine

@MainActor
final class LocationSearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var query: String = "" {
        didSet {
            completer.queryFragment = query
        }
    }
    @Published var results: [MKLocalSearchCompletion] = []

    private lazy var completer: MKLocalSearchCompleter = {
        let completer = MKLocalSearchCompleter()
        completer.resultTypes = [.address]
        return completer
    }()

    override init() {
        super.init()
        completer.delegate = self
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }

    func select(_ completion: MKLocalSearchCompletion) async throws -> MKMapItem? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)
        let response = try await search.start()
        return response.mapItems.first
    }
}
