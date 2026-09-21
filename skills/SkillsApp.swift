import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

@main
struct SkillsApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
  @State private var model = AppModel()
  @AppStorage("languageOverride") private var languageOverride = "system"

  private var locale: Locale {
    languageOverride == "system" ? .autoupdatingCurrent : Locale(identifier: languageOverride)
  }

  var body: some Scene {
    WindowGroup {
      ContentView()
        .environment(model)
        .environment(\.locale, locale)
        .frame(minWidth: 900, minHeight: 620)
    }
    .defaultSize(width: 1040, height: 720)

    Settings {
      SettingsView()
        .environment(model)
        .environment(\.locale, locale)
        .frame(width: 620, height: 520)
    }
  }
}
