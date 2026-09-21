import SwiftUI

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

