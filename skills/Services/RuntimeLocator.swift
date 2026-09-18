import Foundation

enum RuntimeLocator {
  static func available(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> [PackageRuntime] {
    let paths = searchPaths(environment: environment, homeDirectory: homeDirectory)
    guard let orderedPaths = pathsWithCompatibleNodeFirst(paths) else { return [] }

    var runtimes: [PackageRuntime] = []
    if let bunx = executable(named: "bunx", paths: orderedPaths) {
      runtimes.append(.bunx(bunx))
    }
    if let npx = executable(named: "npx", paths: orderedPaths) {
      runtimes.append(.npx(npx))
    }
    return runtimes
  }

  static func supportsNodeVersion(_ value: String) -> Bool {
    let components =
      value
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
      .split(separator: ".")
      .prefix(3)
      .compactMap { Int($0) }
    guard components.count >= 2 else { return false }

    let major = components[0]
    let minor = components[1]
    if major != 22 { return major > 22 }
    return minor >= 20
  }

  static func augmentedPath(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> String {
    let paths = searchPaths(environment: environment, homeDirectory: homeDirectory)
    return (pathsWithCompatibleNodeFirst(paths) ?? paths)
      .map(\.path)
      .joined(separator: ":")
  }

  private static func searchPaths(environment: [String: String], homeDirectory: URL) -> [URL] {
    var paths = (environment["PATH"] ?? "")
      .split(separator: ":")
      .map { URL(fileURLWithPath: String($0), isDirectory: true) }

    paths += [
      homeDirectory.appending(path: ".bun/bin", directoryHint: .isDirectory),
      homeDirectory.appending(path: ".local/bin", directoryHint: .isDirectory),
      homeDirectory.appending(path: ".volta/bin", directoryHint: .isDirectory),
      homeDirectory.appending(path: ".asdf/shims", directoryHint: .isDirectory),
      homeDirectory.appending(path: ".mise/shims", directoryHint: .isDirectory),
      URL(fileURLWithPath: "/opt/homebrew/bin", isDirectory: true),
      URL(fileURLWithPath: "/usr/local/bin", isDirectory: true),
      URL(fileURLWithPath: "/usr/bin", isDirectory: true),
    ]

    let nvmRoot = homeDirectory.appending(path: ".nvm/versions/node", directoryHint: .isDirectory)
    if let versions = try? FileManager.default.contentsOfDirectory(
      at: nvmRoot,
      includingPropertiesForKeys: nil,
      options: .skipsHiddenFiles
    ) {
      paths += versions.sorted { $0.lastPathComponent > $1.lastPathComponent }
        .map { $0.appending(path: "bin", directoryHint: .isDirectory) }
    }

    var seen = Set<String>()
    return paths.filter { seen.insert($0.standardizedFileURL.path).inserted }
  }

  private static func executable(named name: String, paths: [URL]) -> URL? {
    paths
      .map { $0.appending(path: name, directoryHint: .notDirectory) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
  }

  private static func pathsWithCompatibleNodeFirst(_ paths: [URL]) -> [URL]? {
    let path = paths.map(\.path).joined(separator: ":")
    for directory in paths {
      let node = directory.appending(path: "node", directoryHint: .notDirectory)
      guard
        FileManager.default.isExecutableFile(atPath: node.path),
        let version = nodeVersion(at: node, path: path),
        supportsNodeVersion(version)
      else {
        continue
      }
      return [directory] + paths.filter { $0.standardizedFileURL != directory.standardizedFileURL }
    }
    return nil
  }

  private static func nodeVersion(at executable: URL, path: String) -> String? {
    let process = Process()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = ["--version"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    var environment = ProcessInfo.processInfo.environment
    environment["PATH"] = path
    process.environment = environment

    do {
      try process.run()
      process.waitUntilExit()
      guard process.terminationStatus == 0 else { return nil }
      return String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
    } catch {
      return nil
    }
  }
}
