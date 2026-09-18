import Foundation

enum ManagerSection: String, CaseIterable, Identifiable {
  case discover
  case installed
  case settings

  var id: Self { self }

  var titleKey: LocalizedStringResource {
    switch self {
    case .discover: "navigation.discover"
    case .installed: "navigation.installed"
    case .settings: "navigation.settings"
    }
  }

  var systemImage: String {
    switch self {
    case .discover: "magnifyingglass"
    case .installed: "square.stack.3d.up"
    case .settings: "gearshape"
    }
  }
}

struct SearchResponse: Decodable {
  let skills: [SearchSkill]
}

struct DiscoveryPage: Decodable {
  let skills: [SearchSkill]
  let hasMore: Bool
  let page: Int
}

struct SearchSkill: Decodable, Identifiable, Hashable, Sendable {
  let id: String
  let skillId: String?
  let name: String
  let installs: Int
  let source: String

  private enum CodingKeys: String, CodingKey {
    case id
    case skillId
    case name
    case installs
    case source
  }

  init(from decoder: Decoder) throws {
    let values = try decoder.container(keyedBy: CodingKeys.self)
    skillId = try values.decodeIfPresent(String.self, forKey: .skillId)
    name = try values.decode(String.self, forKey: .name)
    installs = try values.decode(Int.self, forKey: .installs)
    source = try values.decode(String.self, forKey: .source)
    id =
      try values.decodeIfPresent(String.self, forKey: .id)
      ?? "\(source)/\(skillId ?? name)"
  }

  var installName: String { skillId ?? id.split(separator: "/").last.map(String.init) ?? name }
}

struct InstalledSkill: Decodable, Identifiable, Hashable, Sendable {
  var id: String { path }

  let name: String
  let path: String
  let scope: String
  let agents: [String]
  let source: String?
  let sourceUrl: String?
  let sourceType: String?

  var installSource: String? { source ?? sourceUrl }
}

struct AddOutcome: Decodable, Sendable {
  let status: String
  let name: String?
  let error: String?
  let reason: String?
}

enum PackageRuntime: Hashable, Sendable {
  case bunx(URL)
  case npx(URL)

  var executableURL: URL {
    switch self {
    case .bunx(let url), .npx(let url): url
    }
  }

  var displayName: String {
    switch self {
    case .bunx: "bunx"
    case .npx: "npx"
    }
  }

  func arguments(for skillsArguments: [String], package: String) -> [String] {
    switch self {
    case .bunx:
      [package] + skillsArguments
    case .npx:
      ["-y", package] + skillsArguments
    }
  }

  func commandDescription(for skillsArguments: [String], package: String) -> String {
    ([displayName] + arguments(for: skillsArguments, package: package))
      .map(Self.shellQuoted)
      .joined(separator: " ")
  }

  private static func shellQuoted(_ argument: String) -> String {
    guard !argument.isEmpty else { return "''" }
    let isSafe = argument.allSatisfy {
      $0.isLetter || $0.isNumber || $0 == "-" || $0 == "_" || $0 == "." || $0 == "/"
        || $0 == ":" || $0 == "@"
    }
    guard !isSafe else { return argument }
    return "'\(argument.replacingOccurrences(of: "'", with: "'\\''"))'"
  }
}

enum RuntimeState: Equatable {
  case checking
  case available(PackageRuntime)
  case missing
}

struct CommandResult: Sendable {
  let status: Int32
  let standardOutput: String
  let standardError: String

  var log: String {
    [standardOutput, standardError]
      .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
      .joined(separator: "\n")
  }
}

enum SkillMutationAction: Sendable {
  case install
  case installRepository
  case update
  case link
  case remove
}

enum SkillMutationPhase: Sendable {
  case running
  case refreshing
  case succeeded
  case failed

  var isRunning: Bool {
    self == .running || self == .refreshing
  }
}

struct SkillMutationProgress: Sendable {
  let action: SkillMutationAction
  let skillName: String
  let command: String
  var phase: SkillMutationPhase
  var log: String
  var errorKey: String?
}

struct AgentDefinition: Identifiable, Hashable, Sendable {
  let id: String
  let skillDirectory: String
}

enum AgentCatalog {
  static let global: [AgentDefinition] = [
    ("aider-desk", "~/.aider-desk/skills"),
    ("amp", "~/.config/agents/skills"),
    ("antigravity", "~/.gemini/antigravity/skills"),
    ("antigravity-cli", "~/.gemini/antigravity-cli/skills"),
    ("astrbot", "~/.astrbot/data/skills"),
    ("autohand-code", "~/.autohand/skills"),
    ("augment", "~/.augment/skills"),
    ("bob", "~/.bob/skills"),
    ("claude-code", "~/.claude/skills"),
    ("openclaw", "~/.openclaw/skills"),
    ("cline", "~/.agents/skills"),
    ("codearts-agent", "~/.codeartsdoer/skills"),
    ("codebuddy", "~/.codebuddy/skills"),
    ("codemaker", "~/.codemaker/skills"),
    ("codestudio", "~/.codestudio/skills"),
    ("codex", "~/.codex/skills"),
    ("command-code", "~/.commandcode/skills"),
    ("continue", "~/.continue/skills"),
    ("cortex", "~/.snowflake/cortex/skills"),
    ("crush", "~/.config/crush/skills"),
    ("cursor", "~/.cursor/skills"),
    ("deepagents", "~/.deepagents/agent/skills"),
    ("devin", "~/.config/devin/skills"),
    ("dexto", "~/.agents/skills"),
    ("droid", "~/.factory/skills"),
    ("firebender", "~/.firebender/skills"),
    ("forgecode", "~/.forge/skills"),
    ("fx", "~/.fx/skills"),
    ("gemini-cli", "~/.gemini/skills"),
    ("github-copilot", "~/.copilot/skills"),
    ("goose", "~/.config/goose/skills"),
    ("grok", "~/.grok/skills"),
    ("hermes-agent", "~/.hermes/skills"),
    ("inference-sh", "~/.inferencesh/skills"),
    ("jazz", "~/.jazz/skills"),
    ("junie", "~/.junie/skills"),
    ("iflow-cli", "~/.iflow/skills"),
    ("kilo", "~/.kilo/skills"),
    ("kimchi", "~/.config/kimchi/harness/skills"),
    ("kimi-code-cli", "~/.agents/skills"),
    ("kiro-cli", "~/.kiro/skills"),
    ("kode", "~/.kode/skills"),
    ("lingma", "~/.lingma/skills"),
    ("loaf", "~/.agents/skills"),
    ("mcpjam", "~/.mcpjam/skills"),
    ("minimax-code", "~/.minimax/skills"),
    ("mistral-vibe", "~/.vibe/skills"),
    ("moxby", "~/.moxby/skills"),
    ("mux", "~/.mux/skills"),
    ("opencode", "~/.config/opencode/skills"),
    ("openhands", "~/.openhands/skills"),
    ("ona", "~/.ona/skills"),
    ("pi", "~/.pi/agent/skills"),
    ("posit-assistant", "~/.posit/assistant/skills"),
    ("qoder", "~/.qoder/skills"),
    ("qoder-cn", "~/.qoder-cn/skills"),
    ("qwen-code", "~/.qwen/skills"),
    ("replit", "~/.config/agents/skills"),
    ("reasonix", "~/.reasonix/skills"),
    ("rovodev", "~/.rovodev/skills"),
    ("roo", "~/.roo/skills"),
    ("sarvam-code", "~/.agents/skills"),
    ("tabnine-cli", "~/.tabnine/agent/skills"),
    ("terramind", "~/.terramind/skills"),
    ("tinycloud", "~/.tinycloud/skills"),
    ("trae", "~/.trae/skills"),
    ("trae-cn", "~/.trae-cn/skills"),
    ("warp", "~/.agents/skills"),
    ("windsurf", "~/.codeium/windsurf/skills"),
    ("zed", "~/.agents/skills"),
    ("zcode", "~/.zcode/skills"),
    ("zencoder", "~/.zencoder/skills"),
    ("zenflow", "~/.zencoder/skills"),
    ("neovate", "~/.neovate/skills"),
    ("pochi", "~/.pochi/skills"),
    ("adal", "~/.adal/skills"),
    ("universal", "~/.config/agents/skills"),
  ].map { AgentDefinition(id: $0.0, skillDirectory: $0.1) }
}
