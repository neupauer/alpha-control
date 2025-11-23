import SwiftUI

struct CameraControlView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isPressed = false
    
    var body: some View {
        VStack(spacing: 40) {
            Spacer()
            
            Text(bluetoothManager.statusMessage)
                .font(.title2)
                .foregroundColor(.gray)
                .frame(height: 30) // Fixed height to prevent jump
            
            // Custom Gesture Button
            ZStack {
                Circle()
                    .fill(isPressed ? Color.red.opacity(0.8) : Color.red)
                    .frame(width: 150, height: 150)
                    .shadow(radius: isPressed ? 5 : 10)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                Circle()
                    .stroke(Color.white, lineWidth: 5)
                    .frame(width: 140, height: 140)
                    .scaleEffect(isPressed ? 0.95 : 1.0)
                
                VStack {
                    Image(systemName: "camera.shutter.button")
                        .font(.system(size: 50))
                        .foregroundColor(.white)
                    Text(isPressed ? "Focusing..." : "Shoot")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 5)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed {
                            isPressed = true
                            bluetoothManager.startFocus()
                        }
                    }
                    .onEnded { _ in
                        isPressed = false
                        bluetoothManager.finishCapture()
                    }
            )
            .disabled(!bluetoothManager.isReadyToCapture)
            .opacity(bluetoothManager.isReadyToCapture ? 1.0 : 0.5)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
            
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