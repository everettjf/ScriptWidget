import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @State private var isExporting = false
    @State private var exportSucceeded = false
    @State private var progress: Float = 0
    @State private var statusMessage = ""
    @State private var logMessages: [String] = []
    @State private var exportedFileURL: URL?
    @State private var showShareSheet = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Export button and progress bar
            VStack {
                Button(action: {
                    startExport()
                }) {
                    Text("Export")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(isExporting || exportSucceeded ? Color.gray : Color.blue) // Change background color when disabled
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                .disabled(isExporting || exportSucceeded)
                
                // Always show progress view
                ProgressView(value: progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .scaleEffect(1.5)
                    .padding(.top, 10)
                
                Text(statusMessage)
                    .font(.caption)
                    .padding(.top, 5)
            }
            
            // Move log list outside the VStack and increase its height
            List {
                ForEach(logMessages, id: \.self) { message in
                    Text(message)
                        .font(.caption)
                }
            }
            .frame(maxHeight: .infinity) // Allow the list to expand and fill available space
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
        }
        .padding()
        .sheet(isPresented: $showShareSheet, content: {
            if let fileURL = exportedFileURL {
                ActivityViewController(activityItems: [fileURL])
            }
        })
    }
    
    private func startExport() {
        isExporting = true
        exportSucceeded = false
        progress = 0
        statusMessage = "Starting export..."
        logMessages.removeAll() // Clear previous log messages
        
        Task {
            do {
                let zipFileURL = try await ExportManager.exportAllScripts { currentProgress, message in
                    DispatchQueue.main.async {
                        self.progress = currentProgress
                        self.statusMessage = message
                        self.logMessages.insert(message, at: 0) // Insert new message at the beginning
                    }
                }
                
                DispatchQueue.main.async {
                    self.exportedFileURL = zipFileURL
                    self.showShareSheet = true
                    self.isExporting = false
                    self.exportSucceeded = true
                    self.statusMessage = "Export completed successfully"
                    self.logMessages.insert("Export completed successfully", at: 0) // Insert final message at the beginning
                }
            } catch {
                DispatchQueue.main.async {
                    self.isExporting = false
                    self.exportSucceeded = false
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.logMessages.insert("Error: \(error.localizedDescription)", at: 0) // Insert error message at the beginning
                }
            }
        }
    }
}

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct ExportView_Previews: PreviewProvider {
    static var previews: some View {
        ExportView()
    }
}
