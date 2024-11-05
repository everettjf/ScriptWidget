import SwiftUI

struct ImportView: View {
    @State private var isImporting = false
    
    var body: some View {
        VStack(spacing: 20) {
            // Import button and progress bar
            VStack {
                Button(action: {
                    isImporting.toggle()
                }) {
                    Text("Import")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(15)
                }
                .padding(.horizontal, 20)
                
                if isImporting {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))
                        .scaleEffect(1.5)
                        .padding(.top, 10)
                }
            }
        }
        .padding()
    }
    
    
}

struct ImportView_Previews: PreviewProvider {
    static var previews: some View {
        ImportView()
    }
}
