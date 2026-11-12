import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  let documents = PaperDocumentBridge()

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Fallback for application-delegate URL delivery. Scene-enabled launches use
  // SceneDelegate; iOS does not deliver the same event through both callbacks.
  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if url.isFileURL {
      documents.accept(url)
      return true
    }
    return super.application(app, open: url, options: options)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    documents.connect(engineBridge.applicationRegistrar.messenger())
  }
}

/// Copies externally supplied PDFs into an app-owned, short-lived staging area.
/// All bridge state is main-thread confined; file-provider work runs serially off UI.
final class PaperDocumentBridge {
  private var channel: FlutterMethodChannel?
  private var ready = false
  private var queued: [String] = []
  private var staged: [String: URL] = [:]
  private var outstanding = 0
  private var errorPending = false
  private var lastErrorTime = -Double.infinity
  private let io = DispatchQueue(label: "technology.cave.paper.document-import")
  private let root = FileManager.default.temporaryDirectory
    .appendingPathComponent("CavePaperOpenIn", isDirectory: true)
  private let limit = 200 * 1024 * 1024
  private let diskFloor: Int64 = 2 * 1024 * 1024 * 1024

  init() {
    // Only this adapter owns this staging directory. A previous process may have
    // exited before Flutter acknowledged release; never retain those PDF copies.
    io.async { [root] in try? FileManager.default.removeItem(at: root) }
  }

  func connect(_ messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "technology.cave.paper/documents", binaryMessenger: messenger)
    self.channel = channel
    channel.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { result(nil); return }
      switch call.method {
      case "ready":
        self.ready = true
        let paths = self.queued
        self.queued.removeAll()
        result(paths)
      case "release":
        if let path = call.arguments as? String, path.isEmpty {
          self.errorPending = false
        }
        if let path = call.arguments as? String, let directory = self.staged.removeValue(forKey: path) {
          self.outstanding -= 1
          self.io.async { try? FileManager.default.removeItem(at: directory) }
        }
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  func accept(_ url: URL) {
    // No remote URLs, directory imports or unbounded batches.
    guard url.isFileURL else { return }
    guard url.pathExtension.lowercased() == "pdf", outstanding < 8 else {
      reportFailure()
      return
    }
    outstanding += 1
    io.async { [self] in
      do {
        let copy = try stage(url)
        DispatchQueue.main.async { [self] in
          staged[copy.path] = copy.deletingLastPathComponent()
          if ready, let channel = channel {
            channel.invokeMethod("open", arguments: copy.path)
          } else {
            queued.append(copy.path)
          }
        }
      } catch {
        // Never log document paths or contents. Failed copies are removed by stage.
        NSLog("Cave Paper could not import an external PDF.")
        DispatchQueue.main.async { [self] in
          outstanding -= 1
          reportFailure()
        }
      }
    }
  }

  private func reportFailure() {
    // The existing Dart adapter rejects an empty path and displays localized
    // importError. Keep at most one unacknowledged failure, with a short throttle
    // so a large rejected batch cannot flood the Flutter queue/snackbar stack.
    let now = ProcessInfo.processInfo.systemUptime
    guard !errorPending, now - lastErrorTime >= 2 else { return }
    errorPending = true
    lastErrorTime = now
    if ready, let channel = channel {
      channel.invokeMethod("open", arguments: "")
    } else {
      queued.append("")
    }
  }

  private enum ImportError: Error { case invalid, tooLarge, lowSpace }

  private func stage(_ source: URL) throws -> URL {
    let manager = FileManager.default
    try manager.createDirectory(at: root, withIntermediateDirectories: true)
    let capacity = try root.resourceValues(forKeys: [.volumeAvailableCapacityKey])
    guard let free = capacity.volumeAvailableCapacity, Int64(free) >= diskFloor + Int64(limit) else {
      throw ImportError.lowSpace
    }
    let directory = root.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try manager.createDirectory(at: directory, withIntermediateDirectories: false)
    let target = directory.appendingPathComponent(source.lastPathComponent)
    var completed = false
    defer { if !completed { try? manager.removeItem(at: directory) } }
    let scoped = source.startAccessingSecurityScopedResource()
    defer { if scoped { source.stopAccessingSecurityScopedResource() } }
    var coordinationError: NSError?
    var copyError: Error?
    NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { coordinated in
      do {
        let values = try coordinated.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey, .fileSizeKey])
        guard values.isRegularFile == true, values.isSymbolicLink != true else { throw ImportError.invalid }
        guard let size = values.fileSize, size > 0, size <= limit else { throw ImportError.tooLarge }
        let input = try FileHandle(forReadingFrom: coordinated)
        defer { try? input.close() }
        guard manager.createFile(atPath: target.path, contents: nil) else { throw ImportError.invalid }
        let output = try FileHandle(forWritingTo: target)
        defer { try? output.close() }
        var total = 0
        var prefix = Data()
        while let data = try input.read(upToCount: 64 * 1024), !data.isEmpty {
          total += data.count
          guard total <= limit else { throw ImportError.tooLarge }
          if prefix.count < 1024 { prefix.append(data.prefix(1024 - prefix.count)) }
          try output.write(contentsOf: data)
        }
        guard prefix.range(of: Data("%PDF-".utf8)) != nil else { throw ImportError.invalid }
        try output.synchronize()
      } catch { copyError = error }
    }
    if let error = coordinationError { throw error }
    if let error = copyError { throw error }
    guard manager.fileExists(atPath: target.path) else { throw ImportError.invalid }
    completed = true
    return target
  }
}
