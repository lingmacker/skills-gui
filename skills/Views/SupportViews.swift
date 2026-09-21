import SwiftUI

struct RuntimeGateView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    ContentUnavailableView {
      Label("environment.missing.title", systemImage: "wrench.and.screwdriver")
    } description: {
      Text("environment.missing.description")
    } actions: {
      HStack {
        Button("environment.retry") {
          Task { await model.start() }
        }
        .buttonStyle(.borderedProminent)

        Link(
          "environment.install_bun", destination: URL(string: "https://bun.com/docs/installation")!)
        Link(
          "environment.install_node", destination: URL(string: "https://nodejs.org/en/download")!)
      }
    }
  }
}

struct SkillMutationProgressView: View {
  @Environment(AppModel.self) private var model
  @State private var showsDetails = true

  var body: some View {
    if let progress = model.mutationProgress {
      VStack(alignment: .leading, spacing: 20) {
        HStack(alignment: .top, spacing: 14) {
          Group {
            switch progress.phase {
            case .running, .refreshing:
              ProgressView()
                .controlSize(.small)
            case .succeeded:
              Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            case .failed:
              Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            }
          }
          .font(.title2)
          .frame(width: 24, height: 24)

          VStack(alignment: .leading, spacing: 5) {
            Text(titleKey(for: progress))
              .font(.headline)
            Group {
              if case .update = progress.action, progress.skillName.isEmpty {
                Text("installed.update_all")
              } else {
                Text(progress.skillName)
              }
            }
            .font(.title2.weight(.semibold))
            .textSelection(.enabled)
            Text(statusKey(for: progress))
              .foregroundStyle(.secondary)
          }
        }

        if progress.phase.isRunning {
          ProgressView()
            .progressViewStyle(.linear)
        }

        VStack(alignment: .leading, spacing: 6) {
          Text("skill.progress.command")
            .font(.caption)
            .foregroundStyle(.secondary)
          ScrollView(.horizontal) {
            Text(progress.command)
              .font(.system(.callout, design: .monospaced))
              .textSelection(.enabled)
          }
        }

        if !progress.log.isEmpty {
          DisclosureGroup("skill.progress.details", isExpanded: $showsDetails) {
            ScrollView([.horizontal, .vertical]) {
              Text(progress.log)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 180)
          }
        }

        if !progress.phase.isRunning {
          HStack {
            Spacer()
            Button("action.done") {
              model.dismissMutationProgress()
            }
            .keyboardShortcut(.defaultAction)
          }
        }
      }
      .padding(24)
      .frame(minWidth: 500, minHeight: 240)
      .interactiveDismissDisabled(progress.phase.isRunning)
    }
  }

  private func titleKey(for progress: SkillMutationProgress) -> LocalizedStringKey {
    switch progress.action {
    case .install: "skill.progress.install.title"
    case .installRepository: "repository.progress.title"
    case .update: "skill.progress.update.title"
    case .link: "skill.progress.link.title"
    case .remove: "skill.progress.remove.title"
    }
  }

  private func statusKey(for progress: SkillMutationProgress) -> LocalizedStringKey {
    switch progress.phase {
    case .running:
      switch progress.action {
      case .install: "skill.progress.install.running"
      case .installRepository: "repository.progress.running"
      case .update: "skill.progress.update.running"
      case .link: "skill.progress.link.running"
      case .remove: "skill.progress.remove.running"
      }
    case .refreshing:
      "skill.progress.refreshing"
    case .succeeded:
      switch progress.action {
      case .install: "skill.progress.install.succeeded"
      case .installRepository: "repository.progress.succeeded"
      case .update: "skill.progress.update.succeeded"
      case .link: "skill.progress.link.succeeded"
      case .remove: "skill.progress.remove.succeeded"
      }
    case .failed:
      if let errorKey = progress.errorKey {
        LocalizedStringKey(errorKey)
      } else {
        switch progress.action {
        case .install: "skill.progress.install.failed"
        case .installRepository: "repository.progress.failed"
        case .update: "skill.progress.update.failed"
        case .link: "skill.progress.link.failed"
        case .remove: "skill.progress.remove.failed"
        }
      }
    }
  }
}

public struct SettingsView: View {
  @Environment(AppModel.self) private var model
  @AppStorage("languageOverride") private var languageOverride = "system"

  public init() {}

  public var body: some View {
    @Bindable var model = model

    Form {
      Section("settings.general") {
        Picker("settings.language", selection: $languageOverride) {
          Text("settings.language.system").tag("system")
          Text("settings.language.english").tag("en")
          Text("settings.language.chinese").tag("zh-Hans")
        }
      }

      Section("settings.environment") {
        switch model.runtimeState {
        case .available(let runtime):
          Picker(
            "settings.runtime",
            selection: Binding(
              get: { runtime },
              set: { model.selectRuntime($0) }
            )
          ) {
            ForEach(model.availableRuntimes, id: \.self) { runtime in
              Text(runtime.displayName).tag(runtime)
            }
          }
        case .checking:
          LabeledContent("settings.runtime") {
            ProgressView().controlSize(.small)
          }
        case .missing:
          LabeledContent("settings.runtime") {
            Text("settings.runtime.missing")
              .foregroundStyle(.secondary)
          }
        }

        HStack(spacing: 16) {
          VStack(alignment: .leading, spacing: 3) {
            Text("environment.retry")
              .font(.body.weight(.medium))
            Text("settings.runtime.recheck")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
          Spacer()
          if model.isCheckingRuntime {
            ProgressView()
              .controlSize(.small)
          }
          Button("environment.retry") {
            Task { await model.start() }
          }
          .disabled(model.isCheckingRuntime)
        }
      }

      Section("settings.cli") {
        LabeledContent("settings.cli_version") {
          HStack(spacing: 4) {
            Text("skills@")
              .foregroundStyle(.secondary)
            TextField(
              "settings.cli_version",
              text: $model.cliVersion,
              prompt: Text("settings.cli_version.placeholder")
            )
            .labelsHidden()
            .textFieldStyle(.roundedBorder)
            .frame(width: 120)
          }
        }
        LabeledContent("settings.scope") {
          Text("settings.scope.global")
        }
      }
    }
    .formStyle(.grouped)
  }
}
