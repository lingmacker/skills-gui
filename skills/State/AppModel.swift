import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
  var runtimeState: RuntimeState = .checking
  var availableRuntimes: [PackageRuntime] = []
  var isCheckingRuntime = false
  var selectedSection: ManagerSection = .discover
  var searchQuery = ""
  var searchResults: [SearchSkill] = []
  var directorySkills: [SearchSkill] = []
  var installedSkills: [InstalledSkill] = []
  var selectedSearchID: String?
  var selectedInstalledID: String?
  var selectedAgents: Set<String>
  var cliVersion: String {
    didSet { defaults.set(cliVersion, forKey: "cliVersion") }
  }
  var copyInstallation = false
  var agentFilter = ""
  var isSearching = false
  var isLoadingMoreSkills = false
  var mutationProgress: SkillMutationProgress?
  var activeOperation: String?
  var errorKey: String?
  var errorDetails: String?

  private let client = SkillsClient()
  private let defaults = UserDefaults.standard
  private var directoryPage = 0
  private var hasMoreDirectorySkills = true
  private var searchResultCache: [String: [SearchSkill]] = [:]
  private var installedLoadError: Error?

  init() {
    let remembered = defaults.stringArray(forKey: "selectedAgents") ?? []
    selectedAgents = Set(remembered)
    cliVersion = defaults.string(forKey: "cliVersion") ?? "latest"
  }

  var runtime: PackageRuntime? {
    if case .available(let runtime) = runtimeState { runtime } else { nil }
  }

  var cliPackage: String {
    let version = cliVersion.trimmingCharacters(in: .whitespacesAndNewlines)
    return "skills@\(version.isEmpty ? "latest" : version)"
  }

  var isShowingDirectory: Bool {
    searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).count < 2
  }

  var visibleSkills: [SearchSkill] {
    isShowingDirectory ? directorySkills : searchResults
  }

  var isInitialDirectoryLoad: Bool {
    isLoadingMoreSkills && directorySkills.isEmpty
  }

  var selectedSearchSkill: SearchSkill? {
    visibleSkills.first { $0.id == selectedSearchID }
  }

  var selectedInstalledSkill: InstalledSkill? {
    installedSkills.first { $0.id == selectedInstalledID }
  }

  var isBusy: Bool { activeOperation != nil }

  func start() async {
    guard !isCheckingRuntime else { return }
    if runtime == nil {
      runtimeState = .checking
    }
    isCheckingRuntime = true
    defer { isCheckingRuntime = false }

    let found = await Task.detached(priority: .userInitiated) { RuntimeLocator.available() }.value
    availableRuntimes = found
    guard
      let preferred =
        found.first(where: { $0.displayName == defaults.string(forKey: "runtimePreference") })
        ?? found.first
    else {
      runtimeState = .missing
      return
    }

    let candidates = [preferred] + found.filter { $0 != preferred }
    var loadedInstalledSkills = false
    for candidate in candidates {
      runtimeState = .available(candidate)
      if await reloadInstalled(reportFailure: false) {
        defaults.set(candidate.displayName, forKey: "runtimePreference")
        loadedInstalledSkills = true
        break
      }
    }
    if !loadedInstalledSkills {
      presentError("error.list_failed", details: installedLoadError?.localizedDescription)
    }
    if directorySkills.isEmpty {
      await loadMoreDiscovery()
    }
  }

  func selectRuntime(_ runtime: PackageRuntime) {
    guard availableRuntimes.contains(runtime) else { return }
    defaults.set(runtime.displayName, forKey: "runtimePreference")
    runtimeState = .available(runtime)
    Task { await reloadInstalled() }
  }

  func search() async {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard query.count >= 2 else {
      searchResults = []
      isSearching = false
      selectFirstVisibleSkillIfNeeded()
      return
    }

    if let cachedResults = searchResultCache[query] {
      searchResults = cachedResults
      isSearching = false
      selectFirstVisibleSkillIfNeeded()
      return
    }

    searchResults = []
    isSearching = true
    defer {
      if searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query {
        isSearching = false
      }
    }

    do {
      try await Task.sleep(for: .milliseconds(250))
      let results = try await client.search(query: query)
      guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
      searchResults = results
      searchResultCache[query] = results
      selectFirstVisibleSkillIfNeeded()
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
      guard searchQuery.trimmingCharacters(in: .whitespacesAndNewlines) == query else { return }
      searchResults = []
      presentError("error.search_failed")
    }
  }

  func loadMoreDiscovery() async {
    guard isShowingDirectory, hasMoreDirectorySkills, !isLoadingMoreSkills else { return }
    isLoadingMoreSkills = true
    defer { isLoadingMoreSkills = false }

    do {
      let response = try await client.discoveryPage(directoryPage + 1)
      guard isShowingDirectory else { return }
      let existingIDs = Set(directorySkills.map(\.id))
      directorySkills += response.skills.filter { !existingIDs.contains($0.id) }
      directoryPage = response.page
      hasMoreDirectorySkills = response.hasMore
      selectFirstVisibleSkillIfNeeded()
    } catch is CancellationError {
      return
    } catch {
      guard !Task.isCancelled, (error as? URLError)?.code != .cancelled else { return }
      guard isShowingDirectory else { return }
      presentError("error.search_failed")
    }
  }

  @discardableResult
  func reloadInstalled(reportFailure: Bool = true) async -> Bool {
    guard let runtime else { return false }
    do {
      let response = try await client.list(runtime: runtime, package: cliPackage)
      installedLoadError = nil
      installedSkills = response.skills.sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
      if !installedSkills.contains(where: { $0.id == selectedInstalledID }) {
        selectedInstalledID = installedSkills.first?.id
      }
      return true
    } catch {
      installedLoadError = error
      if reportFailure {
        presentError("error.list_failed", details: error.localizedDescription)
      }
      return false
    }
  }

  func installSelected() async {
    guard let runtime, let skill = selectedSearchSkill, !selectedAgents.isEmpty else { return }
    let package = cliPackage
    let agents = selectedAgents.sorted()
    let copy = copyInstallation
    let arguments = SkillsClient.addArguments(skill: skill, agents: agents, copy: copy)
    await performInstall(
      action: .install,
      displayName: skill.name,
      command: runtime.commandDescription(for: arguments, package: package),
      preferredInstalledNames: [skill.installName, skill.name],
      failureKey: "error.install_failed",
      skippedKey: "error.install_skipped"
    ) {
      try await self.client.add(
        runtime: runtime,
        package: package,
        skill: skill,
        agents: agents,
        copy: copy
      )
    }
  }

  func loadRepositorySkills(source: String) async -> [String]? {
    let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard Self.isValidGitHubRepositorySource(source) else {
      presentError("error.repository_source_invalid")
      return nil
    }
    guard let runtime else { return nil }

    do {
      return try await client.repositorySkills(
        runtime: runtime, package: cliPackage, source: source)
    } catch {
      presentError("error.repository_load_failed", details: error.localizedDescription)
      return nil
    }
  }

  func installRepository(source: String, skillNames: [String]) async {
    let source = source.trimmingCharacters(in: .whitespacesAndNewlines)
    guard Self.isValidGitHubRepositorySource(source) else {
      presentError("error.repository_source_invalid")
      return
    }
    guard let runtime, !skillNames.isEmpty, !selectedAgents.isEmpty else { return }
    let package = cliPackage
    let skillNames = skillNames.sorted()
    let agents = selectedAgents.sorted()
    let copy = copyInstallation
    let arguments = SkillsClient.repositoryAddArguments(
      source: source, skillNames: skillNames, agents: agents, copy: copy)
    await performInstall(
      action: .installRepository,
      displayName: source,
      command: runtime.commandDescription(for: arguments, package: package),
      preferredInstalledNames: Set(skillNames),
      failureKey: "error.install_failed",
      skippedKey: "error.install_skipped"
    ) {
      try await self.client.addRepository(
        runtime: runtime,
        package: package,
        source: source,
        skillNames: skillNames,
        agents: agents,
        copy: copy
      )
    }
  }

  nonisolated static func isValidGitHubRepositorySource(_ input: String) -> Bool {
    let source = input.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !source.isEmpty else { return false }

    if let components = URLComponents(string: source), let scheme = components.scheme?.lowercased()
    {
      guard components.user == nil, components.password == nil else { return false }
      guard ["http", "https"].contains(scheme),
        ["github.com", "www.github.com"].contains(components.host?.lowercased() ?? "")
      else { return false }
      let parts = components.path.split(separator: "/")
      return parts.count >= 2 && parts.prefix(2).allSatisfy(isValidGitHubPathSegment)
    }

    let parts = source.split(separator: "/", omittingEmptySubsequences: false)
    return parts.count == 2 && parts.allSatisfy(isValidGitHubPathSegment)
  }

  private nonisolated static func isValidGitHubPathSegment(_ segment: Substring) -> Bool {
    !segment.isEmpty
      && segment.allSatisfy {
        $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "."
      }
  }

  private func performInstall(
    action: SkillMutationAction,
    displayName: String,
    command: String,
    preferredInstalledNames: Set<String>,
    failureKey: String,
    skippedKey: String,
    operation: () async throws -> (outcomes: [AddOutcome], result: CommandResult)
  ) async {
    rememberAgents()
    activeOperation = displayName
    mutationProgress = SkillMutationProgress(
      action: action,
      skillName: displayName,
      command: command,
      phase: .running,
      log: "",
      errorKey: nil
    )
    defer { activeOperation = nil }

    do {
      let response = try await operation()
      let unsuccessful = response.outcomes.filter { $0.status != "installed" }
      let succeeded =
        response.result.status == 0 && !response.outcomes.isEmpty && unsuccessful.isEmpty
      mutationProgress?.log = response.result.log

      guard succeeded else {
        let skipped = !unsuccessful.isEmpty && unsuccessful.allSatisfy { $0.status == "skipped" }
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = skipped ? skippedKey : failureKey
        return
      }

      mutationProgress?.phase = .refreshing
      guard await reloadInstalled(reportFailure: false) else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.list_failed"
        return
      }

      let installedNames = preferredInstalledNames.union(response.outcomes.compactMap(\.name))
      if let installed = installedSkills.first(where: { installedNames.contains($0.name) }) {
        selectedSection = .installed
        selectedInstalledID = installed.id
      } else if preferredInstalledNames.isEmpty {
        selectedSection = .installed
      }
      mutationProgress?.phase = .succeeded
    } catch {
      let result = (error as? SkillsClientError)?.commandResult
      mutationProgress?.phase = .failed
      mutationProgress?.errorKey = failureKey
      mutationProgress?.log =
        result?.log.isEmpty == false
        ? result!.log
        : error.localizedDescription
    }
  }

  func link(_ skills: [InstalledSkill], to selectedAgents: Set<String>) async {
    guard let runtime, !skills.isEmpty, !selectedAgents.isEmpty else { return }
    let package = cliPackage
    let agents = selectedAgents.sorted()
    let linkableSkills = skills.compactMap { skill -> (source: String, skill: InstalledSkill)? in
      guard let source = skill.installSource else { return nil }
      return (source, skill)
    }
    guard !linkableSkills.isEmpty else { return }

    let operations = Dictionary(grouping: linkableSkills) { $0.source }
      .map { source, entries in
        (
          source: source,
          skillNames: entries.map(\.skill.name).sorted()
        )
      }
      .sorted { $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedAscending }
    let names = linkableSkills.map(\.skill.name).sorted()
    let displayName =
      names.count <= 3
      ? names.joined(separator: ", ")
      : "\(names.prefix(3).joined(separator: ", ")) +\(names.count - 3)"
    let commands = operations.map {
      runtime.commandDescription(
        for: SkillsClient.linkArguments(
          source: $0.source, skillNames: $0.skillNames, agents: agents),
        package: package)
    }

    await performInstall(
      action: .link,
      displayName: displayName,
      command: commands.joined(separator: "\n"),
      preferredInstalledNames: Set(names),
      failureKey: "error.link_failed",
      skippedKey: "error.link_failed"
    ) {
      var outcomes: [AddOutcome] = []
      var logs: [String] = []
      var failed = false
      for operation in operations {
        let response = try await self.client.link(
          runtime: runtime,
          package: package,
          source: operation.source,
          skillNames: operation.skillNames,
          agents: agents
        )
        outcomes += response.outcomes
        if !response.result.log.isEmpty { logs.append(response.result.log) }
        if response.result.status != 0 { failed = true }
      }
      return (
        outcomes,
        CommandResult(
          status: failed ? 1 : 0,
          standardOutput: logs.joined(separator: "\n\n"),
          standardError: ""
        )
      )
    }
  }

  func update(skillNames: [String]) async {
    guard let runtime else { return }
    let package = cliPackage
    let arguments = SkillsClient.updateArguments(skillNames: skillNames)
    let displayName = skillNames.joined(separator: ", ")
    activeOperation = displayName.isEmpty ? "All skills" : displayName
    mutationProgress = SkillMutationProgress(
      action: .update,
      skillName: displayName,
      command: runtime.commandDescription(for: arguments, package: package),
      phase: .running,
      log: "",
      errorKey: nil
    )
    defer { activeOperation = nil }

    do {
      let result = try await client.update(
        runtime: runtime, package: package, skillNames: skillNames)
      mutationProgress?.log = result.log
      guard result.status == 0 else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.update_failed"
        return
      }

      mutationProgress?.phase = .refreshing
      guard await reloadInstalled(reportFailure: false) else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.list_failed"
        return
      }
      mutationProgress?.phase = .succeeded
    } catch {
      let result = (error as? SkillsClientError)?.commandResult
      mutationProgress?.phase = .failed
      mutationProgress?.errorKey = "error.update_failed"
      mutationProgress?.log =
        result?.log.isEmpty == false
        ? result!.log
        : error.localizedDescription
    }
  }

  func removeSelected() async {
    guard let runtime, let skill = selectedInstalledSkill else { return }
    let package = cliPackage
    let arguments = SkillsClient.removeArguments(skillName: skill.name)
    activeOperation = skill.name
    mutationProgress = SkillMutationProgress(
      action: .remove,
      skillName: skill.name,
      command: runtime.commandDescription(for: arguments, package: package),
      phase: .running,
      log: "",
      errorKey: nil
    )
    defer { activeOperation = nil }

    do {
      let result = try await client.remove(
        runtime: runtime, package: package, skillName: skill.name)
      mutationProgress?.log = result.log
      guard result.status == 0 else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.remove_failed"
        return
      }

      mutationProgress?.phase = .refreshing
      guard await reloadInstalled(reportFailure: false) else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.list_failed"
        return
      }
      guard !installedSkills.contains(where: { $0.name == skill.name }) else {
        mutationProgress?.phase = .failed
        mutationProgress?.errorKey = "error.remove_failed"
        return
      }
      mutationProgress?.phase = .succeeded
    } catch {
      let result = (error as? SkillsClientError)?.commandResult
      mutationProgress?.phase = .failed
      mutationProgress?.errorKey = "error.remove_failed"
      mutationProgress?.log =
        result?.log.isEmpty == false
        ? result!.log
        : error.localizedDescription
    }
  }

  func setSelectedAgents(_ agents: Set<String>) {
    selectedAgents = agents
    rememberAgents()
  }

  private func selectFirstVisibleSkillIfNeeded() {
    if !visibleSkills.contains(where: { $0.id == selectedSearchID }) {
      selectedSearchID = visibleSkills.first?.id
    }
  }

  private func rememberAgents() {
    defaults.set(selectedAgents.sorted(), forKey: "selectedAgents")
  }

  func dismissMutationProgress() {
    guard mutationProgress?.phase.isRunning != true else { return }
    mutationProgress = nil
  }

  func dismissError() {
    errorKey = nil
    errorDetails = nil
  }

  private func presentError(_ key: String, details: String? = nil) {
    errorDetails = details
    errorKey = key
  }
}
