import CallKit
import Foundation

/// The Call Directory extension: gives the iPhone the names of the saved
/// families, so an incoming call from one of them shows
/// "أم مينا جورج – فصل 5 بنات" even when the number is not in Contacts.
///
/// The app writes the numbers to a file in the shared App Group
/// (`CallerIdChannel.swift`); this reads it. iOS requires the numbers sorted
/// ascending and each number only once.
class CallDirectoryHandler: CXCallDirectoryProvider {
    static let appGroup = "group.com.sabtawya.sabtawya"
    static let fileName = "caller_id.json"

    override func beginRequest(with context: CXCallDirectoryExtensionContext) {
        context.delegate = self

        // The whole list is replaced each time, so removed numbers go away.
        if context.isIncremental {
            context.removeAllIdentificationEntries()
        }

        for (number, label) in loadEntries() {
            context.addIdentificationEntry(withNextSequentialPhoneNumber: number, label: label)
        }
        context.completeRequest()
    }

    /// `{ "201012345678": "أم مينا جورج – فصل 5 بنات", ... }` as sorted pairs.
    private func loadEntries() -> [(CXCallDirectoryPhoneNumber, String)] {
        guard
            let dir = FileManager.default
                .containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup),
            let data = try? Data(contentsOf: dir.appendingPathComponent(Self.fileName)),
            let raw = try? JSONSerialization.jsonObject(with: data) as? [String: String]
        else { return [] }

        var pairs: [(CXCallDirectoryPhoneNumber, String)] = []
        var seen = Set<CXCallDirectoryPhoneNumber>()
        for (digits, label) in raw {
            // Only full international numbers (country code first); a number
            // written without one cannot be matched by iOS.
            guard let n = CXCallDirectoryPhoneNumber(digits), !digits.hasPrefix("0"),
                  seen.insert(n).inserted else { continue }
            pairs.append((n, label))
        }
        return pairs.sorted { $0.0 < $1.0 }
    }
}

extension CallDirectoryHandler: CXCallDirectoryExtensionContextDelegate {
    func requestFailed(for extensionContext: CXCallDirectoryExtensionContext, withError error: Error) {
        // Nothing to recover: the previous list stays in place.
    }
}
