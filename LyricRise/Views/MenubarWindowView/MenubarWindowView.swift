//
//  MenubarWindowView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-07-26.
//

import AppKit
import SwiftUI
import Translation

private struct PanelWindowAnchor: NSViewRepresentable {
    let view: NSView

    func makeNSView(context: Context) -> NSView { view }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

struct MenubarWindowView: View {
    @Environment(\.openURL) var openURL
    @Environment(\.openWindow) var openWindow
    @Environment(ViewModel.self) var viewmodel
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    @State var currentHoveredItem = MenubarButtonHighlight.none
    @State var supportedLanguages: [Locale.Language] = []
    @State private var panelAnchor = NSView(frame: .zero)
    @State private var isPanelVisible = false
    @State private var progressDisplayDate = Date()

    private var hasPlaybackProgress: Bool {
        viewmodel.userDefaultStorage.hasOnboarded && viewmodel.duration > 0
    }
    
    @ViewBuilder
    var profilePicViewHeaderView: some View {
        ZStack {
            if let artworkImage = viewmodel.artworkImage {
                Image(nsImage: artworkImage)
                    .resizable()
                    .frame(width: 112, height: 112)
                    .clipShape(.rect(cornerRadius: 9))
//                    .animation(.smooth(duration: 0.3), value: viewmodel.newAlbum)
                    .apply {
                        if let shareURL = viewmodel.currentPlayerInstance.shareURL(for: viewmodel.currentlyPlaying) {
                            $0
                                .draggable(shareURL)
                        } else {
                            $0
                        }
                    }
                    .shadow(color: viewmodel.currentBackground ?? .clear, radius: 70)
                    .shadow(color: viewmodel.currentBackground ?? .clear, radius: 70)
            } else {
                Image("LyricRiseIcon")
                    .resizable()
                    .frame(width: 112, height: 112)
                    .clipShape(.rect(cornerRadius: 9))
            }
            
            ZStack {
                if viewmodel.isFetching {
                    Rectangle()
                        .fill(Color.black.opacity(0.5))
                        .clipShape(.rect(cornerRadius: 9))
                    
                    ProgressView()
                }
            }
            .animation(.smooth(duration: 2), value: viewmodel.isFetching)
        }
        .frame(width: 112, height: 112)
    }
    
    @ViewBuilder
    var songDetails: some View {
        VStack {
            HStack {
                MarqueeText(viewmodel.currentlyPlayingName ?? "-", startDelay: 1.5, alignment: .leading, leftFade: 2)
                .frame(height: 15)
            }
            HStack {
                MarqueeText(viewmodel.currentlyPlayingArtist ?? "-", startDelay: 1.5, alignment: .leading, leftFade: 2)
                    .font(.caption)
                    .frame(height: 15)
            }
        }
    }
    
    @ViewBuilder
    var songControls: some View {
        HStack {
            SongControlButton(systemImage: "backward.fill") {
                viewmodel.currentPlayerInstance.rewind()
            }
            .onHover { isHovering in
                currentHoveredItem = isHovering ? .rewind : .none
            }
            SongControlButton(systemImage: viewmodel.isPlaying ? "pause.fill" : "play.fill", wiggle: false) {
                viewmodel.currentPlayerInstance.togglePlayback()
            }
//            .controlSize(.large)
            .onHover { isHovering in
                currentHoveredItem = isHovering ? (viewmodel.isPlaying ? .pause : .play) : .none
            }
            .keyboardShortcut(" ", modifiers: [])
            .contentTransition(.symbolEffect(.replace, options: .speed(2)))
            
            SongControlButton(systemImage: "forward.fill") {
                viewmodel.currentPlayerInstance.forward()
            }
            .onHover { isHovering in
                currentHoveredItem = isHovering ? .forward : .none
            }
        }
        .frame(height: 30)
//        .buttonStyle(.accessoryBar)
    }
    
    @ViewBuilder
    var headerView: some View {
        HStack(spacing: 12) {
            profilePicViewHeaderView
                .onHover { isHovering in
                    currentHoveredItem = isHovering ? viewmodel.currentPlayerInstance.currentHoverItem : .none
                }
                .onTapGesture {
                    viewmodel.currentPlayerInstance.activate()
                    dismiss()
                }
            VStack {
                HStack {
                    songDetails
//                    LikeButton()
//                        .task(id: viewmodel.currentlyPlaying) {
//                            guard let currentlyPlaying = viewmodel.currentlyPlaying else {
//                                print("Ignoring nil currentlyPlaying for heart check")
//                                return
//                            }
//                            print("Task to check if \(viewmodel.currentlyPlaying) is hearted")
//                            do {
//                                viewmodel.isHearted = try await viewmodel.spotifyLyricProvider.checkHeartedStatusFor(trackID: currentlyPlaying)
//                            } catch {
//                                print(error)
//                            }
//                        }
//                        .onHover { isHovering in
//                            currentHoveredItem = isHovering ? (viewmodel.isHearted ? .unheart : .heart) : .none
//                        }
                }
                songControls
                
                playbackProgress(at: progressDisplayDate)
                .task(id: isPanelVisible && viewmodel.isPlaying && hasPlaybackProgress) {
                    guard isPanelVisible, viewmodel.isPlaying, hasPlaybackProgress else { return }
                    do {
                        while !Task.isCancelled {
                            progressDisplayDate = Date()
                            try await Task.sleep(for: .seconds(1))
                        }
                    } catch is CancellationError {
                        return
                    } catch {
                        assertionFailure("Unexpected progress timer failure: \(error)")
                    }
                }
                .onChange(of: viewmodel.isPlaying) {
                    if isPanelVisible { viewmodel.refreshPlaybackPosition() }
                }
                .onChange(of: viewmodel.currentlyPlaying) {
                    if isPanelVisible, viewmodel.currentlyPlaying != nil {
                        viewmodel.refreshPlaybackPosition()
                    }
                }
                volumeSlider
            }
        }
        // even out vertical padding with divider as compared to Menubar button
        .padding(.bottom, 2)
    }
    
    private func playbackProgress(at date: Date) -> some View {
        VStack {
            GeometryReader { geometry in
                ProgressView(value: hasPlaybackProgress ? viewmodel.lyricProgressTime(at: date) : 0, total: Double(max(1, viewmodel.duration)))
                    .progressViewStyle(ColoredThinProgressViewStyle(color: .secondary, thickness: 4))
                    .frame(height: 4)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .onTapGesture { location in
                        guard hasPlaybackProgress, geometry.size.width > 0 else { return }
                        viewmodel.seekPlayback(to: location.x / geometry.size.width)
                    }
            }
            .frame(height: 12)
            .padding(.horizontal, 4)

            HStack {
                Text(hasPlaybackProgress ? viewmodel.formattedCurrentTime(for: date) : "--:--")
                    .font(.caption2)
                Spacer()
                Text(viewmodel.formattedDuration)
                    .font(.caption2)
            }
            .padding(.horizontal, 4)
        }
    }

    var displayLyrics: ButtonState {
        if !viewmodel.userDefaultStorage.hasOnboarded {
            return .disabled
        } else if viewmodel.lyricsIsEmptyPostLoad {
            return .disabled
        } else if viewmodel.showLyrics {
            return .enabled
        } else {
            return .clickable
        }
    }
    
    
    @ViewBuilder
    var lyricModifierView: some View {
        HStack {
            MenubarButton(buttonText: "", imageText: "", buttonState: displayLyrics, assetName: "LyricRiseTrayIcon") {
                viewmodel.showLyrics.toggle()
            }
            .onHover { isHovering in
                if isHovering {
                    switch displayLyrics {
                        case .enabled:
                            currentHoveredItem = .disableLyrics
                        case .disabled:
                            currentHoveredItem = .unavailableLyrics
                        case .clickable:
                            currentHoveredItem = .enableLyrics
                        default:
                            currentHoveredItem = .none
                    }
                } else {
                    currentHoveredItem = .none
                }
            }
            MenubarButton(buttonText: "", imageText: "arrow.up.left.and.arrow.down.right", buttonState: displayFullscreen) {
                viewmodel.displayFullscreen.toggle()
                dismiss()
            }
            .onHover { isHovering in
                currentHoveredItem = isHovering ? (viewmodel.displayFullscreen ? .disableFullscreen : .enableFullscreen) : .none
            }
//            .foregroundStyle(.white)
            MenubarButton(buttonText: "", imageText: "dock.rectangle", buttonState: displayKaraoke) {
                viewmodel.userDefaultStorage.karaoke.toggle()
            }
            .onHover { isHovering in
                if isHovering {
                    switch displayKaraoke {
                        case .enabled:
                            currentHoveredItem = .disableKaraoke
                        case .disabled:
                            currentHoveredItem = .unavailableKaraoke
                        case .clickable:
                            currentHoveredItem = .enableKaraoke
                        default:
                            currentHoveredItem = .none
                    }
                } else {
                    currentHoveredItem = .none
                }
            }
        }
    }

    @ViewBuilder
    var translationAndRomanizationView: some View {
        @Bindable var viewmodel = viewmodel
        Section("Translation Options") {
            if viewmodel.userDefaultStorage.translate {
                if viewmodel.translationNotNeeded {
                    Text("Translation not needed")
                } else {
                    Text(!viewmodel.translatedLyric.isEmpty ? "Translated Lyrics 😃" : "No Translation ☹️")
                }
                if viewmodel.translatedLyric.isEmpty && !viewmodel.translationNotNeeded {
                    Button("Translation Help") {
                        openURL(URL(string: "https://aviwadhwa.com/TranslationHelp")!)
                    }
                }
            }
            
            Toggle("Translate To \(viewmodel.userLocaleLanguageString)", isOn: $viewmodel.userDefaultStorage.translate)
            .disabled(!viewmodel.userDefaultStorage.hasOnboarded)
            Divider()
        }
        let translationSourceLanguagePickerBinding = Binding<String?> (
           get: {
               return viewmodel.translationSourceLanguage?.maximalIdentifier
           },
           set: {
               if let localeIdentifier = $0 {
                   viewmodel.translationSourceLanguage = Locale.Language(identifier: localeIdentifier)
               } else {
                   viewmodel.translationSourceLanguage = nil
               }
               guard let trackID = viewmodel.currentlyPlaying else {
                   print("Translationg: ignoring source language change: nil currentlyPlaying")
                   return
               }
               guard let translationSourceLanguage = viewmodel.translationSourceLanguage else {
                   print("Translation: source language change: nil source language, deleting existing pair")
                   viewmodel.deleteSongLocalePairing(trackID: trackID)
                   return
               }
               let localeIdentifier = translationSourceLanguage.maximalIdentifier
//               guard let localeIdentifier = translationSourceLanguage.maximalIdentifier else {
//                   print("Translation: ignoring source language change: nil locale identifier")
//                   return
//               }
               print("Translation: Source language changed. Saving new pair (\(trackID),\(localeIdentifier))  to coredata")
               let newSongToLocaleMapping = SongToLocale(context: viewmodel.coreDataContainer.viewContext)
               newSongToLocaleMapping.id = trackID
               newSongToLocaleMapping.locale = localeIdentifier
               do {
                   try viewmodel.coreDataContainer.viewContext.save()
                   print("Translation: Successfully saved locale \(String(describing: newSongToLocaleMapping.locale)) for trackID \(trackID)")
               } catch {
                   print("Translation: Couldn't save locale mapping to CoreData: \(error)")
               }
           }
       )
        Section("Translation Settings for This Song") {
            Picker("Source Language", selection: translationSourceLanguagePickerBinding) {
                Text("Auto").tag(nil as String?)
                ForEach(supportedLanguages, id: \.maximalIdentifier) { language in
                    Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? language.maximalIdentifier).tag(language.maximalIdentifier)
                }
            }
        }
//        .onChange(of: viewmodel.translationSourceLanguage) {
//        }
        Section("Translation Settings for All Songs") {
            Picker("Target Language", selection: $viewmodel.userDefaultStorage.translationTargetLanguage) {
                Text("System (\(viewmodel.systemLocaleString))").tag(nil as Locale.Language?)
                ForEach(supportedLanguages, id: \.maximalIdentifier) { language in
                    Text(Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? language.maximalIdentifier).tag(language)
                }
            }
        }
        Section("Transliteration Options") {
            Toggle("Romanize", isOn: $viewmodel.userDefaultStorage.romanize)
//            Toggle("Romanize Song Details", isOn: $viewmodel.userDefaultStorage.romanizeMetadata)
//                .disabled(!viewmodel.userDefaultStorage.romanize)
            Picker("Chinese Conversion", selection: $viewmodel.userDefaultStorage.chinesePreference) {
                ForEach(ChineseConversion.allCases) { conversionCase in
                    Text(LocalizedStringKey(conversionCase.description)).tag(conversionCase.rawValue)
                }
            }
        }
    }
    
    var displayFullscreen: ButtonState {
        if !viewmodel.userDefaultStorage.hasOnboarded {
            return .disabled
        } else if viewmodel.displayFullscreen {
            return .enabled
        } else {
            return .clickable
        }
    }
    
    var displayKaraoke: ButtonState {
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .disabled
        }
        guard viewmodel.showLyrics else {
            return .disabled
        }
        guard !viewmodel.lyricsIsEmptyPostLoad else {
            return .disabled
        }
        if viewmodel.userDefaultStorage.karaoke {
            return .enabled
        } else {
            return .clickable
        }
    }
    
    var refreshState: ButtonState {
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .disabled
        }
        if viewmodel.isFetching {
            return .loading
        } else {
            return .clickable
        }
    }
    
    var translationState: ButtonState {
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .disabled
        }
        guard !viewmodel.lyricsIsEmptyPostLoad else {
            return .disabled
        }
        if viewmodel.userDefaultStorage.translate {
            if viewmodel.isFetchingTranslation {
                return .loading
            } else if viewmodel.translationExists || viewmodel.translationNotNeeded {
                return .enabled
            } else {
                return .missing
            }
        } else if viewmodel.userDefaultStorage.romanize {
            return .enabled
        } else {
            return .clickable
        }
    }
    
    var searchState: ButtonState {
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .disabled
        }
        return .clickable
    }
    
    var deleteOrUploadState: ButtonState {
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .disabled
        }
        // attach a separate disabled modifier to prevent slash flashing
//        if viewmodel.isFetching {
//            return .disabled
//        }
        return .clickable
    }
    
    @ViewBuilder
    var viewSelector: some View {
        @Bindable var viewmodel = viewmodel
        HStack {
            SmallMenubarButton(buttonText: "", imageText: "arrow.clockwise", buttonState: refreshState) {
                Task {
                    do {
                        try await viewmodel.refreshLyrics()
                    } catch {
                        print("Couldn't refresh lyrics: error \(String(describing: error))")
                    }
                }
            }
            .disabled(refreshState == .loading)
            .onHover { isHovering in
                if isHovering {
                    switch refreshState {
                        case .loading:
                            currentHoveredItem = .refreshingLyrics
                        case .disabled:
                            currentHoveredItem = .none
                        case .clickable:
                            currentHoveredItem = .refreshLyrics
                        default:
                            currentHoveredItem = .none
                    }
                } else {
                    currentHoveredItem = .none
                }
            }
            SmallMenubarButton(buttonText: "", imageText: "magnifyingglass", buttonState: searchState) {
                NSApplication.shared.activate(ignoringOtherApps: true)
                openWindow(id: "search")
            }
            .onHover { isHovering in
                if isHovering {
                    currentHoveredItem = .search
                } else {
                    currentHoveredItem = .none
                }
            }
            Menu {
                translationAndRomanizationView
            } label: {
               
            }
            .disabled(translationState == .disabled)
            .buttonStyle(SmallMenubarButtonStyle(imageText: "translate", buttonState: translationState))
            .onHover { isHovering in
                if isHovering {
                    switch translationState {
                        case .enabled:
                            currentHoveredItem = viewmodel.translationNotNeeded ? .translationNotNeeded : .translateEnabled
                        case .disabled:
                            currentHoveredItem = .translationUnavailable
                        case .loading:
                            currentHoveredItem = .translationLoading
                        case .clickable:
                            currentHoveredItem = .translate
                        case .missing:
                            currentHoveredItem = .translationFail
                    }
                } else {
                    currentHoveredItem = .none
                }
            }
            SmallMenubarButton(buttonText: "", imageText: viewmodel.lyricsIsEmptyPostLoad ? "arrow.up.document" : "trash", buttonState: deleteOrUploadState) {
                if viewmodel.lyricsIsEmptyPostLoad {
                    Task {
                        do {
                            try await viewmodel.uploadLocalLRCFile()
                        } catch {
                            print("MenuBarWindowView: Upload LRC: Error occurred: \(error)")
                        }
                    }
                } else {
                    guard let currentlyPlaying = viewmodel.currentlyPlaying else { return }
                    viewmodel.deleteLyric(trackID: currentlyPlaying)
                }
            }
            .disabled(viewmodel.isFetching)
            .onHover { isHovering in
                if isHovering {
                    if viewmodel.lyricsIsEmptyPostLoad {
                        currentHoveredItem = .upload
                    } else {
                        currentHoveredItem = .delete
                    }
                } else {
                    currentHoveredItem = .none
                }
            }
            .contentTransition(.symbolEffect(.replace))
        }
    }
    
    @ViewBuilder
    var systemControlView: some View {
        HStack {
            Button {
                panelAnchor.window?.orderOut(nil)
                openWindow(id: "onboarding")
                NSApplication.shared.activate(ignoringOtherApps: true)
                NotificationCenter.default.post(name: Notification.Name("didClickSettings"), object: nil)
            } label: {
                Image(systemName: "gearshape")
                    .accessibilityLabel("Settings…")
            }
            .help(Text("Settings…"))
            .keyboardShortcut("s")
            .background {
                PanelWindowAnchor(view: panelAnchor)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }

            Spacer()
            Text(currentHoveredItem.description)
                .minimumScaleFactor(0.8)
                .font(.body)
            Spacer()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.top, 8)
    }
    

    
    private var sliderTint: Color? {
        if #available(macOS 26.0, *) {
            return nil
        }
        return .secondary
    }

    var volumeBinding: Binding<Double> {
        Binding(
            get: { Double(viewmodel.currentVolume) },
            set: { newValue in
                viewmodel.currentPlayerInstance.setVolume(to: newValue)
                viewmodel.currentVolume = Int(newValue)
            }
        )
    }
    
    @ViewBuilder
    var volumeSlider: some View {
        HStack(spacing: 6) {
            Image(systemName: "speaker.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            if #available(macOS 26.0, *) {
                Slider(value: volumeBinding, in: 0...100) {
                    Text("Volume")
                } ticks: {
                    
                }
                .labelsHidden()
                .frame(width: 160)
            } else {
                Slider(value: volumeBinding, in: 0...100) {
                    Text("Volume")
                }
                .labelsHidden()
                .frame(width: 160)
            }
            Image(systemName: "speaker.wave.3.fill")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
        }
        .tint(sliderTint)
    }
    
    var body: some View {
        VStack {
            if case let .available(version, url) = viewmodel.updaterService.status {
                HStack {
                    Text("LyricRise \(version) is available.")
                    Spacer()
                    Link("Download Update", destination: url)
                }
                .font(.callout)
                Divider()
            }
            headerView
            Divider()
            lyricModifierView
            Divider()
            viewSelector
            Divider()
            Divider()
            systemControlView
        }
        .foregroundStyle(.primary)
        .padding(14)
        .background {
            if #available(macOS 26.0, *) {
                RoundedRectangle(cornerRadius: 16)
                    .fill(.clear)
                    .glassEffect(
                        .clear.tint((viewmodel.currentBackground ?? .clear).opacity(0.25)),
                        in: .rect(cornerRadius: 16)
                    )
            } else {
                viewmodel.currentBackground
                    .brightness(colorScheme == .dark ? -0.4 : -0.8)
                    .opacity(0.6)
                    .animation(.smooth, value: viewmodel.currentBackground)
                    .background(Color(white: 0.1))
            }
        }
        .onAppear {
            isPanelVisible = panelAnchor.window?.occlusionState.contains(.visible) ?? true
            if isPanelVisible { viewmodel.refreshPlaybackPosition() }
            if !viewmodel.isStopped {
                viewmodel.currentVolume = viewmodel.currentPlayerInstance.volume
            }
        }
        .onDisappear { isPanelVisible = false }
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didChangeOcclusionStateNotification)) { notification in
            guard let window = notification.object as? NSWindow, window === panelAnchor.window else { return }
            let visible = window.occlusionState.contains(.visible)
            if visible && !isPanelVisible { viewmodel.refreshPlaybackPosition() }
            isPanelVisible = visible
        }
        .task {
            let languages = await Task.detached {
                await LanguageAvailability().supportedLanguages
            }.value
            await MainActor.run {
                supportedLanguages = languages
            }
        }
    }
}
