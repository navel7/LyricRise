//
//  KaraokeSettings.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-02-08.
//

import SwiftUI
import AppKit
import FontPicker

enum KaraokeTextColor: String, CaseIterable {
    case automatic, blue, purple, pink, red, orange, yellow, green, graphite, custom

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
        return String(localized: "\(seconds) s earlier")
    }
    
    var colorBinding: Binding<Color> {
        Binding<Color> {
            Color(NSColor(hexString: fixedKaraokeColorHex)!)
        } set: { newValue in
            fixedKaraokeColorHex = NSColor(newValue).hexString!
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            @Bindable var viewmodel = viewmodel
            Text("Karaoke Behaviour")
                .font(.system(size: 15, weight: .bold))
            Toggle(isOn: $karaokeModeHoveringSetting) {
                Text("Hide Karaoke window when mouse passes by")
            }
            .toggleStyle(.checkbox)
            Toggle(isOn: $karaokeShowMultilingual) {
                Text("Show multilingual lyrics when translating in Karaoke window")
            }
            .toggleStyle(.checkbox)
            .padding(.bottom, 20)
            
            Text("Karaoke and menu bar lyric timing: \(timingDescription)")
            HStack {
                Text("Earlier")
                Slider(value: $karaokeTimingAdjustment, in: -2...0, step: 0.25)
                    .accessibilityLabel("Karaoke and menu bar lyric timing")
                    .accessibilityValue(timingDescription)
                Text("Original")
            }
            .frame(width: 300)
            .padding(.bottom, 20)

            Text("Karaoke Background Appearance")
                    .font(.system(size: 15, weight: .bold))
            
            Toggle(isOn: $karaokeUseAlbumColor) {
                Text("Use album color for Karaoke window")
            }
            .toggleStyle(.checkbox)
            if !karaokeUseAlbumColor {
                ColorPicker("Set a background color", selection: colorBinding, supportsOpacity: false)
            }
            Text("Opacity Level")
            HStack {
                Image(systemName: "circle")
                    .accessibilityHidden(true)

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
                Slider(value: $karaokeTransparency, in: 1...100, step: 5)
                    .accessibilityLabel("Opacity Level")
                    .accessibilityValue("\(Int(karaokeTransparency)) percent")
                Image(systemName: "circle.fill")
                    .accessibilityHidden(true)
            }
            .frame(width: 300, height: 24)
            .padding(.bottom, 20)
            
            Text("Karaoke Font Appearance")
//                .bold()
                .font(.system(size: 15, weight: .bold))
            FontPicker("Select a Font:", selection: $viewmodel.karaokeFont)
                .frame(height: 30)
                .buttonStyle(.bordered)
            Text("Font Selected: \(viewmodel.karaokeFont.displayName ?? ""), Size: \(Int(viewmodel.karaokeFont.pointSize))")
                .font(.custom(viewmodel.karaokeFont.fontName, size: 13))
            
            .frame(width: 300, height: 24)
            Button("Reset to default") {
                viewmodel.userDefaultStorage.karaokeModeHoveringSetting = false
                karaokeUseAlbumColor = true
                karaokeTimingAdjustment = -0.5
                viewmodel.userDefaultStorage.karaokeShowMultilingual = true
                viewmodel.userDefaultStorage.karaokeTransparency = 50
                viewmodel.karaokeFont = NSFont.boldSystemFont(ofSize: 30)
            HStack {
                Picker("Karaoke Text Color", selection: $karaokeTextColor) {
                    Label {
                        Text(KaraokeTextColor.automatic.title)
                    } icon: {
                        colorSwatch(LinearGradient(colors: [.blue, .pink, .orange], startPoint: .leading, endPoint: .trailing))
                    }
                    .tag(KaraokeTextColor.automatic)
                    Divider()
                    ForEach(KaraokeTextColor.allCases.filter { $0 != .automatic && $0 != .custom }, id: \.self) { option in
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
//                viewmodel.karaokeFontSize = 30
                colorBinding.wrappedValue = Color(.sRGB, red: 0.98, green: 0.0, blue: 0.98)
                
            }
            Spacer()
        }
//        .padding(.vertical, 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.bouncy, value: karaokeUseAlbumColor)
        .padding(.horizontal)
        .padding(.top, 100)
    }
}
                karaokeTextColor = .automatic
                karaokeCustomTextColorHex = "#FFFFFF"
