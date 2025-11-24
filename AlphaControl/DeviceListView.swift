import SwiftUI

struct DeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @Binding var isPresented: Bool
    
    var body: some View {
        NavigationView {
            List {
                if let connectedName = bluetoothManager.connectedDeviceName, bluetoothManager.connectionStatus == .connected {
                    Section(header: Text("Connected Device")) {
                        HStack {
                            Text(connectedName)
                                .font(.headline)
                                .foregroundColor(.green)
                            Spacer()
                            Button("Disconnect") {
                                bluetoothManager.disconnect()
                            }
                            .foregroundColor(.red)
                            .buttonStyle(BorderedButtonStyle())
                        }
                    }
                }
                
                Section(header: Text("Discovered Devices")) {
                    if bluetoothManager.discoveredDevices.isEmpty {
                        if bluetoothManager.connectionStatus == .scanning {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .padding(.trailing, 10)
                                Text("Scanning...")
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                        } else {
                            Text("No devices found")
                                .foregroundColor(.gray)
                        }
                    } else {
                        ForEach(bluetoothManager.discoveredDevices) { device in
                            Button(action: {
                                bluetoothManager.connect(to: device)
                                isPresented = false
                            }) {
                                HStack {
                                    Text(device.name)
                                        .font(.headline)
                                    Spacer()
                                    if device.rssi != 0 {
                                        Text("\(device.rssi) dBm")
                                            .font(.subheadline)
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Cameras")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bluetoothManager.connectionStatus == .scanning {
                        Button("Stop") {
                            bluetoothManager.stopScanning()
                        }
                    } else {
                        Button("Scan") {
                            bluetoothManager.startScanning()
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                if bluetoothManager.connectionStatus != .connected {
                    bluetoothManager.startScanning()
                }
            }
        }
    }
}