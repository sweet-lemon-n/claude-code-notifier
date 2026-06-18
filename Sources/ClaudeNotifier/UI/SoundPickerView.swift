import SwiftUI
import AppKit

/// A picker for selecting a system sound (or custom file), with an inline preview button.
struct SoundPickerView: View {
    let label: String
    @Binding var selection: String
    @ObservedObject var settings: SettingsStore

    @State private var showFilePicker = false

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .frame(width: 100, alignment: .trailing)

            Picker("", selection: $selection) {
                ForEach(SoundManager.systemSounds, id: \.self) { name in
                    Text(name).tag(name)
                }
                Divider()
                Text("Custom...").tag("__custom__")
            }
            .frame(width: 160)
            .onChange(of: selection) { _, newValue in
                if newValue != "__custom__" {
                    SoundManager(settings: settings).preview(name: newValue)
                }
            }

            if selection == "__custom__" {
                Button("Choose...") {
                    showFilePicker = true
                }
                .buttonStyle(.link)
                if !settings.customSoundPath.isEmpty {
                    Text("✓ Set").foregroundColor(.green).font(.caption)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.aiff, .wav, .mp3, .mpeg4Audio],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                let didStart = url.startAccessingSecurityScopedResource()
                settings.customSoundPath = url.path
                if didStart { url.stopAccessingSecurityScopedResource() }
            }
        }
    }
}
