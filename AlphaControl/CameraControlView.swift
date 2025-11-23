import SwiftUI

struct CameraControlView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text(bluetoothManager.statusMessage)
                .font(.title2)
                .foregroundColor(.gray)
            
            Button(action: {
                bluetoothManager.triggerShutter()
            }) {
                Label("Trigger Shutter", systemImage: "camera.shutter.button")
                    .font(.title2)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(!bluetoothManager.isReadyToCapture)
            
            Spacer()
            
            Button("Disconnect") {
                bluetoothManager.disconnect()
            }
            .foregroundColor(.red)
            .padding()
        }
        .padding()
    }
}
