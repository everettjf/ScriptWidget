import SwiftUI
import UniformTypeIdentifiers

struct ExportView: View {
    @State private var isExporting = false
    @State private var progress: Float = 0
    @State private var statusMessage = ""
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
                        .background(Color.blue)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                .disabled(isExporting)
                
                if isExporting {
                    VStack {
                        ProgressView(value: progress)
                            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                            .scaleEffect(1.5)
                            .padding(.top, 10)
                        
                        Text(statusMessage)
                            .font(.caption)
                            .padding(.top, 5)
                    }
                }
            }
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
        progress = 0
        statusMessage = "Starting export..."
        
        Task {
            do {
                let zipFileURL = try await ExportManager.exportAllScripts { currentProgress, message in
                    DispatchQueue.main.async {
                        self.progress = currentProgress
                        self.statusMessage = message
                    }
                }
                
                DispatchQueue.main.async {
                    self.exportedFileURL = zipFileURL
                    self.showShareSheet = true
                    self.isExporting = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.statusMessage = "Error: \(error.localizedDescription)"
                    self.isExporting = false
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

// End of file. No additional code.
