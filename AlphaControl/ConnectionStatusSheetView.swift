import SwiftUI

struct ConnectionStatusSheetView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: systemIconName())
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 80, height: 80)
                .foregroundColor(iconColor())
            
            Text(bluetoothManager.statusMessage)
                .font(.title2)
                .fontWeight(.semibold)
                .padding(.top, 10)
            
            if bluetoothManager.connectionStatus == .connecting {
                ProgressView()
                    .progressViewStyle(.circular)
                    .padding(.top, 5)
            }
            
            Spacer()
            
            Button("Cancel") {
                bluetoothManager.disconnect()
                dismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .tint(.red)
            .padding(.bottom)
        }
        .padding()
        .onChange(of: bluetoothManager.connectionStatus) { newStatus in
            if newStatus == .connected || newStatus == .disconnected || newStatus == .error {
                // Allow some time for the user to read status before dismissing
                // For .connected, the ContentView will transition, so no dismiss here
                // For .disconnected or .error, dismiss after a short delay
                if newStatus == .disconnected || newStatus == .error {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func systemIconName() -> String {
        switch bluetoothManager.connectionStatus {
        case .connecting: return "antenna.radiowaves.left.and.right"
        case .connected: return "checkmark.circle.fill"
        case .disconnected: return "bolt.slash.fill"
        case .scanning: return "magnifyingglass"
        case .error: return "xmark.octagon.fill"
        }
    }
    
    private func iconColor() -> Color {
        switch bluetoothManager.connectionStatus {
        case .connecting: return .blue
        case .connected: return .green
        case .disconnected: return .gray
        case .scanning: return .blue
        case .error: return .red
        }
    }
}
