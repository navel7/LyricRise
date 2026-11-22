//
//  KaraokeSettings.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-02-08.
//

import SwiftUI
import AppKit

@MainActor
private final class KaraokeFontPanelTarget: NSObject {
    weak var viewModel: ViewModel?

    @objc func changeFont(_ sender: NSFontManager) {
        guard let viewModel else { return }
        viewModel.karaokeFont = sender.convert(viewModel.karaokeFont)
    }
}

enum KaraokeTextColor: String, CaseIterable {
    case automatic, blue, purple, pink, red, orange, yellow, green, graphite, custom

    static var presets: [Self] {
        allCases.filter { $0 != .automatic && $0 != .custom }
    }

    var title: LocalizedStringKey {
        switch self {
        case .automatic: "Automatic"
        case .blue: "Blue"
        case .purple: "Purple"
        case .pink: "Pink"
        case .red: "Red"
        case .orange: "Orange"
        case .yellow: "Yellow"
        case .green: "Green"
        case .graphite: "Graphite"
        case .custom: "Choose Color…"
        }
    }

    func color(customHex: String) -> Color {
        let hex: String
        switch self {
        case .automatic: return .primary
        case .blue: hex = "#AED7FF"
        case .purple: hex = "#DFC2E1"
        case .pink: hex = "#FFC5E1"
        case .red: hex = "#FFC3C3"
        case .orange: hex = "#FFD7B3"
        case .yellow: hex = "#FFF0B5"
        case .green: hex = "#C9E8C2"
        case .graphite: hex = "#DDDDDD"
        case .custom: hex = customHex
        }
        return NSColor(hexString: hex).map { Color($0) } ?? .primary
    }
}

struct KaraokeSettingsView: View {
    @State private var fontPanelTarget = KaraokeFontPanelTarget()
    @Environment(ViewModel.self) var viewmodel
    @AppStorage("karaokeUseAlbumColor") var karaokeUseAlbumColor: Bool = true
    @AppStorage("fixedKaraokeColorHex") var fixedKaraokeColorHex: String = "#2D3CCC"
    @AppStorage("karaokeModeHoveringSetting") var karaokeModeHoveringSetting: Bool = false
    @AppStorage("karaokeShowMultilingual") var karaokeShowMultilingual: Bool = true
    @AppStorage("karaokeTransparency") var karaokeTransparency: Double = 50
    @AppStorage("karaokeTextColor") private var karaokeTextColor: KaraokeTextColor = .automatic
    @AppStorage("karaokeCustomTextColorHex") private var karaokeCustomTextColorHex = "#FFFFFF"
    @AppStorage("karaokeTimingAdjustment") var karaokeTimingAdjustment: Double = -0.5

    private var timingDescription: String {
        if abs(karaokeTimingAdjustment) < 0.05 { return String(localized: "Original timing") }
        let seconds = abs(karaokeTimingAdjustment).formatted(.number.precision(.fractionLength(2)))
        return karaokeTimingAdjustment < 0
            ? String(localized: "\(seconds) s earlier")
            : String(localized: "\(seconds) s later")
    }
    
    var colorBinding: Binding<Color> {
        Binding<Color> {
            Color(NSColor(hexString: fixedKaraokeColorHex)!)
        } set: { newValue in
            fixedKaraokeColorHex = NSColor(newValue).hexString!
        }
    }

    var body: some View {
        Form {
            Section("Karaoke Behaviour") {
                Toggle("Hide Karaoke window when mouse passes by", isOn: $karaokeModeHoveringSetting)
                Toggle("Show multilingual lyrics when translating in Karaoke window", isOn: $karaokeShowMultilingual)
                GeometryReader { geometry in
                    HStack(spacing: 8) {
                        Text("Lyric display timing")
                        Spacer(minLength: 8)
                        if abs(karaokeTimingAdjustment) >= 0.05 {
                            Text(timingDescription)
                                .fixedSize()
                                .accessibilityHidden(true)
                        }
                        HStack(spacing: 4) {
                            Image(systemName: "hare")
                                .accessibilityHidden(true)
                            Slider(value: $karaokeTimingAdjustment, in: -2...2, step: 0.25)
                                .labelsHidden()
                                .accessibilityLabel("Lyric display timing")
                                .accessibilityValue(timingDescription)
                            Image(systemName: "tortoise")
                                .accessibilityHidden(true)
                        }
                        .frame(maxWidth: geometry.size.width * 0.5)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                }
                .frame(height: 28)
            }
            Section("Karaoke Background Appearance") {
                Toggle("Use album color for Karaoke window", isOn: $karaokeUseAlbumColor)
                if !karaokeUseAlbumColor {
                    ColorPicker("Set a background color", selection: colorBinding, supportsOpacity: false)
                }
                LabeledContent("Opacity Level") {
                    HStack {
                        opacityIcon(filled: false)
                            .accessibilityHidden(true)
                        VStack(spacing: 1) {
                            Slider(value: opacitySliderValue, in: 1...100)
                            .accessibilityLabel("Opacity Level")
                            .accessibilityValue("\(Int(karaokeTransparency)) percent")
                            .accessibilityAdjustableAction { direction in
                                switch direction {
                                case .increment: karaokeTransparency = min(100, karaokeTransparency + 5)
                                case .decrement: karaokeTransparency = max(1, karaokeTransparency - 5)
                                @unknown default: break
                                }
                            }
                            HStack {
                                Circle().frame(width: 2, height: 2)
                                Spacer()
                                Circle().frame(width: 2, height: 2)
                                Spacer()
                                Circle().frame(width: 2, height: 2)
                            }
                            .foregroundStyle(.tertiary)
                            .padding(.horizontal, 10)
                            .accessibilityHidden(true)
                        }
                        opacityIcon(filled: true)
                            .accessibilityHidden(true)
                    }
                    .frame(maxWidth: 260)
                }
                HStack {
                    Picker("Karaoke Text Color", selection: $karaokeTextColor) {
                        Label {
                            Text(KaraokeTextColor.automatic.title)
                        } icon: {
                            colorSwatch(LinearGradient(
                                colors: KaraokeTextColor.presets.map { $0.color(customHex: karaokeCustomTextColorHex) },
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        }
                        .tag(KaraokeTextColor.automatic)
                        Divider()
                        ForEach(KaraokeTextColor.presets, id: \.self) { option in
                            colorOption(option)
                        }
                        Divider()
                        colorOption(.custom)
                    }
                    .pickerStyle(.menu)
                    if karaokeTextColor == .custom {
                        ColorPicker("Custom Karaoke Text Color", selection: Binding {
                            KaraokeTextColor.custom.color(customHex: karaokeCustomTextColorHex)
                        } set: { color in
                            if let hex = NSColor(color).hexString {
                                karaokeCustomTextColorHex = hex
                            }
                        }, supportsOpacity: false)
                        .labelsHidden()
                    }
                }
            }
            Section("Karaoke Font Appearance") {
                LabeledContent("Font") {
                    Button("Select a Font…") {
                        let manager = NSFontManager.shared
                        fontPanelTarget.viewModel = viewmodel
                        manager.target = fontPanelTarget
                        manager.setSelectedFont(viewmodel.karaokeFont, isMultiple: false)
                        manager.orderFrontFontPanel(nil)
                    }
                    .buttonStyle(.bordered)
                }
                Text("Karaoke Font Preview Sample")
                    .font(.custom(viewmodel.karaokeFont.fontName, size: viewmodel.karaokeFont.pointSize))
                    .foregroundStyle(karaokeTextColor.color(customHex: karaokeCustomTextColorHex))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button("Reset to default") {
                viewmodel.userDefaultStorage.karaokeModeHoveringSetting = false
                karaokeUseAlbumColor = true
                karaokeTimingAdjustment = -0.5
                viewmodel.userDefaultStorage.karaokeShowMultilingual = true
                viewmodel.userDefaultStorage.karaokeTransparency = 50
                karaokeTextColor = .automatic
                karaokeCustomTextColorHex = "#FFFFFF"
                viewmodel.karaokeFont = NSFont.boldSystemFont(ofSize: 30)
                colorBinding.wrappedValue = Color(.sRGB, red: 0.98, green: 0.0, blue: 0.98)
            }
            .buttonStyle(.bordered)
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .formStyle(.grouped)
        .toggleStyle(.switch)
        .onDisappear {
            if NSFontManager.shared.target === fontPanelTarget {
                NSFontManager.shared.target = nil
            }
        }
    }

    private var opacitySliderValue: Binding<Double> {
        Binding(get: { karaokeTransparency }, set: { value in
            let steps = ((value - 1) / 5).rounded()
            karaokeTransparency = value == 100 ? 100 : min(100, 1 + steps * 5)
        })
    }

    private func opacityIcon(filled: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            let back = RoundedRectangle(cornerRadius: 2)
            let front = RoundedRectangle(cornerRadius: 5)

            if filled {
                back.fill(.secondary)
                    .frame(width: 12.5, height: 10)
                    .mask(alignment: .topLeading) {
                        Rectangle().fill(.white)
                            .overlay(alignment: .topLeading) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(.black)
                                    .frame(width: 15, height: 12)
                                    .offset(x: 2, y: 1.5)
                                    .blendMode(.destinationOut)
                            }
                            .compositingGroup()
                    }
                front.fill(.secondary)
                    .frame(width: 13, height: 10)
                    .offset(x: 3, y: 2.5)
            } else {
                back.strokeBorder(.secondary, lineWidth: 0.9)
                    .frame(width: 12.5, height: 10)
                front.strokeBorder(.secondary, lineWidth: 0.9)
                    .frame(width: 13, height: 10)
                    .offset(x: 3, y: 2.5)
            }
        }
        .frame(width: 16, height: 12.5, alignment: .topLeading)
    }

    private func colorOption(_ option: KaraokeTextColor) -> some View {
        Label {
            Text(option.title)
        } icon: {
            colorSwatch(option.color(customHex: karaokeCustomTextColorHex))
        }
        .tag(option)
    }

    @MainActor
    private func colorSwatch(_ style: some ShapeStyle) -> Image {
        let renderer = ImageRenderer(content: Circle().fill(style).frame(width: 14, height: 14))
        renderer.scale = 2
        guard let image = renderer.nsImage else {
            return Image(systemName: "circle.fill")
        }
        image.isTemplate = false
        return Image(nsImage: image).renderingMode(.original)
    }
}
