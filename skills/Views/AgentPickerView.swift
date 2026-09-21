import SwiftUI

struct AgentPickerView: View {
  @Environment(AppModel.self) private var model
  @Binding var selectedAgents: Set<String>
  var minimumColumnWidth: CGFloat = 260

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 10) {
      HStack {
        TextField("install.agent.search", text: $model.agentFilter)
          .textFieldStyle(.roundedBorder)
        Button("action.select_all") {
          selectedAgents.formUnion(filteredAgents.map(\.id))
        }
        Button("action.clear") { selectedAgents.removeAll() }
      }

      ScrollView {
        LazyVGrid(
          columns: [GridItem(.adaptive(minimum: minimumColumnWidth), alignment: .leading)],
          spacing: 10
        ) {
          ForEach(filteredAgents) { agent in
            Toggle(
              isOn: Binding(
                get: { selectedAgents.contains(agent.id) },
                set: { isSelected in
                  if isSelected {
                    selectedAgents.insert(agent.id)
                  } else {
                    selectedAgents.remove(agent.id)
                  }
                }
              )
            ) {
              VStack(alignment: .leading, spacing: 1) {
                Text(agent.id)
                  .lineLimit(1)
                Text(agent.skillDirectory)
                  .font(.system(.caption, design: .monospaced))
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.middle)
              }
            }
            .toggleStyle(AgentCheckboxToggleStyle())
            .help(agent.skillDirectory)
          }
        }
        .padding(.vertical, 4)
      }
      .frame(minHeight: 130, maxHeight: .infinity)
    }
    .frame(maxHeight: .infinity, alignment: .top)
  }

  private var filteredAgents: [AgentDefinition] {
    guard !model.agentFilter.isEmpty else { return AgentCatalog.global }
    return AgentCatalog.global.filter {
      $0.id.localizedCaseInsensitiveContains(model.agentFilter)
        || $0.skillDirectory.localizedCaseInsensitiveContains(model.agentFilter)
    }
  }
}

private struct AgentCheckboxToggleStyle: ToggleStyle {
  func makeBody(configuration: Configuration) -> some View {
    Button {
      configuration.isOn.toggle()
    } label: {
      HStack(alignment: .center, spacing: 10) {
        Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
          .font(.system(size: 22))
          .foregroundStyle(configuration.isOn ? Color.accentColor : Color.gray.opacity(0.65))
          .frame(width: 24, height: 24)
          .accessibilityHidden(true)

        configuration.label
      }
      .frame(maxWidth: .infinity, minHeight: 38, alignment: .leading)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}
