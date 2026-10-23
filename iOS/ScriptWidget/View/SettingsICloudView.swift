//
//  SettingsICloudView.swift
//  ScriptWidget
//
//  Created by everettjf on 2021/2/27.
//

import SwiftUI

struct SettingsICloudView: View {
    @State private var showingLibraries = false
    @ObservedObject private var library = ScriptWidgetLibraryLaunchModel.shared

    var body: some View {
        VStack(alignment: .leading, spacing: StudioDesign.standardSpacing) {
            Label(sharedScriptManager.isUsingiCloud ? "iCloud Drive" : "On This Device",
                  systemImage: sharedScriptManager.isUsingiCloud ? "icloud.fill" : "internaldrive")
                .font(.subheadline.weight(.semibold))
            if let path = library.selectedRootPath {
                Text(path).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
            }
            Button("Choose Widget Library") { showingLibraries = true }.buttonStyle(.bordered)
            if sharedScriptManager.isUsingiCloud {
                CountDownButton(text: "Sync from iCloud", waitSeconds: 10) {
                    sharedScriptManager.requestUpdateICloudScripts()
                }.buttonStyle(.bordered)
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .sheet(isPresented: $showingLibraries) { ScriptWidgetLibrarySelectionView(model: library) }
    }
}

#Preview("iCloud Settings") {
    SettingsICloudView()
        .padding()
}

#Preview("iCloud Settings · Dark") {
    SettingsICloudView()
        .padding()
        .preferredColorScheme(.dark)
}
