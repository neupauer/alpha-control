import SwiftUI

struct DeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    @State private var isShowingConnectionSheet = false
    
    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Devices")) {
                    if bluetoothManager.discoveredDevices.isEmpty {
                        Text("No devices found")
                            .foregroundColor(.gray)
                    } else {
                        ForEach(bluetoothManager.discoveredDevices) { device in
                            Button(action: {
                                bluetoothManager.connect(to: device)
                                isShowingConnectionSheet = true
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
            .navigationTitle("Scanner")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if bluetoothManager.connectionStatus == .scanning {
                        ProgressView()
                    } else {
                        Button("Scan") {
                            bluetoothManager.startScanning()
                        }
                    }
                }
            }
            .onAppear {
                bluetoothManager.startScanning()
            }
            .sheet(isPresented: $isShowingConnectionSheet) {
                ConnectionStatusSheetView(bluetoothManager: bluetoothManager)
            }
            .onChange(of: bluetoothManager.connectionStatus) { newStatus in
                // Automatically dismiss the sheet if connected, or after a delay if disconnected/error
                if newStatus == .connected {
                    isShowingConnectionSheet = false // ContentView will handle navigation
                } else if newStatus == .disconnected || newStatus == .error {
                    // Give user time to see the status, then dismiss
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        isShowingConnectionSheet = false
                    }
                }
            }
        }
    }
}
