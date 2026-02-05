import Foundation
import MapKit
import UIKit

enum MapSnapshotService {
    static func snapshotURL(for coordinate: CLLocationCoordinate2D, title: String) async throws -> URL {
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        options.size = CGSize(width: 800, height: 600)
        options.scale = UIScreen.main.scale

        let snapshotter = MKMapSnapshotter(options: options)
        let snapshot = try await snapshotter.start()
        let image = snapshot.image

        let filename = "property-map-\(UUID().uuidString).png"
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let url = (documents ?? FileManager.default.temporaryDirectory).appendingPathComponent(filename)
        guard let data = image.pngData() else { throw NSError(domain: "Snapshot", code: 1) }
        try data.write(to: url)
        return url
    }
}
