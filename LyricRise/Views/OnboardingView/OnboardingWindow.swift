//
//  OnboardingWindow.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 01/09/23.
//

import SwiftUI
import LaunchAtLogin

struct OnboardingWindow: View {
    @Environment(ViewModel.self) private var viewModel
    @Environment(\.openURL) private var openURL

    private enum Page: CaseIterable {
        case player, general, karaoke, shortcuts

        var title: LocalizedStringKey {
            switch self {
            case .player: "Initial Setup"
            case .general: "Main Settings"
            case .karaoke: "Karaoke Window"
            case .shortcuts: "Keyboard Shortcuts"
            }
        }

        var icon: String {
            switch self {
            case .player: "play.circle"
            case .general: "gearshape"
            case .karaoke: "music.mic"
            case .shortcuts: "keyboard"
            }
        }
    }

    @State private var selection: Page? = .player

    var body: some View {
        @Bindable var viewModel = viewModel
        NavigationSplitView {
            List(Page.allCases, id: \.self, selection: $selection) { page in
                Label(page.title, systemImage: page.icon)
                    .tag(page)
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 175, ideal: 205, max: 245)
        } detail: {
            let page = selection ?? .player
            Group {
                switch page {
                case .player: MainSettingsView(onDone: { selection = .general })
                case .general:
                    Form {
                        Section {
                            LaunchAtLogin.Toggle(String(localized: "Launch at Login"))
                                .disabled(!viewModel.userDefaultStorage.hasOnboarded)
                            Toggle("Show Song Details in Menubar", isOn: $viewModel.userDefaultStorage.showSongDetailsInMenubar)
                        }
                        Section {
                            switch viewModel.updaterService.status {
                            case .idle: EmptyView()
                            case .checking: ProgressView("Checking for updates…")
                            case .upToDate: Text("LyricRise is up to date.")
                            case .unavailable: Text("Could not check for updates.").foregroundStyle(.secondary)
                            case let .available(version, url):
                                LabeledContent("LyricRise \(version) is available.") {
                                    Link("Download Update", destination: url)
                                }
                            }
                            Button("Check for Updates") {
                                Task { await viewModel.updaterService.checkForUpdates() }
                            }
                            .disabled(viewModel.updaterService.status == .checking)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Section {
                            Button("Buy the Original Developer a Beer (Thank You)!") {
                                openURL(URL(string: "https://buymeacoffee.com/aviwadhwalyricfever")!)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                            Button("Support the Improved Version Developer with a Coffee ☕️ (Thank You 🙏)") {
                                openURL(URL(string: "https://buymeacoffee.com/navel7")!)
                            }
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        Section {
                            Text("This app is a fork of [Lyric Fever](https://github.com/aviwad/LyricFever).")
                            Text("For support, please use [GitHub Issues](https://github.com/navel7/LyricRise/issues).")
                            Text("⚠️ Disclaimer: I do not own the rights to Spotify or the lyric content presented.\nMusixmatch and Spotify own all rights to the lyrics.\nTranslations by InTheManXG and ARui-tw")
                            Text("[LyricRise GitHub](https://github.com/navel7/LyricRise)\nVersion \(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown")")
                        }
                        .font(.callout)
                    }
                    .formStyle(.grouped)
                    .toggleStyle(.switch)
                case .karaoke: KaraokeSettingsView()
                case .shortcuts: GlobalKeyboardShortcutsView()
                }
            }
            .navigationTitle(Text(page.title))
        }
        .navigationSplitViewStyle(.balanced)
        .onAppear(perform: selectOpeningPage)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("didClickSettings"))) { _ in
            selectOpeningPage()
        }
    }

    private func selectOpeningPage() {
        selection = viewModel.userDefaultStorage.hasOnboarded ? .general : .player
    }
}
