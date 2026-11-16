import CallKit
import Flutter
import Foundation

/// The iPhone half of "show caller name": the same `sabtawya/caller_id`
/// channel the Android app uses (see `lib/data/services/caller_id_service.dart`).
/// Writes the numbers to the shared App Group file the Call Directory
/// extension reads, then asks iOS to reload the extension.
enum CallerIdChannel {
    static let extensionId = "com.sabtawya.sabtawya.CallDirectory"

    static func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "sabtawya/caller_id", binaryMessenger: messenger)
        channel.setMethodCallHandler { call, result in
            switch call.method {
            case "setNumbers":
                let map = (call.arguments as? [String: String]) ?? [:]
                write(map)
                reload { result(nil) }
            case "clear":
                write([:])
                reload { result(nil) }
            case "isEnabled":
                CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
                    withIdentifier: extensionId
                ) { status, _ in
                    result(status == .enabled)
                }
            case "requestPermissions":
                // iOS has no prompt: the servant switches the extension on in
                // Settings > Phone > Call Blocking & Identification. Report
                // whether that is already done.
                CXCallDirectoryManager.sharedInstance.getEnabledStatusForExtension(
                    withIdentifier: extensionId
                ) { status, _ in
                    result(status == .enabled)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private static func write(_ map: [String: String]) {
        guard
            let dir = FileManager.default.containerURL(
                forSecurityApplicationGroupIdentifier: CallDirectoryHandler.appGroup),
            let data = try? JSONSerialization.data(withJSONObject: map)
        else { return }
        try? data.write(to: dir.appendingPathComponent(CallDirectoryHandler.fileName),
                        options: .atomic)
    }

    private static func reload(_ done: @escaping () -> Void) {
        CXCallDirectoryManager.sharedInstance.reloadExtension(
            withIdentifier: extensionId
        ) { _ in done() }
    }
}
