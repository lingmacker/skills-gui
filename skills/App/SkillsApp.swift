import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    true
  }
}

private final class TitlebarSeparatorView: NSView {
  func hideSeparator() {
    window?.titlebarSeparatorStyle = .none
  }

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    hideSeparator()
    DispatchQueue.main.async { [weak self] in
      self?.hideSeparator()
    }
  }
}

private struct HideTitlebarSeparator: NSViewRepresentable {
  func makeNSView(context: Context) -> TitlebarSeparatorView {
    TitlebarSeparatorView()
  }

  func updateNSView(_ view: TitlebarSeparatorView, context: Context) {
    view.hideSeparator()
    DispatchQueue.main.async { [weak view] in
      view?.hideSeparator()
    }
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
        .background(HideTitlebarSeparator())
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
