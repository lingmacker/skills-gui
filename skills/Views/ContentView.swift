import SwiftUI

struct ContentView: View {
  @Environment(AppModel.self) private var model

  var body: some View {
    Group {
      switch model.runtimeState {
      case .checking:
        ProgressView("environment.checking")
          .controlSize(.large)
      case .missing:
        RuntimeGateView()
      case .available:
        ManagerView()
      }
    }
    .task {
      if model.runtimeState == .checking {
        await model.start()
      }
    }
  }
}

private struct ManagerView: View {
  @Environment(AppModel.self) private var model
  @State private var confirmsUpdateAll = false
  @FocusState private var discoverySearchFocused: Bool
  @State private var showsRepositoryInstaller = false
  @State private var linkTargetSkills: [InstalledSkill] = []

  var body: some View {
    VStack(spacing: 0) {
      HStack(spacing: 12) {
        ForEach(ManagerSection.allCases) { section in
          let isSelected = model.selectedSection == section
          Button {
            discoverySearchFocused = false
            model.selectedSection = section
          } label: {
            VStack(spacing: 3) {
              Image(systemName: section.systemImage)
                .font(.system(size: 21, weight: .regular))
                .frame(height: 23)
              Text(section.titleKey)
                .font(.caption.weight(isSelected ? .semibold : .regular))
            }
            .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
            .frame(width: 68, height: 48)
            .background {
              if isSelected {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                  .fill(.quaternary)
              }
            }
            .contentShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityValue(isSelected ? Text("navigation.selected") : Text(""))
        }
      }
      .padding(.vertical, 8)
      .frame(maxWidth: .infinity)
      .accessibilityElement(children: .contain)
      .accessibilityLabel("navigation.section")

      Divider()

      Group {
        switch model.selectedSection {
        case .discover:
          HSplitView {
            DiscoveryListView(
              searchFocused: $discoverySearchFocused,
              onRepository: {
                discoverySearchFocused = false
                showsRepositoryInstaller = true
              }
            )
            .frame(minWidth: 300, idealWidth: 360, maxWidth: 440)

            Group {
              if let skill = model.selectedSearchSkill {
                SearchSkillDetailView(skill: skill)
              } else {
                ContentUnavailableView(
                  "discover.empty.selection",
                  systemImage: "magnifyingglass")
              }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
          }
        case .installed:
          HSplitView {
            InstalledListView(
              onUpdateAll: { confirmsUpdateAll = true },
              onBatchLink: {
                linkTargetSkills = model.installedSkills.filter { $0.installSource != nil }
              }
            )
            .frame(minWidth: 300, idealWidth: 360, maxWidth: 440)

            Group {
              if let skill = model.selectedInstalledSkill {
                InstalledSkillDetailView(skill: skill) {
                  linkTargetSkills = [skill]
                }
              } else {
                ContentUnavailableView(
                  "installed.empty",
                  systemImage: "square.stack.3d.up")
              }
            }
            .frame(minWidth: 400, maxWidth: .infinity, maxHeight: .infinity)
          }
        case .settings:
          SettingsView()
            .frame(maxWidth: 720, maxHeight: .infinity)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .onChange(of: model.mutationProgress != nil) { _, hasProgress in
      if hasProgress {
        showsRepositoryInstaller = false
        linkTargetSkills = []
      }
    }
    .confirmationDialog(
      "installed.update_all.confirm",
      isPresented: $confirmsUpdateAll,
      titleVisibility: .visible
    ) {
      Button("installed.update_all") {
        Task { await model.update(skillNames: []) }
      }
      Button("action.cancel", role: .cancel) {}
    } message: {
      Text("installed.update_all.message")
    }
    .alert(
      "error.title",
      isPresented: Binding(
        get: { model.errorKey != nil },
        set: { if !$0 { model.dismissError() } }
      )
    ) {
      Button("action.ok") { model.dismissError() }
    } message: {
      Text(LocalizedStringKey(model.errorKey ?? ""))
    }
    .sheet(isPresented: presentsSheet) {
      if showsRepositoryInstaller {
        RepositoryInstallView {
          showsRepositoryInstaller = false
        }
      } else if !linkTargetSkills.isEmpty {
        LinkSkillView(skills: linkTargetSkills) {
          linkTargetSkills = []
        }
      } else {
        SkillMutationProgressView()
      }
    }
  }

  private var presentsSheet: Binding<Bool> {
    Binding(
      get: {
        showsRepositoryInstaller || !linkTargetSkills.isEmpty || model.mutationProgress != nil
      },
      set: { isPresented in
        guard !isPresented else { return }
        showsRepositoryInstaller = false
        linkTargetSkills = []
        model.dismissMutationProgress()
      }
    )
  }
}
