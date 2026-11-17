//
//  MenubarLabelView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-08-05.
//

import SwiftUI

struct MenubarStatusIcon: View {
    var playbackSymbol: String?

    private func renderedIcon(playbackSymbol symbol: String?) -> NSImage? {
        let icon = ZStack(alignment: .bottomTrailing) {
            Image("LyricRiseTrayIcon")
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .foregroundStyle(.black)
                .frame(width: 23, height: 18, alignment: .leading)
            if symbol != nil {
                Circle()
                    .fill(.black)
                    .frame(width: 10, height: 10)
                    .blendMode(.destinationOut)
            }
        }
        .compositingGroup()
        .overlay(alignment: .bottomTrailing) {
            if let symbol {
                Image(systemName: symbol)
                    .font(.system(size: 7, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 9, height: 9)
            }
        }
        .frame(width: 23, height: 18)

        let renderer = ImageRenderer(content: icon)
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            print("MenubarStatusIcon: could not render icon with playback symbol \(symbol ?? "none")")
            return nil
        }
        image.isTemplate = true
        return image
    }

    @ViewBuilder
    var body: some View {
        if let image = renderedIcon(playbackSymbol: playbackSymbol) {
            Image(nsImage: image)
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: 23, height: 18)
        } else {
            Image("LyricRiseTrayIcon")
                .renderingMode(.template)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
        }
    }

}

struct MenubarLabelView: View {
    @Environment(ViewModel.self) var viewmodel

    private enum Content {
        case lyric(String)
        case song(name: String, artist: String, isPlaying: Bool)
        case notice(String)
        case icon
    }

    private var content: Content {
        if viewmodel.mustUpdateUrgent {
            return .notice(String(localized: "⚠️ Please Update (Click Check Updates)"))
        }
        guard viewmodel.userDefaultStorage.hasOnboarded else {
            return .notice(String(localized: "⚠️ Complete Setup (Click Settings)"))
        }
        if !viewmodel.fullscreen, !viewmodel.userDefaultStorage.karaoke,
           viewmodel.isPlaying, viewmodel.showLyrics,
           let index = viewmodel.currentlyPlayingKaraokeLyricsIndex,
           viewmodel.currentlyPlayingLyrics.indices.contains(index) {
            if viewmodel.translatedLyric.indices.contains(index) {
                return .lyric(viewmodel.translatedLyric[index])
            } else if viewmodel.romanizedLyrics.indices.contains(index) {
                return .lyric(viewmodel.romanizedLyrics[index])
            } else if viewmodel.chineseConversionLyrics.indices.contains(index) {
                return .lyric(viewmodel.chineseConversionLyrics[index])
            } else {
                return .lyric(viewmodel.currentlyPlayingLyrics[index].words)
            }
        }
        if viewmodel.userDefaultStorage.showSongDetailsInMenubar,
           let name = viewmodel.currentlyPlayingName,
           let artist = viewmodel.currentlyPlayingArtist {
            return .song(name: name, artist: artist, isPlaying: viewmodel.isPlaying)
        }
        return .icon
    }

    @ViewBuilder
    var body: some View {
        switch content {
        case .lyric(let lyric):
            Text(lyric.trunc())
        case .song(let name, let artist, let isPlaying):
            HStack(spacing: 4) {
                MenubarStatusIcon(playbackSymbol: isPlaying ? "play.fill" : "pause.fill")
                Text("\(name) - \(artist)".trunc())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(isPlaying
                ? String(localized: "Now Playing: \(name) - \(artist)")
                : String(localized: "Now Paused: \(name) - \(artist)")))
        case .notice(let notice):
            HStack(spacing: 4) {
                MenubarStatusIcon()
                Text(notice.trunc())
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(notice))
        case .icon:
            MenubarStatusIcon()
                .accessibilityLabel(Text("LyricRise"))
        }
    }
}
