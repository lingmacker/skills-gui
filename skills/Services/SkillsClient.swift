import Foundation

struct SkillsClient: Sendable {
  func search(query: String) async throws -> [SearchSkill] {
    var components = URLComponents(string: "https://skills.sh/api/search")!
    components.queryItems = [
      URLQueryItem(name: "q", value: query),
      URLQueryItem(name: "limit", value: "50"),
    ]
    guard let url = components.url else { throw SkillsClientError.invalidSearchURL }

    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw SkillsClientError.searchUnavailable
    }
    return try JSONDecoder().decode(SearchResponse.self, from: data).skills
  }

  func discoveryPage(_ page: Int) async throws -> DiscoveryPage {
    let url = URL(string: "https://skills.sh/api/skills/all-time/\(page)")!
    let (data, response) = try await URLSession.shared.data(from: url)
    guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
      throw SkillsClientError.searchUnavailable
    }
    return try JSONDecoder().decode(DiscoveryPage.self, from: data)
  }

  func list(runtime: PackageRuntime, package: String) async throws -> (
    skills: [InstalledSkill], result: CommandResult
  ) {
    let result = try await run(
      runtime: runtime, package: package, arguments: ["list", "-g", "--json"])
    guard result.status == 0 else { throw SkillsClientError.commandFailed(result) }
    do {
      return (try Self.decodeInstalledSkills(from: result.standardOutput), result)
    } catch {
      throw SkillsClientError.incompatibleOutput(result)
    }
  }

  static func decodeInstalledSkills(from output: String) throws -> [InstalledSkill] {
    let decoder = JSONDecoder()
    let data = Data(output.utf8)
    if let skills = try? decoder.decode([InstalledSkill].self, from: data) {
      return skills
    }

    var searchStart = output.startIndex
    while let start = output[searchStart...].firstIndex(of: "["),
      let end = output.lastIndex(of: "]"),
      start <= end
    {
      if let skills = try? decoder.decode(
        [InstalledSkill].self, from: Data(output[start...end].utf8))
      {
        return skills
      }
      searchStart = output.index(after: start)
    }

    return try decoder.decode([InstalledSkill].self, from: data)
  }
  func repositorySkills(runtime: PackageRuntime, package: String, source: String) async throws
    -> [String]
  {
    let result = try await run(
      runtime: runtime, package: package, arguments: ["add", source, "--list"])
    guard result.status == 0 else { throw SkillsClientError.commandFailed(result) }
    let skills = Self.decodeRepositorySkillNames(from: result.standardOutput)
    guard !skills.isEmpty else { throw SkillsClientError.incompatibleOutput(result) }
    return skills
  }

  static func decodeRepositorySkillNames(from output: String) -> [String] {
    guard let marker = output.range(of: "Available Skills") else { return [] }
    return output[marker.upperBound...]
      .split(separator: "\n", omittingEmptySubsequences: false)
      .prefix { !$0.contains("Use --skill") }
      .compactMap { line in
        guard line.hasPrefix("│    "), !line.hasPrefix("│      ") else { return nil }
        let name = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? nil : name
      }
  }

  func add(
    runtime: PackageRuntime,
    package: String,
    skill: SearchSkill,
    agents: [String],
    copy: Bool
  ) async throws -> (outcomes: [AddOutcome], result: CommandResult) {
    try await add(
      runtime: runtime,
      package: package,
      arguments: Self.addArguments(skill: skill, agents: agents, copy: copy)
    )
  }

  func addRepository(
    runtime: PackageRuntime,
    package: String,
    source: String,
    skillNames: [String],
    agents: [String],
    copy: Bool
  ) async throws -> (outcomes: [AddOutcome], result: CommandResult) {
    try await add(
      runtime: runtime,
      package: package,
      arguments: Self.repositoryAddArguments(
        source: source, skillNames: skillNames, agents: agents, copy: copy)
    )
  }

  static func addArguments(skill: SearchSkill, agents: [String], copy: Bool) -> [String] {
    addArguments(source: skill.source, skills: [skill.installName], agents: agents, copy: copy)
  }

  static func repositoryAddArguments(
    source: String, skillNames: [String], agents: [String], copy: Bool
  ) -> [String] {
    addArguments(source: source, skills: skillNames, agents: agents, copy: copy)
  }

  static func linkArguments(source: String, skillNames: [String], agents: [String]) -> [String] {
    addArguments(source: source, skills: skillNames, agents: agents, copy: false)
  }

  func link(
    runtime: PackageRuntime,
    package: String,
    source: String,
    skillNames: [String],
    agents: [String]
  ) async throws -> (outcomes: [AddOutcome], result: CommandResult) {
    try await add(
      runtime: runtime,
      package: package,
      arguments: Self.linkArguments(source: source, skillNames: skillNames, agents: agents)
    )
  }

  private static func addArguments(
    source: String,
    skills: [String],
    agents: [String],
    copy: Bool
  ) -> [String] {
    var arguments = ["add", source, "-g"]
    for skill in skills {
      arguments += ["-s", skill]
    }
    arguments.append("-a")

    // Work around skills#745: non-interactive single-target installs are forced to copy mode.
    let targetAgents = copy || agents.contains("universal") ? agents : agents + ["universal"]
    arguments += targetAgents
    arguments += ["-y", "--json"]
    if copy { arguments.append("--copy") }
    return arguments
  }

  private func add(
    runtime: PackageRuntime,
    package: String,
    arguments: [String]
  ) async throws -> (outcomes: [AddOutcome], result: CommandResult) {
    let result = try await run(runtime: runtime, package: package, arguments: arguments)
    guard
      let outcomes = try? JSONDecoder().decode(
        [AddOutcome].self, from: Data(result.standardOutput.utf8))
    else {
      throw result.status == 0
        ? SkillsClientError.incompatibleOutput(result)
        : SkillsClientError.commandFailed(result)
    }
    return (outcomes, result)
  }
  static func updateArguments(skillNames: [String]) -> [String] {
    ["update"] + skillNames + ["-g", "-y"]
  }

  func update(runtime: PackageRuntime, package: String, skillNames: [String]) async throws
    -> CommandResult
  {
    try await run(
      runtime: runtime, package: package, arguments: Self.updateArguments(skillNames: skillNames))
  }

  static func removeArguments(skillName: String) -> [String] {
    ["remove", skillName, "-g", "-y"]
  }

  func remove(runtime: PackageRuntime, package: String, skillName: String) async throws
    -> CommandResult
  {
    try await run(
      runtime: runtime, package: package, arguments: Self.removeArguments(skillName: skillName))
  }

  private static func stripTerminalFormatting(_ output: String) -> String {
    output.replacingOccurrences(
      of: "\u{001B}\\[[0-?]*[ -/]*[@-~]|\u{009B}[0-?]*[ -/]*[@-~]",
      with: "",
      options: .regularExpression
    )
  }

  private func run(runtime: PackageRuntime, package: String, arguments: [String]) async throws
    -> CommandResult
  {
    try await Task.detached(priority: .userInitiated) {
      let fileManager = FileManager.default
      let directory = fileManager.temporaryDirectory.appending(
        path: UUID().uuidString, directoryHint: .isDirectory)
      try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
      defer { try? fileManager.removeItem(at: directory) }

      let stdoutURL = directory.appending(path: "stdout")
      let stderrURL = directory.appending(path: "stderr")
      fileManager.createFile(atPath: stdoutURL.path, contents: nil)
      fileManager.createFile(atPath: stderrURL.path, contents: nil)

      let stdout = try FileHandle(forWritingTo: stdoutURL)
      let stderr = try FileHandle(forWritingTo: stderrURL)
      defer {
        try? stdout.close()
        try? stderr.close()
      }

      var environment = ProcessInfo.processInfo.environment
      let path = RuntimeLocator.augmentedPath(environment: environment)
      environment["PATH"] = path
      environment["HOME"] = fileManager.homeDirectoryForCurrentUser.path

      let process = Process()
      process.executableURL = runtime.executableURL
      process.arguments = runtime.arguments(for: arguments, package: package)
      process.currentDirectoryURL = fileManager.homeDirectoryForCurrentUser
      process.standardOutput = stdout
      process.standardError = stderr
      process.environment = environment

      do {
        try process.run()
        process.waitUntilExit()
      } catch {
        throw SkillsClientError.launchFailed(runtime.displayName, error)
      }

      try stdout.synchronize()
      try stderr.synchronize()
      let standardOutput = Self.stripTerminalFormatting(
        String(decoding: try Data(contentsOf: stdoutURL), as: UTF8.self))
      let standardError = Self.stripTerminalFormatting(
        String(decoding: try Data(contentsOf: stderrURL), as: UTF8.self))
      return CommandResult(
        status: process.terminationStatus,
        standardOutput: standardOutput,
        standardError: standardError
      )
    }.value
  }
}

enum SkillsClientError: LocalizedError {
  case invalidSearchURL
  case searchUnavailable
  case launchFailed(String, Error)
  case commandFailed(CommandResult)
  case incompatibleOutput(CommandResult)

  var errorDescription: String? {
    switch self {
    case .invalidSearchURL:
      "Invalid skills.sh search URL."
    case .searchUnavailable:
      "The skills directory is unavailable."
    case .launchFailed(let runtime, let error):
      "Could not launch \(runtime): \(error.localizedDescription)"
    case .commandFailed(let result):
      result.log.isEmpty ? "The skills command failed with status \(result.status)." : result.log
    case .incompatibleOutput(let result):
      result.log.isEmpty ? "The skills CLI returned an unsupported response." : result.log
    }
  }

  var commandResult: CommandResult? {
    switch self {
    case .commandFailed(let result), .incompatibleOutput(let result): result
    default: nil
    }
  }
}
