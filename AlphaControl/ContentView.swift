import SwiftUI

struct ContentView: View {
    @StateObject var bluetoothManager = BluetoothManager()
    @State private var showDeviceList = false
    
    var body: some View {
        ZStack {
            Color.black.edgesIgnoringSafeArea(.all)
            
            VStack {
                // Top Bar: Device Selector
                Button(action: {
                    showDeviceList = true
                }) {
                    HStack(spacing: 10) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 18))
                        Text(bluetoothManager.connectedDeviceName ?? "Select Camera")
                            .font(.headline)
                            .fontWeight(.semibold)
                        Image(systemName: "chevron.down")
                            .font(.caption)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.systemGray6).opacity(0.2))
                    .cornerRadius(30)
                }
                .padding(.top, 60)
                
                Spacer()
                
                // Status Indicator
                if bluetoothManager.connectionStatus == .connected {
                    Text(bluetoothManager.statusMessage)
                        .font(.system(size: 16, weight: .medium, design: .monospaced))
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                } else {
                    Text("Tap 'Select Camera' to connect")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .padding(.bottom, 20)
                }
                
                // Big Shutter Button Area
                ShutterButton(bluetoothManager: bluetoothManager)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 50)
            }
        }
        .sheet(isPresented: $showDeviceList) {
            DeviceListView(bluetoothManager: bluetoothManager, isPresented: $showDeviceList)
        }
        .preferredColorScheme(.dark)
    }
}

struct ShutterButton: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isPressed = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background of the button (Trackpad style)
                RoundedRectangle(cornerRadius: 40)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color(UIColor.systemGray5).opacity(0.3), Color(UIColor.systemGray6).opacity(0.1)]),
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                
                // Pressed State Overlay
                if isPressed {
                    RoundedRectangle(cornerRadius: 40)
                        .fill(Color.white.opacity(0.1))
                }
                
                // Icon / Text
                VStack(spacing: 15) {
                    Image(systemName: "camera.shutter.button.fill")
                        .font(.system(size: 60))
                        .foregroundColor(isPressed ? .white : .white.opacity(0.8))
                        .scaleEffect(isPressed ? 0.9 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isPressed)
                    
                    Text(isPressed ? "RELEASE TO SHOOT" : "PRESS TO FOCUS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .tracking(2)
                        .foregroundColor(.gray)
                }
            }
            // Make it fill the available height in the parent's frame allocation, or a fixed aspect ratio
            // The user asked for a "big button".
            .frame(height: geometry.size.width * 1.2) // Rectangular, taller than wide
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isPressed && bluetoothManager.isReadyToCapture {
                            isPressed = true
                            let generator = UIImpactFeedbackGenerator(style: .medium)
                            generator.impactOccurred()
                            bluetoothManager.startFocus()
                        }
                    }
                    .onEnded { _ in
                        if isPressed {
                            isPressed = false
                            let generator = UIImpactFeedbackGenerator(style: .heavy)
                            generator.impactOccurred()
                            bluetoothManager.finishCapture()
                        }
                    }
            )
            .opacity(bluetoothManager.isReadyToCapture ? 1.0 : 0.5)
            .animation(.easeInOut, value: bluetoothManager.isReadyToCapture)
        }
        .frame(height: 400) // Provide a constrained height for the GeometryReader
    }
}