import Darwin
import Foundation

enum UserShellEnvironment {
  enum ShellKind: Equatable {
    case zsh
    case bash
    case fish
    case other
  }

  static func load(
    base: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
    timeout: TimeInterval = 5
  ) -> [String: String] {
    var base = base
    base["HOME"] = homeDirectory.path

    let fileManager = FileManager.default
    let directory = fileManager.temporaryDirectory.appending(
      path: UUID().uuidString, directoryHint: .isDirectory)
    let outputURL = directory.appending(path: "environment")

    do {
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? fileManager.removeItem(at: directory) }
      fileManager.createFile(atPath: outputURL.path, contents: nil)
      let output = try FileHandle(forWritingTo: outputURL)
      defer { try? output.close() }

      let shell = loginShell(environment: base)
      let process = Process()
      process.executableURL = shell
      process.arguments = arguments(for: kind(for: shell.path))
      process.currentDirectoryURL = homeDirectory
      process.standardOutput = output
      process.standardError = FileHandle.nullDevice
      process.environment = base
      try process.run()

      let deadline = Date().addingTimeInterval(timeout)
      while process.isRunning, Date() < deadline {
        Thread.sleep(forTimeInterval: 0.02)
      }
      if process.isRunning {
        process.terminate()
        process.waitUntilExit()
        return base
      }

      try output.synchronize()
      guard process.terminationStatus == 0 else { return base }
      let loaded = decode(try Data(contentsOf: outputURL))
      return base.merging(loaded) { _, shellValue in shellValue }
    } catch {
      return base
    }
  }

  static func kind(for path: String) -> ShellKind {
    switch URL(fileURLWithPath: path).lastPathComponent {
    case "zsh": .zsh
    case "bash": .bash
    case "fish": .fish
    default: .other
    }
  }

  static func arguments(for kind: ShellKind) -> [String] {
    switch kind {
    case .zsh, .bash, .fish:
      ["-l", "-i", "-c", "/usr/bin/env -0"]
    case .other:
      ["-c", "/usr/bin/env -0"]
    }
  }

  static func decode(_ data: Data) -> [String: String] {
    data.split(separator: 0).reduce(into: [:]) { environment, bytes in
      let entry = String(decoding: bytes, as: UTF8.self)
      guard let separator = entry.firstIndex(of: "=") else { return }
      var key = entry[..<separator]
      if let newline = key.lastIndex(where: { $0 == "\n" || $0 == "\r" }) {
        key = key[key.index(after: newline)...]
      }
      guard !key.isEmpty, key.allSatisfy({ $0.isLetter || $0.isNumber || $0 == "_" }) else {
        return
      }
      environment[String(key)] = String(entry[entry.index(after: separator)...])
    }
  }

  private static func loginShell(environment: [String: String]) -> URL {
    let fileManager = FileManager.default
    let accountShell = getpwuid(getuid()).map { String(cString: $0.pointee.pw_shell) }
    let path =
      [environment["SHELL"], accountShell]
      .compactMap { $0 }
      .first { fileManager.isExecutableFile(atPath: $0) }
      ?? "/bin/sh"
    return URL(fileURLWithPath: path)
  }
}

enum RuntimeLocator {
  static func available(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser
  ) -> [PackageRuntime] {
    let paths = searchPaths(environment: environment, homeDirectory: homeDirectory)
    guard
      let orderedPaths = pathsWithCompatibleNodeFirst(paths, environment: environment)
    else { return [] }

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
    return (pathsWithCompatibleNodeFirst(paths, environment: environment) ?? paths)
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

  private static func pathsWithCompatibleNodeFirst(
    _ paths: [URL], environment: [String: String]
  ) -> [URL]? {
    let path = paths.map(\.path).joined(separator: ":")
    for directory in paths {
      let node = directory.appending(path: "node", directoryHint: .notDirectory)
      guard
        FileManager.default.isExecutableFile(atPath: node.path),
        let version = nodeVersion(at: node, path: path, environment: environment),
        supportsNodeVersion(version)
      else {
        continue
      }
      return [directory] + paths.filter { $0.standardizedFileURL != directory.standardizedFileURL }
    }
    return nil
  }

  private static func nodeVersion(
    at executable: URL, path: String, environment: [String: String]
  ) -> String? {
    let process = Process()
    let output = Pipe()
    process.executableURL = executable
    process.arguments = ["--version"]
    process.standardOutput = output
    process.standardError = FileHandle.nullDevice
    var environment = environment
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
