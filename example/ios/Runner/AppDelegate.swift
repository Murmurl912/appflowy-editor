import UIKit
import Flutter

@main
@objc class AppDelegate: FlutterAppDelegate {
    private var sharedFilePath: String?

    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        GeneratedPluginRegistrant.register(with: self)

        let controller = window?.rootViewController as! FlutterViewController
        let channel = FlutterMethodChannel(
            name: "app.channel.shared.data",
            binaryMessenger: controller.binaryMessenger
        )

        channel.setMethodCallHandler { [weak self] (call, result) in
            if call.method == "getSharedFile" {
                result(self?.sharedFilePath)
                self?.sharedFilePath = nil
            } else {
                result(FlutterMethodNotImplemented)
            }
        }

        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    override func application(
        _ app: UIApplication,
        open url: URL,
        options: [UIApplication.OpenURLOptionsKey: Any] = [:]
    ) -> Bool {
        sharedFilePath = copyToTemp(url: url)
        return true
    }

    private func copyToTemp(url: URL) -> String? {
        let tempDir = NSTemporaryDirectory()
        let tempFile = tempDir + "shared_\(Int(Date().timeIntervalSince1970 * 1000)).md"
        let tempURL = URL(fileURLWithPath: tempFile)

        do {
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                try FileManager.default.copyItem(at: url, to: tempURL)
            } else {
                try FileManager.default.copyItem(at: url, to: tempURL)
            }
            return tempFile
        } catch {
            return nil
        }
    }
}
