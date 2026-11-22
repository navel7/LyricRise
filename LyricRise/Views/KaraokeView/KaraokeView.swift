//
//  KaraokeView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2024-10-08.
//

import SwiftUI
import SDWebImage
import ColorKit
import Combine

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()

        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        //
        nsView.material = .hudWindow
        nsView.blendingMode = .behindWindow
    }
}

private struct KaraokeWidthClip: AnimatableModifier {
    var width: CGFloat

    var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }

    func body(content: Content) -> some View {
        content.frame(width: max(width, 0)).clipped()
    }
}

@available(macOS 26.0, *)
private final class KaraokeGlassView<Content: View>: NSGlassEffectView {
    private let clippingView = NSView()
    private let hostingView: NSHostingView<Content>
    var contentWidth: CGFloat = 0

    init(content: Content) {
        hostingView = NSHostingView(rootView: content)
        super.init(frame: .zero)
        style = .clear
        clippingView.wantsLayer = true
        clippingView.layer?.masksToBounds = true
        clippingView.addSubview(hostingView)
        contentView = clippingView
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(content: Content, width: CGFloat, tint: NSColor) {
        hostingView.rootView = content
        contentWidth = width
        tintColor = tint
        needsLayout = true
    }

    override func layout() {
        super.layout()
        cornerRadius = bounds.height / 2
        clippingView.frame = bounds
        clippingView.layer?.cornerRadius = bounds.height / 2
        hostingView.frame = NSRect(x: (bounds.width - contentWidth) / 2, y: 2,
                                   width: contentWidth, height: bounds.height)
    }
}

@available(macOS 26.0, *)
private struct KaraokeGlass<Content: View>: NSViewRepresentable {
    let content: Content
    let contentWidth: CGFloat
    let tint: NSColor

    func makeNSView(context: Context) -> KaraokeGlassView<Content> {
        KaraokeGlassView(content: content)
    }

    func updateNSView(_ view: KaraokeGlassView<Content>, context: Context) {
        view.update(content: content, width: contentWidth, tint: tint)
    }
}

@available(macOS 26.0, *)
private struct KaraokeGlassLayout<Lyric: View>: AnimatableModifier {
    var width: CGFloat
    let targetWidth: CGFloat
    let tint: NSColor
    let lyric: Lyric

    var animatableData: CGFloat {
        get { width }
        set { width = newValue }
    }

    func body(content: Content) -> some View {
        content.hidden()
            .overlay {
                KaraokeGlass(content: lyric, contentWidth: targetWidth, tint: tint)
                    .frame(width: max(width, 0))
            }
            .frame(width: max(width, 0))
    }
}

private struct KaraokeLyricSegment {
    let text: String
    let fontSize: CGFloat
}

struct KaraokeView: View {
    @Environment(ViewModel.self) var viewmodel
    @State private var displayedPillWidth: CGFloat?
    @AppStorage("karaokeTransparency") var karaokeTransparency: Double = 50
    @AppStorage("karaokeTextColor") private var karaokeTextColor: KaraokeTextColor = .automatic
    @AppStorage("karaokeCustomTextColorHex") private var karaokeCustomTextColorHex = "#FFFFFF"
    @AppStorage("karaokeShowMultilingual") var karaokeShowMultilingual: Bool = true
    @AppStorage("karaokeUseAlbumColor") var karaokeUseAlbumColor: Bool = true
    @AppStorage("fixedKaraokeColorHex") var fixedKaraokeColorHex: String = "#2D3CCC"
    
    private var currentLyricSegments: [KaraokeLyricSegment] {
        guard let index = viewmodel.currentlyPlayingKaraokeLyricsIndex,
              viewmodel.currentlyPlayingLyrics.indices.contains(index)
        else { return [] }

        let original = viewmodel.currentlyPlayingLyrics[index].words
        let mainFontSize = viewmodel.karaokeFont.pointSize
        let words: String
        if viewmodel.romanizedLyrics.indices.contains(index) {
            words = viewmodel.romanizedLyrics[index]
        } else if viewmodel.chineseConversionLyrics.indices.contains(index) {
            words = viewmodel.chineseConversionLyrics[index]
        } else {
            words = original
        }

        if viewmodel.translationExists, viewmodel.translatedLyric.indices.contains(index) {
            let translation = viewmodel.translatedLyric[index]
            if karaokeShowMultilingual, original != translation {
                return [
                    KaraokeLyricSegment(text: words, fontSize: mainFontSize),
                    KaraokeLyricSegment(text: translation, fontSize: mainFontSize * 0.9)
                ]
            }
            return [KaraokeLyricSegment(text: translation, fontSize: mainFontSize)]
        }
        return [KaraokeLyricSegment(text: words, fontSize: mainFontSize)]
    }

    var hasVisibleCurrentLyric: Bool {
        currentLyricSegments.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    private func measuredWidth(for segment: KaraokeLyricSegment) -> CGFloat {
        let font = NSFont(name: viewmodel.karaokeFont.fontName, size: segment.fontSize) ?? viewmodel.karaokeFont
        return segment.text
            .components(separatedBy: .newlines)
            .map { ($0 as NSString).size(withAttributes: [.font: font]).width }
            .max() ?? 0
    }

    var karaokePillWidth: CGFloat {
        guard hasVisibleCurrentLyric else {
            return 0
        }
        let textWidth = currentLyricSegments.map { measuredWidth(for: $0) }.max() ?? 0
        return min(max(textWidth + 12, 0), 760) + 40
    }

    private var visiblePillWidth: CGFloat {
        displayedPillWidth ?? karaokePillWidth
    }
    
    @ViewBuilder
    func lyricsView() -> some View {
        let segments = currentLyricSegments
        if let first = segments.first, let second = segments.dropFirst().first {
            VStack(spacing: 6) {
                Text(verbatim: first.text)
                Text(verbatim: second.text)
                    .font(.custom(viewmodel.karaokeFont.fontName, size: second.fontSize))
                    .opacity(0.85)
            }
        } else {
            Text(verbatim: segments.first?.text ?? "")
        }
    }
    
    var karaokeLyricsText: some View {
        lyricsView()
            .lineLimit(2)
            .foregroundStyle(karaokeTextColor.color(customHex: karaokeCustomTextColorHex))
            .minimumScaleFactor(0.9)
            .font(.custom(viewmodel.karaokeFont.fontName, size: viewmodel.karaokeFont.pointSize))
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
    }

    var karaokePillContent: some View {
        Group {
            if hasVisibleCurrentLyric {
                if #available(macOS 26.0, *) {
                    karaokePillLayout
                        .modifier(KaraokeGlassLayout(
                            width: visiblePillWidth,
                            targetWidth: karaokePillWidth,
                            tint: NSColor(currentAlbumArt.opacity(karaokeTransparency / 100)),
                            lyric: karaokePillLayout
                        ))
                } else {
                    karaokePillLayout
                        .modifier(KaraokeWidthClip(width: visiblePillWidth))
                        .background {
                            currentAlbumArt
                                .opacity(karaokeTransparency / 100)
                                .background(VisualEffectView().ignoresSafeArea())
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Color.clear.frame(width: 0, height: 100)
            }
        }
        .onAppear {
            displayedPillWidth = karaokePillWidth
        }
        .onChange(of: karaokePillWidth) { _, newWidth in
            withAnimation(.easeIn(duration: 0.2)) {
                displayedPillWidth = newWidth
            }
        }
    }

    private var karaokePillLayout: some View {
        karaokeLyricsText
            .frame(width: max(karaokePillWidth - 40, 0))
            .padding(10)
            .padding(.horizontal, 10)
            .onHover { hover in
                if viewmodel.userDefaultStorage.karaokeModeHoveringSetting {
                    viewmodel.karaokeModeHovering = hover
                }
            }
    }

    @ViewBuilder
    var finalKaraokeView: some View {
        karaokePillContent
        .frame(minWidth: 800, maxWidth: 800, minHeight: 100, maxHeight: 100, alignment: .center)
        .clipped()
    }
    
    var currentAlbumArt: Color {
        // ensure user wants to use album-derived color, and album-derived color exists
        guard karaokeUseAlbumColor, let currentBackground = viewmodel.currentBackground else {
            return Color(NSColor(hexString: fixedKaraokeColorHex)!)
        }
        return currentBackground
    }
    
    var body: some View {
        finalKaraokeView
    }
}
