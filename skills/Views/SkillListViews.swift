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
  @State private var searchQuery = ""

  private var filteredSkills: [InstalledSkill] {
    let query = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !query.isEmpty else { return model.installedSkills }
    return model.installedSkills.filter { skill in
      [skill.name, skill.source, skill.sourceUrl]
        .compactMap { $0 }
        .contains { $0.localizedCaseInsensitiveContains(query) }
    }
  }

  var body: some View {
    @Bindable var model = model

    VStack(spacing: 0) {
      VStack(spacing: 8) {
        TextField("installed.search.prompt", text: $searchQuery)
          .textFieldStyle(.roundedBorder)

        if !model.installedSkills.isEmpty {
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
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 10)

      Divider()

      List(selection: $model.selectedInstalledID) {
        Section {
          if model.installedSkills.isEmpty {
            ContentUnavailableView(
              "installed.empty",
              systemImage: "square.stack.3d.up",
              description: Text("installed.empty.description")
            )
            .frame(maxWidth: .infinity, minHeight: 220)
          } else if filteredSkills.isEmpty {
            ContentUnavailableView.search(text: searchQuery)
              .frame(maxWidth: .infinity, minHeight: 180)
          } else {
            ForEach(filteredSkills) { skill in
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

