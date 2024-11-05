//
//  ImportExportManager.swift
//  ScriptWidget
//
//  Created by eevv on 11/5/24.
//
//

import Foundation
import ZipArchive

class ExportManager {
    static func exportAllScripts(progressCallback: @escaping (Float, String) -> Void) async throws -> URL {
        // Create a temporary directory for exporting scripts
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("scriptwidget-export-all")
        let zipFilePath = FileManager.default.temporaryDirectory.appendingPathComponent("scriptwidget-export-all.zip")
        
        // Remove existing temp directory and zip file if they exist
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.removeItem(at: zipFilePath)
        
        // Create the temporary directory
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
        
        // List all scripts
        let scripts = await sharedScriptManager.asyncListScripts()
        let totalScripts = Float(scripts.count)
        
        // Export each script to the temporary directory
        for (index, script) in scripts.enumerated() {
            let scriptPath = tempDir.appendingPathComponent(script.name)
            let succeed = sharedScriptManager.exportScript(model: script, toPath: scriptPath)
            
            // Update progress with script name
            let progress = Float(index + 1) / totalScripts
            await MainActor.run {
                progressCallback(progress * 0.9, "Exporting: \(script.name)") // 90% of progress for exporting scripts
            }
        }
        
        // Create zip file from the temporary directory
        await MainActor.run {
            progressCallback(0.95, "Creating zip file") // 95% progress when starting zip creation
        }
        let success = SSZipArchive.createZipFile(atPath: zipFilePath.path, withContentsOfDirectory: tempDir.path)
        
        if success {
            // Remove the temporary directory
            try? FileManager.default.removeItem(at: tempDir)
            
            // Final progress update
            await MainActor.run {
                progressCallback(1.0, "Export completed")
            }
            
            return zipFilePath
        } else {
            throw NSError(domain: "ExportManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to create zip file"])
        }
    }
}
