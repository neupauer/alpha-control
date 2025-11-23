import SwiftUI

struct DeviceListView: View {
    @ObservedObject var bluetoothManager: BluetoothManager
    
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
        }
    }
}
