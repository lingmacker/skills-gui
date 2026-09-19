import XCTest

@testable import Skills

final class SkillsTests: XCTestCase {
  func testBunxLaunchArgumentsUseSelectedPackage() {
    let bunx = URL(fileURLWithPath: "/tmp/bunx")
    let runtime = PackageRuntime.bunx(bunx)

    XCTAssertEqual(
      runtime.arguments(for: ["list", "-g", "--json"], package: "skills@1.7.0"),
      ["skills@1.7.0", "list", "-g", "--json"]
    )
  }

  func testNpxSuppressesItsOwnInstallPrompt() {
    let npx = URL(fileURLWithPath: "/tmp/npx")
    let runtime = PackageRuntime.npx(npx)

    XCTAssertEqual(
      runtime.arguments(for: ["update", "-g", "-y"], package: "skills@latest"),
      ["-y", "skills@latest", "update", "-g", "-y"]
    )
  }

  func testNodeRuntimeMinimumVersion() {
    XCTAssertFalse(RuntimeLocator.supportsNodeVersion("v22.19.9"))
    XCTAssertTrue(RuntimeLocator.supportsNodeVersion("v22.20.0"))
    XCTAssertTrue(RuntimeLocator.supportsNodeVersion("v23.0.0"))
  }
  func testShellSpecificStartupArguments() {
    XCTAssertEqual(UserShellEnvironment.kind(for: "/bin/zsh"), .zsh)
    XCTAssertEqual(UserShellEnvironment.kind(for: "/bin/bash"), .bash)
    XCTAssertEqual(UserShellEnvironment.kind(for: "/opt/homebrew/bin/fish"), .fish)
    XCTAssertEqual(UserShellEnvironment.kind(for: "/bin/tcsh"), .other)
    XCTAssertEqual(
      UserShellEnvironment.arguments(for: .zsh),
      ["-l", "-i", "-c", "/usr/bin/env -0"])
    XCTAssertEqual(
      UserShellEnvironment.arguments(for: .other),
      ["-c", "/usr/bin/env -0"])
  }

  func testShellEnvironmentLoadsOnceFromConfiguredShell() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let shell = root.appending(path: "fish")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try makeExecutable(
      at: shell,
      contents:
        "#!/bin/sh\nprintf 'startup output\\nPATH=/custom/bin\\0JAVA_HOME=/custom/java\\0VALUE=a=b\\0'\n"
    )

    let environment = UserShellEnvironment.load(
      base: ["SHELL": shell.path, "BASE_VALUE": "preserved"],
      homeDirectory: root,
      timeout: 1
    )

    XCTAssertEqual(environment["PATH"], "/custom/bin")
    XCTAssertEqual(environment["JAVA_HOME"], "/custom/java")
    XCTAssertEqual(environment["VALUE"], "a=b")
    XCTAssertEqual(environment["BASE_VALUE"], "preserved")
  }

  func testClientPassesCapturedEnvironmentDirectlyToRuntime() async throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let bunx = root.appending(path: "bunx")
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }
    try makeExecutable(
      at: bunx,
      contents:
        "#!/bin/sh\nprintf '[{\"name\":\"%s\",\"path\":\"/tmp\",\"scope\":\"global\",\"agents\":[]}]' \"$CAPTURED_VALUE\"\n"
    )

    let client = SkillsClient(environment: [
      "CAPTURED_VALUE": "from-shell",
      "HOME": root.path,
      "PATH": "/usr/bin",
    ])
    let response = try await client.list(runtime: .bunx(bunx), package: "skills@latest")

    XCTAssertEqual(response.skills.map(\.name), ["from-shell"])
  }

  func testRuntimeSkipsAnOlderNodeEarlierInPath() throws {
    let root = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let old = root.appending(path: "old")
    let compatible = root.appending(path: "compatible")
    try FileManager.default.createDirectory(at: old, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: compatible, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: root) }

    try makeExecutable(at: old.appending(path: "node"), contents: "#!/bin/sh\necho v22.19.0\n")
    try makeExecutable(
      at: compatible.appending(path: "node"), contents: "#!/bin/sh\necho v22.20.0\n")
    try makeExecutable(at: old.appending(path: "bunx"), contents: "#!/bin/sh\nexit 0\n")
    try makeExecutable(at: compatible.appending(path: "npx"), contents: "#!/bin/sh\nexit 0\n")

    let environment = ["PATH": "\(old.path):\(compatible.path)"]
    let runtimes = RuntimeLocator.available(
      environment: environment,
      homeDirectory: root.appending(path: "home")
    )

    XCTAssertEqual(
      runtimes,
      [
        .bunx(old.appending(path: "bunx")),
        .npx(compatible.appending(path: "npx")),
      ])
    XCTAssertTrue(
      RuntimeLocator.augmentedPath(
        environment: environment,
        homeDirectory: root.appending(path: "home")
      ).hasPrefix(compatible.path))
  }

  private func makeExecutable(at url: URL, contents: String) throws {
    try Data(contents.utf8).write(to: url)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o755],
      ofItemAtPath: url.path
    )
  }

  func testSearchResponseUsesSkillIdentifierForInstallation() throws {
    let data = Data(
      #"{"skills":[{"id":"owner/repo/my-skill","skillId":"my-skill","name":"My Skill","installs":42,"source":"owner/repo"}]}"#
        .utf8)
    let skill = try XCTUnwrap(JSONDecoder().decode(SearchResponse.self, from: data).skills.first)

    XCTAssertEqual(skill.installName, "my-skill")
    XCTAssertEqual(skill.source, "owner/repo")
  }
  func testSymlinkInstallTargetsCanonicalDirectory() throws {
    let data = Data(
      #"{"skills":[{"id":"owner/repo/my-skill","skillId":"my-skill","name":"My Skill","installs":42,"source":"owner/repo"}]}"#
        .utf8)
    let skill = try XCTUnwrap(JSONDecoder().decode(SearchResponse.self, from: data).skills.first)

    XCTAssertEqual(
      SkillsClient.addArguments(skill: skill, agents: ["claude-code"], copy: false),
      [
        "add", "owner/repo", "-g", "-s", "my-skill", "-a", "claude-code", "universal", "-y",
        "--json",
      ])
  }
  func testRepositoryInstallUsesOnlySelectedSkills() {
    XCTAssertEqual(
      SkillsClient.repositoryAddArguments(
        source: "owner/repo",
        skillNames: ["alpha", "beta"],
        agents: ["codex"],
        copy: false
      ),
      [
        "add", "owner/repo", "-g", "-s", "alpha", "-s", "beta", "-a", "codex", "universal",
        "-y", "--json",
      ])
  }

  func testRepositorySkillListParserIgnoresDescriptionsAndGroups() {
    let output = """
      ◇  Available Skills
      Plugin Group
      │    alpha
      │
      │      Alpha description
      │    beta
      │
      │      Beta description
      └  Use --skill <name> to install specific skills
      """

    XCTAssertEqual(SkillsClient.decodeRepositorySkillNames(from: output), ["alpha", "beta"])
  }

  func testDirectoryPageBuildsStableIdentifierWithoutSearchID() throws {
    let data = Data(
      #"{"skills":[{"skillId":"my-skill","name":"My Skill","installs":42,"source":"owner/repo"}],"hasMore":true,"page":1}"#
        .utf8)
    let page = try JSONDecoder().decode(DiscoveryPage.self, from: data)

    XCTAssertEqual(page.skills.first?.id, "owner/repo/my-skill")
    XCTAssertTrue(page.hasMore)
    XCTAssertEqual(page.page, 1)
  }

  func testInstalledListParserIgnoresRuntimeNoise() throws {
    let output = """
      Resolving dependencies
      [{"name":"my-skill","path":"/tmp/my-skill","scope":"global","agents":["Codex"]}]
      Saved lockfile
      """

    let skills = try SkillsClient.decodeInstalledSkills(from: output)

    XCTAssertEqual(skills.map(\.name), ["my-skill"])
    XCTAssertEqual(skills.first?.agents, ["Codex"])
  }

}
