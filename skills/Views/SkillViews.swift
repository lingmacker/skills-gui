import SwiftUI

struct DiscoveryListView: View {
  @Environment(AppModel.self) private var model
  @FocusState.Binding var searchFocused: Bool
  let onRepository: () -> Void

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 0) {
      VStack(spacing: 8) {
        HStack(spacing: 8) {
          TextField("discover.search.prompt", text: $model.searchQuery)
            .textFieldStyle(.roundedBorder)
            .focused($searchFocused)
          if model.isSearching {
            ProgressView()
              .controlSize(.small)
          }
        }

        Button(action: onRepository) {
          HStack(spacing: 10) {
            Image(systemName: "shippingbox")
              .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
              Text("repository.open")
                .font(.body.weight(.medium))
                .foregroundStyle(.primary)
              Text("repository.description")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
            Spacer()
          }
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(model.isBusy)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider()

      List(selection: $model.selectedSearchID) {
        Section {
          if model.visibleSkills.isEmpty {
            Group {
              if model.isSearching || model.isInitialDirectoryLoad {
                ProgressView(
                  model.isSearching
                    ? LocalizedStringKey("discover.searching")
                    : LocalizedStringKey("discover.loading")
                )
              } else if model.isShowingDirectory {
                ContentUnavailableView(
                  "discover.start.title",
                  systemImage: "square.stack.3d.up",
                  description: Text("discover.start.description")
                )
              } else {
                ContentUnavailableView.search(text: model.searchQuery)
              }
            }
            .frame(maxWidth: .infinity, minHeight: 180)
          } else {
            ForEach(model.visibleSkills) { skill in
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                  Text(skill.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                  Text(skill.source)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                }
                Spacer()
                Label {
                  Text(skill.installs, format: .number)
                } icon: {
                  Image(systemName: "arrow.down.circle")
                }
                .font(.caption)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
                .frame(minWidth: 68, alignment: .trailing)
              }
              .contentShape(Rectangle())
              .alignmentGuide(.listRowSeparatorLeading) { _ in 0 }
              .tag(skill.id)
              .task {
                if model.isShowingDirectory, skill.id == model.visibleSkills.last?.id {
                  await model.loadMoreDiscovery()
                }
              }
            }

            if model.isLoadingMoreSkills, !model.directorySkills.isEmpty {
              HStack {
                Spacer()
                ProgressView()
                  .controlSize(.small)
                Spacer()
              }
              .accessibilityLabel(Text("discover.loading"))
            }
          }
        } header: {
          HStack {
            Text("discover.start.title")
            Spacer()
            Button {
              Task { await model.refreshDiscovery() }
            } label: {
              Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("discover.refresh")
            .accessibilityLabel("discover.refresh")
            .disabled(model.isSearching || model.isLoadingMoreSkills)
          }
        }
      }
      .listStyle(.inset)
    }
    .task(id: model.searchQuery) { await model.search() }
  }
}

struct InstalledListView: View {
  @Environment(AppModel.self) private var model
  let onUpdateAll: () -> Void
  let onBatchLink: () -> Void

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 0) {
      if !model.installedSkills.isEmpty {
        VStack(spacing: 8) {
          Button(action: onUpdateAll) {
            HStack(spacing: 10) {
              Image(systemName: "arrow.triangle.2.circlepath")
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text("installed.update_all")
                  .font(.body.weight(.medium))
                  .foregroundStyle(.primary)
                Text("installed.update_all.message")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer()
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(model.isBusy)

          Button(action: onBatchLink) {
            HStack(spacing: 10) {
              Image(systemName: "link.badge.plus")
                .foregroundStyle(.secondary)
              VStack(alignment: .leading, spacing: 2) {
                Text("link.batch.action")
                  .font(.body.weight(.medium))
                  .foregroundStyle(.primary)
                Text("link.batch.description")
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
              }
              Spacer()
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .disabled(
            model.isBusy || !model.installedSkills.contains { $0.installSource != nil })
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)

        Divider()
      }

      List(selection: $model.selectedInstalledID) {

        Section {
          if model.installedSkills.isEmpty {
            ContentUnavailableView(
              "installed.empty",
              systemImage: "square.stack.3d.up",
              description: Text("installed.empty.description")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
          } else {
            ForEach(model.installedSkills) { skill in
              HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                  Text(skill.name)
                    .font(.body.weight(.medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                  Group {
                    if let source = skill.source {
                      Text(source)
                    } else {
                      Text("source.local")
                    }
                  }
                  .font(.caption)
                  .foregroundStyle(.secondary)
                  .lineLimit(1)
                  .truncationMode(.middle)
                }
                Spacer()
                HStack(spacing: 0) {
                  Text(skill.agents.count, format: .number)
                    .monospacedDigit()
                  Text("installed.agents.suffix")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
              }
              .contentShape(Rectangle())
              .tag(skill.id)
            }
          }
        } header: {
          HStack {
            Text("installed.skills")
            Spacer()
            HStack(spacing: 0) {
              Text(model.installedSkills.count, format: .number)
                .monospacedDigit()
              Text("installed.count.suffix")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
          }
        }
      }
      .listStyle(.inset)
      .refreshable { await model.reloadInstalled() }
    }
  }
}

struct RepositoryInstallView: View {
  @Environment(AppModel.self) private var model
  let onClose: () -> Void
  @State private var source = ""
  @State private var repositorySkills: [String] = []
  @State private var selectedSkillNames: Set<String> = []
  @State private var isLoadingSkills = false
  @FocusState private var sourceFieldFocused: Bool

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 20) {
        VStack(alignment: .leading, spacing: 5) {
          Text(
            LocalizedStringKey(
              repositorySkills.isEmpty ? "repository.title" : "repository.skills.title")
          )
          .font(.title2.weight(.semibold))
          Text(
            LocalizedStringKey(
              repositorySkills.isEmpty
                ? "repository.description" : "repository.skills.description")
          )
          .foregroundStyle(.secondary)
        }

        if repositorySkills.isEmpty {
          VStack(alignment: .leading, spacing: 7) {
            Text("repository.source.label")
              .font(.headline)
            TextField("repository.source.placeholder", text: $source)
              .textFieldStyle(.roundedBorder)
              .focused($sourceFieldFocused)
            Text("repository.source.help")
              .font(.caption)
              .foregroundStyle(.secondary)
            if !trimmedSource.isEmpty, !sourceIsValid {
              Label("repository.source.invalid", systemImage: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.red)
            }
          }

          VStack(alignment: .leading, spacing: 10) {
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
              ),
              minimumColumnWidth: 220
            )
          }
          .frame(maxHeight: .infinity, alignment: .top)

          VStack(alignment: .leading, spacing: 7) {
            Picker("install.mode", selection: $model.copyInstallation) {
              Text("install.mode.symlink").tag(false)
              Text("install.mode.copy").tag(true)
            }
            .pickerStyle(.segmented)

            Text(model.copyInstallation ? "install.mode.copy.help" : "install.mode.symlink.help")
              .font(.caption)
              .foregroundStyle(.secondary)
          }
        } else {
          VStack(alignment: .leading, spacing: 10) {
            HStack {
              Text("repository.skills.label")
                .font(.headline)
              Spacer()
              HStack(spacing: 4) {
                Text("install.agents.selected")
                Text(selectedSkillNames.count, format: .number)
              }
              .foregroundStyle(.secondary)
              Button("action.select_all") {
                selectedSkillNames = Set(repositorySkills)
              }
              Button("action.clear") {
                selectedSkillNames.removeAll()
              }
            }

            ScrollView {
              LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)],
                alignment: .leading,
                spacing: 8
              ) {
                ForEach(repositorySkills, id: \.self) { skillName in
                  Toggle(
                    skillName,
                    isOn: Binding(
                      get: { selectedSkillNames.contains(skillName) },
                      set: { isSelected in
                        if isSelected {
                          selectedSkillNames.insert(skillName)
                        } else {
                          selectedSkillNames.remove(skillName)
                        }
                      }
                    )
                  )
                  .toggleStyle(.checkbox)
                  .frame(maxWidth: .infinity, alignment: .leading)
                }
              }
              .padding(.vertical, 4)
            }
          }
          .frame(maxHeight: .infinity, alignment: .top)
        }
      }
      .padding(24)

      Divider()

      HStack {
        if !repositorySkills.isEmpty {
          Button("action.back") {
            repositorySkills = []
            selectedSkillNames = []
          }
        }
        Spacer()
        Button("action.cancel", role: .cancel, action: onClose)
          .keyboardShortcut(.cancelAction)
        if repositorySkills.isEmpty {
          Button {
            loadSkills()
          } label: {
            if isLoadingSkills {
              ProgressView()
                .controlSize(.small)
              Text("repository.skills.loading")
            } else {
              Text("repository.review.action")
            }
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(
            !sourceIsValid || model.selectedAgents.isEmpty || model.isBusy || isLoadingSkills)
        } else {
          Button("repository.install.action") {
            Task {
              await model.installRepository(
                source: trimmedSource,
                skillNames: repositorySkills.filter(selectedSkillNames.contains)
              )
            }
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
          .disabled(selectedSkillNames.isEmpty || model.isBusy)
        }
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
    .frame(width: 560, height: 600)
    .onAppear { sourceFieldFocused = true }
  }

  private var trimmedSource: String {
    source.trimmingCharacters(in: .whitespacesAndNewlines)
  }

  private var sourceIsValid: Bool {
    AppModel.isValidGitHubRepositorySource(trimmedSource)
  }

  private func loadSkills() {
    isLoadingSkills = true
    Task {
      defer { isLoadingSkills = false }
      guard let skills = await model.loadRepositorySkills(source: trimmedSource) else { return }
      repositorySkills = skills
      selectedSkillNames = Set(skills)
    }
  }
}

struct LinkSkillView: View {
  @Environment(AppModel.self) private var model
  let skills: [InstalledSkill]
  let onClose: () -> Void
  @State private var selectedSkillIDs: Set<String>
  @State private var skillFilter = ""
  @State private var selectedAgents: Set<String> = []

  init(skills: [InstalledSkill], onClose: @escaping () -> Void) {
    self.skills = skills
    self.onClose = onClose
    _selectedSkillIDs = State(initialValue: skills.count == 1 ? Set(skills.map(\.id)) : [])
  }

  var body: some View {
    VStack(spacing: 0) {
      VStack(alignment: .leading, spacing: 18) {
        VStack(alignment: .leading, spacing: 5) {
          if isBatch {
            Text("link.batch.title")
              .font(.title2.weight(.semibold))
            Text("link.batch.description")
              .foregroundStyle(.secondary)
          } else if let skill = skills.first {
            Text("link.title")
              .font(.title2.weight(.semibold))
            Text(skill.name)
              .font(.headline)
            Text("link.description")
              .foregroundStyle(.secondary)
          }
        }

        if isBatch {
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Text("link.skills")
                .font(.headline)
              Spacer()
              HStack(spacing: 4) {
                Text("install.agents.selected")
                Text(selectedSkillIDs.count, format: .number)
              }
              .foregroundStyle(.secondary)
              Button("action.select_all") {
                selectedSkillIDs.formUnion(filteredSkills.map(\.id))
              }
              Button("action.clear") { selectedSkillIDs.removeAll() }
            }

            TextField("link.skill.search", text: $skillFilter)
              .textFieldStyle(.roundedBorder)

            Group {
              if filteredSkills.isEmpty {
                ContentUnavailableView("link.skills.empty", systemImage: "magnifyingglass")
              } else {
                ScrollView {
                  LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 220), alignment: .leading)],
                    alignment: .leading,
                    spacing: 8
                  ) {
                    ForEach(filteredSkills) { skill in
                      Toggle(
                        isOn: Binding(
                          get: { selectedSkillIDs.contains(skill.id) },
                          set: { isSelected in
                            if isSelected {
                              selectedSkillIDs.insert(skill.id)
                            } else {
                              selectedSkillIDs.remove(skill.id)
                            }
                          }
                        )
                      ) {
                        VStack(alignment: .leading, spacing: 1) {
                          Text(skill.name)
                            .lineLimit(1)
                          Text(skill.installSource ?? "")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        }
                      }
                      .toggleStyle(.checkbox)
                      .frame(maxWidth: .infinity, alignment: .leading)
                    }
                  }
                  .padding(.vertical, 4)
                }
              }
            }
            .frame(height: 150)
          }
        } else if let skill = skills.first, !skill.agents.isEmpty {
          LabeledContent("link.current_agents") {
            Text(skill.agents.joined(separator: ", "))
              .multilineTextAlignment(.trailing)
          }
        }

        VStack(alignment: .leading, spacing: 10) {
          HStack {
            Text("link.target_agents")
              .font(.headline)
            Spacer()
            HStack(spacing: 4) {
              Text("install.agents.selected")
              Text(selectedAgents.count, format: .number)
            }
            .foregroundStyle(.secondary)
          }
          AgentPickerView(selectedAgents: $selectedAgents, minimumColumnWidth: 220)
        }
        .frame(maxHeight: .infinity, alignment: .top)
      }
      .padding(24)

      Divider()

      HStack {
        Spacer()
        Button("action.cancel", role: .cancel, action: onClose)
          .keyboardShortcut(.cancelAction)
        Button("link.action") {
          Task { await model.link(selectedSkills, to: selectedAgents) }
        }
        .buttonStyle(.borderedProminent)
        .keyboardShortcut(.defaultAction)
        .disabled(selectedSkills.isEmpty || selectedAgents.isEmpty || model.isBusy)
      }
      .padding(.horizontal, 24)
      .padding(.vertical, 16)
    }
    .frame(width: 560, height: isBatch ? 640 : 520)
  }

  private var isBatch: Bool { skills.count > 1 }

  private var filteredSkills: [InstalledSkill] {
    let query = skillFilter.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return skills }
    return skills.filter {
      $0.name.localizedCaseInsensitiveContains(query)
        || $0.installSource?.localizedCaseInsensitiveContains(query) == true
    }
  }

  private var selectedSkills: [InstalledSkill] {
    skills.filter { selectedSkillIDs.contains($0.id) }
  }
}

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

private struct AgentPickerView: View {
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
