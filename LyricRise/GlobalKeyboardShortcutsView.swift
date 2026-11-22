//
//  GlobalKeyboardShortcutsView.swift
//  LyricRise
//
//  Created by Avi Wadhwa on 2025-09-11.
//

import AppKit
import SwiftUI
import KeyboardShortcuts

struct GlobalKeyboardShortcutsView: View {
    var body: some View {
        Form {
            Section {
                shortcutRow("Toggle karaoke mode", name: "karaoke")
                shortcutRow("Toggle displaying lyrics", name: "lyrics")
                shortcutRow("Toggle translations", name: "translate")
                shortcutRow("Toggle romanizations", name: "romanize")
                shortcutRow("Display fullscreen", name: "fullscreen")
            }
        }
        .formStyle(.grouped)
    }

    private func shortcutRow(_ title: LocalizedStringKey, name: String) -> some View {
        LabeledContent(title) {
            ShortcutRecorder(name: .init(name))
                .accessibilityLabel(Text(title))
        }
    }
}

private struct ShortcutRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name

    final class Coordinator {
        var monitor: Any?
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        let recorder = KeyboardShortcuts.RecorderCocoa(for: name)
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak recorder] event in
            guard let recorder, let window = recorder.window,
                  event.window === window, !recorder.isHiddenOrHasHiddenAncestor,
                  recorder.isEnabled, window.isKeyWindow,
                  let contentView = window.contentView,
                  let hitView = contentView.hitTest(contentView.superview?.convert(event.locationInWindow, from: nil) ?? event.locationInWindow)
            else { return event }

            let point = recorder.convert(event.locationInWindow, from: nil)
            let hitRecorder = hitView === recorder || hitView.isDescendant(of: recorder)
            let hitEditor = recorder.currentEditor().map { hitView === $0 || hitView.isDescendant(of: $0) } ?? false
            guard hitRecorder || hitEditor, recorder.visibleRect.contains(point)
            else { return event }

            let clickedClear = (recorder.cell as? NSSearchFieldCell).map {
                $0.cancelButtonCell != nil && $0.cancelButtonRect(forBounds: recorder.bounds).contains(point)
            } ?? false

            if recorder.currentEditor() != nil {
                guard window.makeFirstResponder(nil) else { return event }
            }
            if clickedClear {
                KeyboardShortcuts.setShortcut(nil, for: recorder.shortcutName)
                return nil
            }

            return window.makeFirstResponder(recorder) ? nil : event
        }
        return recorder
    }

    func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {
        recorder.shortcutName = name
    }

    static func dismantleNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
