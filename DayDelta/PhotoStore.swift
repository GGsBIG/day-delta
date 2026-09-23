import UIKit

/// Local photo storage in the app's Documents/photos directory. Events keep only
/// the filename. ponytail: plain files, no asset library or database.
enum PhotoStore {
    static let dir = FileManager.default
        .urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("photos", isDirectory: true)

    static func url(_ name: String) -> URL { dir.appendingPathComponent(name) }

    /// Save JPEG bytes (already compressed by the picker); returns the filename.
    static func save(_ data: Data) -> String? {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let name = UUID().uuidString + ".jpg"
        do {
            try data.write(to: url(name))
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> UIImage? {
        UIImage(contentsOfFile: url(name).path)
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: url(name))
    }
}
