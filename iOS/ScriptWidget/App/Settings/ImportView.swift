import SwiftUI
import UniformTypeIdentifiers

struct ImportView: View {
    @State private var isImporting = false
    @State private var importSucceeded = false
    @State private var showFilePicker = false
    @State private var progress: Float = 0
    @State private var statusMessage = ""
    @State private var logMessages: [String] = []
    
    var body: some View {
        VStack(spacing: 20) {
            // Import button and progress bar
            VStack {
                Button(action: {
                    showFilePicker = true
                }) {
                    Text("Import")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isImporting || importSucceeded ? Color.gray : Color.green)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                .disabled(isImporting || importSucceeded)
                
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .green))
                    .scaleEffect(1.5)
                    .padding(.top, 10)
                
                Text(statusMessage)
                    .font(.caption)
                    .padding(.top, 5)
            }
            
            // Modify the log list to take up more space
            List {
                ForEach(logMessages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                }
            }
            .frame(maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let files):
                if let file = files.first {
                    importFile(file)
                }
            case .failure(let error):
                print("Error selecting file: \(error.localizedDescription)")
            }
        }
    }
    
    private func importFile(_ file: URL) {
        isImporting = true
        importSucceeded = false
        progress = 0
        statusMessage = "Starting import..."
        logMessages.removeAll()
        
        Task {
            do {
                try await ImportManager.importScripts(from: file) { currentProgress, message in
                    DispatchQueue.main.async {
                        self.progress = currentProgress
                        self.statusMessage = message
                        self.logMessages.insert(message, at: 0)
                    }
                }
                
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.importSucceeded = true
                    self.statusMessage = "Import completed successfully"
                    self.logMessages.insert("Import completed successfully", at: 0)
                }
            } catch {
                DispatchQueue.main.async {
                    self.isImporting = false
                    self.importSucceeded = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.logMessages.insert("Error: \(error.localizedDescription)", at: 0)
                }
            }
        }
    }
}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView()
    }
}
