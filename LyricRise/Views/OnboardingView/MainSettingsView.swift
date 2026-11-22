//
//  MainSettingsView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-07-26.
//

//
//  MainSettingsView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-07-19.
//

import AppKit
import SwiftUI
import SDWebImageSwiftUI

enum MainSettingsError: Error, Identifiable, CaseIterable {
    case openSpotify
    case openAppleMusic
    case missingAuthorization
    case authorized
    
    var id: Self { self }
    
    var description: LocalizedStringKey {
        switch self {
        case .openSpotify:
            return LocalizedStringKey("Please open Spotify")
        case .openAppleMusic:
            return LocalizedStringKey("Please open Apple Music")
        case .missingAuthorization:
            return LocalizedStringKey("Please give required permissions!")
        case .authorized:
            return " "
        }
    }
}

struct MainSettingsView: View {
    let onDone: () -> Void

    private enum Step: Hashable {
        case spotifyLogin, lyricSize
    }

    @State private var path: [Step] = []
    @Environment(ViewModel.self) var viewModel
    @State var permissionDenied: Bool = false
    @State var error: MainSettingsError = .openSpotify
    @AppStorage("spotifyOrAppleMusic") var spotifyOrAppleMusic: Bool = false
    
    @ViewBuilder
    var permissionDeniedView: some View {
        AnimatedImage(name: "newPermissionMac.gif")
            .resizable()
            .frame(width: 397, height: 340)
        HStack {
            Button("Open Automation Panel", action: {
                let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!
                NSWorkspace.shared.open(url)
            })
        }
    }
    
    @ViewBuilder
    var permissionsOrNextButton: some View {
        if error == .authorized {
            NavigationLink("Next", value: Step.spotifyLogin)
                .font(.headline)
                .controlSize(.large)
                .buttonStyle(.borderedProminent)
        } else {
            HStack {
                Button("Give Spotify Permissions") {
                    if !viewModel.spotifyPlayer.isRunning {
                        print("Spotify not running")
                        error = .openSpotify
                    } else if !viewModel.spotifyPlayer.isAuthorized {
                        error = .openSpotify
                        permissionDenied = true
                    } else {
                        permissionDenied = false
                        error = .authorized
                    }
                }
                .disabled(viewModel.currentPlayer == .appleMusic)
                
                Button("Give Apple Music Permissions") {
                    if !viewModel.appleMusicPlayer.isRunning {
                        error = .openAppleMusic
                    } else if !viewModel.appleMusicPlayer.isAuthorized {
                        error = .openAppleMusic
                        permissionDenied = true
                    } else {
                        permissionDenied = false
                        error = .authorized
                    }
                }
                .disabled(viewModel.currentPlayer == .spotify)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
    
    private var appleMusicIcon: Image {
        let workspace = NSWorkspace.shared
        guard let url = workspace.urlForApplication(withBundleIdentifier: "com.apple.Music") else {
            return Image("music")
        }
        return Image(nsImage: workspace.icon(forFile: url.path))
    }

    var body: some View {
        NavigationStack(path: $path) {
            Form {
                if permissionDenied {
                    Section {
                        permissionDeniedView
                    }
                }

                Section {
                    Picker("Please pick between Spotify and Apple Music", selection: $spotifyOrAppleMusic) {
                        VStack {
                            Text("Spotify")
                            Image("spotify")
                                .resizable()
                                .frame(width: 70.0, height: 70.0)
                        }.tag(false)
                        VStack {
                            Text("Apple Music")
                            appleMusicIcon
                                .resizable()
                                .scaledToFit()
                                .frame(width: 70.0, height: 70.0)
                        }.tag(true)
                    }
                    .pickerStyle(.radioGroup)
                    .horizontalRadioGroupLayout()

                    if error != .authorized {
                        Text(error.description)
                            .foregroundStyle(.secondary)
                    }
                    permissionsOrNextButton
                }

            }
            .formStyle(.grouped)
            .navigationDestination(for: Step.self) { step in
                switch step {
                case .spotifyLogin:
                    ApiView(onContinue: { path.append(.lyricSize) })
                case .lyricSize:
                    FinalTruncationView(onDone: {
                        path.removeAll()
                        onDone()
                    })
                }
            }
            .animation(.bouncy, value: permissionDenied)
            .animation(.bouncy, value: error)
            .onChange(of: viewModel.currentPlayer) {
                print("Updating permission booleans based on media player change")
                switch viewModel.currentPlayer {
                case .appleMusic:
                        error = .openAppleMusic
                case .spotify:
                        error = .openSpotify
                }
            }
        }
    }
}

