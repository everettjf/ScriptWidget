import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var model: CompareModel
    @State private var search = ""

    private var filtered: [Repository.Entry] {
        search.isEmpty ? model.entries : model.entries.filter { $0.id.localizedCaseInsensitiveContains(search) }
    }

    var body: some View {
        NavigationSplitView {
            List(filtered, selection: $model.selection) { entry in
                Text(entry.id).lineLimit(1).truncationMode(.middle).tag(entry.id)
            }
            .searchable(text: $search, placement: .sidebar)
            .navigationSplitViewColumnWidth(min: 220, ideal: 280)
        } detail: {
            ScrollView([.horizontal, .vertical]) {
            VStack(spacing: 16) {
                HStack(alignment: .top, spacing: 24) {
                    pane("macOS native", image: model.comparison.native, error: model.comparison.nativeError, milliseconds: model.comparison.nativeMilliseconds)
                    pane("Web engine", image: model.comparison.web, error: model.comparison.webError, milliseconds: model.comparison.webMilliseconds)
                    pane(model.comparison.percent.map { String(format: "Difference %.2f%%", $0) } ?? "Difference", image: model.comparison.diff, error: nil, milliseconds: nil)
                }
                if !model.comparison.diagnostics.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(Array(model.comparison.diagnostics.enumerated()), id: \.offset) { _, message in
                            Label(message, systemImage: "exclamationmark.triangle").font(.callout).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .overlay { if model.busy { ProgressView().controlSize(.small).padding().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing) } }
            .toolbar {
                Picker("Size", selection: $model.family) {
                    ForEach(PreviewFamily.allCases) { Text($0.rawValue.capitalized).tag($0) }
                }
                .pickerStyle(.segmented)
                Toggle(isOn: $model.dark) { Label("Dark", systemImage: "moon") }
                Button { model.refresh() } label: { Label("Render Again", systemImage: "arrow.clockwise") }
                    .keyboardShortcut("r")
                Button { model.openFolder() } label: { Label("Open Package Folder", systemImage: "folder") }
            }
        }
        .navigationTitle(model.selectedEntry?.id ?? "ScriptWidget Preview")
        .onChange(of: model.selection) { model.refresh() }
        .onChange(of: model.family) { model.refresh() }
        .onChange(of: model.dark) { model.refresh() }
        .onAppear { if model.selection == nil { model.selection = model.entries.first?.id } }
    }

    private func pane(_ title: String, image: CGImage?, error: String?, milliseconds: Double?) -> some View {
        VStack(spacing: 8) {
            Text(title).font(.headline)
            Group {
                if let image {
                    Image(decorative: image, scale: 2).clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 2)
                } else if let error {
                    Text(error).font(.callout).foregroundStyle(.red).frame(width: model.family.size.width).multilineTextAlignment(.leading)
                } else {
                    Color.clear.frame(width: model.family.size.width, height: model.family.size.height)
                }
            }
            if let milliseconds { Text(String(format: "%.0f ms", milliseconds)).font(.caption).foregroundStyle(.secondary) }
        }
    }
}
