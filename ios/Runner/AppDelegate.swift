import Flutter
import UIKit
import CryptoKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var modelChannel: FlutterMethodChannel?
  private let modelQueue = DispatchQueue(label: "ir.alo.bundled-models", qos: .userInitiated)

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    let launched = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    guard let controller = window?.rootViewController as? FlutterViewController else { return launched }
    modelChannel = FlutterMethodChannel(name: "ir.alo/bundled_models", binaryMessenger: controller.binaryMessenger)
    modelChannel?.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      if call.method == "memoryInfo" {
        let available = alo_available_process_memory()
        result(["available": NSNumber(value: available), "low": available < 1_600_000_000])
      } else if call.method == "ensureFiles" {
        guard let args = call.arguments as? [String: Any],
              let root = args["root"] as? String,
              let files = args["files"] as? [[String: Any]] else {
          result(FlutterError(code: "invalid_arguments", message: "درخواست آماده‌سازی مدل معتبر نیست.", details: nil)); return
        }
        self.modelQueue.async {
          do {
            try self.ensureFiles(rootPath: root, files: files)
            DispatchQueue.main.async { result(nil) }
          } catch {
            DispatchQueue.main.async {
              result(FlutterError(code: "model_install", message: "آماده‌سازی مدل کامل نشد. فضای آزاد آیفون را بررسی کنید.", details: nil))
            }
          }
        }
      } else { result(FlutterMethodNotImplemented) }
    }
    return launched
  }

  private enum ModelError: Error { case invalidPath, missingAsset, invalidSpec, checksum, diskSpace }

  private func safeRelative(_ value: String) -> Bool {
    return !value.isEmpty && !value.hasPrefix("/") && !value.contains("\\") &&
      !value.split(separator: "/", omittingEmptySubsequences: false).contains(where: { $0 == ".." || $0 == "." || $0.isEmpty })
  }

  private func assetURL(_ asset: String) throws -> URL {
    guard asset.hasPrefix("assets/"), safeRelative(asset) else { throw ModelError.invalidPath }
    let lookup = FlutterDartProject.lookupKey(forAsset: asset)
    var paths = [Bundle.main.bundleURL.appendingPathComponent(lookup),
                 Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework/flutter_assets/" + asset)]
    // Flutter bundles can percent-escape filenames with spaces. Never infer a different model.
    var allowed = CharacterSet.alphanumerics
    allowed.insert(charactersIn: "-_.~/!")
    if let encoded = asset.addingPercentEncoding(withAllowedCharacters: allowed) {
      paths.append(Bundle.main.bundleURL.appendingPathComponent(FlutterDartProject.lookupKey(forAsset: encoded)))
      paths.append(Bundle.main.bundleURL.appendingPathComponent("Frameworks/App.framework/flutter_assets/" + encoded))
    }
    guard let existing = paths.first(where: { FileManager.default.fileExists(atPath: $0.path) }) else { throw ModelError.missingAsset }
    return existing
  }

  private func excludeBackup(_ url: URL) throws {
    var url = url
    var values = URLResourceValues(); values.isExcludedFromBackup = true
    try url.setResourceValues(values)
  }

  private func ensureFiles(rootPath: String, files: [[String: Any]]) throws {
    let fm = FileManager.default
    let root = URL(fileURLWithPath: rootPath, isDirectory: true).standardizedFileURL
    let support = try fm.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true).standardizedFileURL
    guard root.path == support.path || root.path.hasPrefix(support.path + "/") else { throw ModelError.invalidPath }
    try fm.createDirectory(at: root, withIntermediateDirectories: true)
    try excludeBackup(root)
    // A background termination can leave an incomplete copy. Remove only our
    // private temporary files; the serial queue guarantees no concurrent install.
    if let enumeration = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey]) {
      for case let stale as URL in enumeration where stale.lastPathComponent.hasPrefix(".alo-model-") && stale.pathExtension == "part" {
        try? fm.removeItem(at: stale)
      }
    }
    for spec in files {
      guard let asset = spec["asset"] as? String,
            let target = spec["target"] as? String, safeRelative(target),
            let sizeValue = spec["size"] as? NSNumber, sizeValue.int64Value > 0,
            let sha = spec["sha256"] as? String, sha.count == 64,
            sha.allSatisfy({ $0.isHexDigit }) else { throw ModelError.invalidSpec }
      let expected = sizeValue.int64Value
      let output = root.appendingPathComponent(target)
      let marker = URL(fileURLWithPath: output.path + ".verified")
      if fm.fileExists(atPath: output.path),
         let attrs = try? fm.attributesOfItem(atPath: output.path),
         (attrs[.size] as? NSNumber)?.int64Value == expected,
         (try? String(contentsOf: marker, encoding: .utf8)) == sha { continue }
      let source = try assetURL(asset)
      let capacity = try root.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
      if let capacity = capacity, capacity < expected + 64 * 1024 * 1024 { throw ModelError.diskSpace }
      try fm.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
      let temporary = output.deletingLastPathComponent().appendingPathComponent(".alo-model-" + UUID().uuidString + ".part")
      defer { try? fm.removeItem(at: temporary) }
      guard fm.createFile(atPath: temporary.path, contents: nil,
                         attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication]) else { throw ModelError.diskSpace }
      let input = try FileHandle(forReadingFrom: source)
      let destination = try FileHandle(forWritingTo: temporary)
      do {
        var digest = SHA256(); var bytes: Int64 = 0
        while let chunk = try input.read(upToCount: 64 * 1024), !chunk.isEmpty {
          try destination.write(contentsOf: chunk)
          digest.update(data: chunk); bytes += Int64(chunk.count)
        }
        try destination.synchronize(); try destination.close(); try input.close()
        let actual = digest.finalize().map { String(format: "%02x", $0) }.joined()
        guard bytes == expected, actual == sha else { throw ModelError.checksum }
      } catch {
        try? input.close(); try? destination.close(); throw error
      }
      if fm.fileExists(atPath: output.path) {
        _ = try fm.replaceItemAt(output, withItemAt: temporary)
      } else { try fm.moveItem(at: temporary, to: output) }
      try excludeBackup(output)
      try sha.write(to: marker, atomically: true, encoding: .utf8)
      try excludeBackup(marker)
    }
  }
}
