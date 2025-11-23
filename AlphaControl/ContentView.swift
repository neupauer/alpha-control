import SwiftUI

struct ContentView: View {
    @StateObject var bluetoothManager = BluetoothManager()
    
    var body: some View {
        if bluetoothManager.connectionStatus == .connected {
            CameraControlView(bluetoothManager: bluetoothManager)
        } else {
            DeviceListView(bluetoothManager: bluetoothManager)
        }
    }
}