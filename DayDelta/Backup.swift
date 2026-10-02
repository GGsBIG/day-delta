import SwiftUI
import UniformTypeIdentifiers

/// A JSON document wrapping the encoded `[Event]`, for `.fileExporter` /
/// `.fileImporter`.
struct EventsDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    static var writableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

/// The full backup payload. Replaces the old bare `[Event]` JSON; `handleImport`
/// still falls back to decoding a bare array so old backups keep working.
struct BackupData: Codable {
    var events: [Event]
    var txns: [Txn]
    var categories: [Category]
    var accounts: [Account] = []   // default so older backups (no accounts) decode
}
