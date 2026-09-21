import SwiftUI

struct SearchSkillDetailView: View {
  @Environment(AppModel.self) private var model
  let skill: SearchSkill
  @State private var confirmsInstall = false

  var body: some View {
    @Bindable var model = model

    VStack(alignment: .leading, spacing: 16) {
      Grid(alignment: .leadingFirstTextBaseline, horizontalSpacing: 18, verticalSpacing: 6) {
        GridRow {
          Text("skill.identifier").foregroundStyle(.secondary)
          Text(skill.installName).textSelection(.enabled)
        }
        GridRow {
          Text("skill.installs").foregroundStyle(.secondary)
          Text(skill.installs, format: .number)
        }
        GridRow {
          Text("skill.source").foregroundStyle(.secondary)
          Text(skill.source).textSelection(.enabled)
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Text("install.agents")
            .font(.headline)
          Spacer()
          HStack(spacing: 4) {
            Text("install.agents.selected")
            Text(model.selectedAgents.count, format: .number)
          }
          .foregroundStyle(.secondary)
        }
        AgentPickerView(
          selectedAgents: Binding(
            get: { model.selectedAgents },
            set: { model.setSelectedAgents($0) }
          )
        )
      }
      .frame(maxHeight: .infinity, alignment: .top)

      Picker("install.mode", selection: $model.copyInstallation) {
        Text("install.mode.symlink").tag(false)
        Text("install.mode.copy").tag(true)
      }
      .pickerStyle(.segmented)

      Text(model.copyInstallation ? "install.mode.copy.help" : "install.mode.symlink.help")
        .font(.caption)
        .foregroundStyle(.secondary)

      Button {
        confirmsInstall = true
      } label: {
        Label("action.install", systemImage: "square.and.arrow.down")
          .frame(maxWidth: .infinity)
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.large)
      .disabled(model.selectedAgents.isEmpty || model.isBusy)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
    .confirmationDialog(
      "install.confirm.title",
      isPresented: $confirmsInstall,
      titleVisibility: .visible
    ) {
      Button("action.install") {
        Task { await model.installSelected() }
      }
      Button("action.cancel", role: .cancel) {}
    } message: {
      Text(model.copyInstallation ? "install.confirm.copy" : "install.confirm.symlink")
    }
  }
}

struct InstalledSkillDetailView: View {
  @Environment(AppModel.self) private var model
  let skill: InstalledSkill
  let onLink: () -> Void
  @State private var confirmsRemoval = false
  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      LabeledContent("skill.path") {
        Text(skill.path)
          .textSelection(.enabled)
          .multilineTextAlignment(.trailing)
      }
      LabeledContent("skill.source_type", value: skill.sourceType ?? "—")
      LabeledContent("skill.source", value: skill.installSource ?? "—")

      VStack(alignment: .leading, spacing: 8) {
        Text("installed.available_to")
          .font(.headline)
        ForEach(skill.agents, id: \.self) { agent in
          Label(agent, systemImage: "checkmark.circle.fill")
            .foregroundStyle(.secondary)
        }
      }

      Divider()

      HStack {
        Button {
          Task { await model.update(skillNames: [skill.name]) }
        } label: {
          Label("action.update", systemImage: "arrow.triangle.2.circlepath")
        }
        .buttonStyle(.borderedProminent)
        .disabled(model.isBusy)

        Button(action: onLink) {
          Label("link.action", systemImage: "link.badge.plus")
        }
        .disabled(model.isBusy || skill.installSource == nil)
        .help(
          LocalizedStringKey(
            skill.installSource == nil ? "link.source_unavailable" : "link.open.help"))

        Button(role: .destructive) {
          confirmsRemoval = true
        } label: {
          Label("action.remove", systemImage: "trash")
        }
        .disabled(model.isBusy)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(24)
    .confirmationDialog(
      "remove.confirm.title",
      isPresented: $confirmsRemoval,
      titleVisibility: .visible
    ) {
      Button("action.remove", role: .destructive) {
        Task { await model.removeSelected() }
      }
      Button("action.cancel", role: .cancel) {}
    } message: {
      Text("remove.confirm.message")
    }
  }
}

