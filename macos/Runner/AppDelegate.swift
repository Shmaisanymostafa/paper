import Cocoa
import FlutterMacOS

@main
class AppDelegate: FlutterAppDelegate {
  private var documentChannel: FlutterMethodChannel?
  private var ready = false
  private var pending: [String] = []
  private var scoped: [String: (URL, Int)] = [:]

  func connectDocuments(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "technology.cave.paper/documents", binaryMessenger: messenger)
    documentChannel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "ready":
        self.ready = true
        let files = self.pending
        self.pending.removeAll()
        result(files)
      case "release":
        if let path = call.arguments as? String, let entry = self.scoped[path] {
          if entry.1 <= 1 {
            entry.0.stopAccessingSecurityScopedResource()
            self.scoped.removeValue(forKey: path)
          } else {
            self.scoped[path] = (entry.0, entry.1 - 1)
          }
        }
        result(nil)
      default: result(FlutterMethodNotImplemented)
      }
    }
  }

  override func application(_ application: NSApplication, open urls: [URL]) {
    for url in urls where url.isFileURL && url.pathExtension.lowercased() == "pdf" {
      if let entry = scoped[url.path] {
        scoped[url.path] = (entry.0, entry.1 + 1)
      } else if url.startAccessingSecurityScopedResource() {
        scoped[url.path] = (url, 1)
      }
      if ready { documentChannel?.invokeMethod("open", arguments: url.path) }
      else { pending.append(url.path) }
    }
    application.activate(ignoringOtherApps: true)
  }

  override func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
  override func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
