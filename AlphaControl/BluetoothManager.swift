import Foundation
import CoreBluetooth
import Combine

enum ConnectionStatus: String {
    case disconnected = "Disconnected"
    case scanning = "Scanning..."
    case connecting = "Connecting..."
    case connected = "Connected"
    case error = "Error"
}

struct DiscoveredDevice: Identifiable, Equatable {
    let id: UUID
    let name: String
    let peripheral: CBPeripheral
    let rssi: Int
    let isSonyCamera: Bool
    
    static func == (lhs: DiscoveredDevice, rhs: DiscoveredDevice) -> Bool {
        return lhs.id == rhs.id
    }
}

class BluetoothManager: NSObject, ObservableObject {
    @Published var connectionStatus: ConnectionStatus = .disconnected
    @Published var discoveredDevices: [DiscoveredDevice] = []
    @Published var isReadyToCapture: Bool = false
    @Published var statusMessage: String = "Disconnected"
    
    private var centralManager: CBCentralManager!
    private var connectedPeripheral: CBPeripheral?
    private var commandCharacteristic: CBCharacteristic?
    private var notifyCharacteristic: CBCharacteristic?
    
    // UUIDs from the protocol reference
    private let cameraServiceUUID = CBUUID(string: "8000FF00-FF00-FFFF-FFFF-FFFFFFFFFFFF")
    private let commandCharacteristicUUID = CBUUID(string: "8000FF01-FF00-FFFF-FFFF-FFFFFFFFFFFF")
    private let notifyCharacteristicUUID = CBUUID(string: "8000FF02-FF00-FFFF-FFFF-FFFFFFFFFFFF")
    
    // Command Constants (Little Endian uint16)
    private let cmdPressToFocus: UInt16 = 0x0701
    private let cmdHoldFocus: UInt16 = 0x0801
    private let cmdTakePicture: UInt16 = 0x0901
    private let cmdShutterReleased: UInt16 = 0x0601
    
    private let lastConnectedDeviceKey = "lastConnectedDeviceUUID"
    
    // Sony Camera Manufacturer Data Prefix (from C++ reference: CAMERA_MANUFACTURER_LOOKUP)
    private let sonyManufacturerDataPrefix: Data = Data([0x2D, 0x01, 0x03, 0x00])
    
    // State for Focus/Capture logic
    private var isFocusLocked: Bool = false
    private var pendingCapture: Bool = false
    
    override init() {
        super.init()
        centralManager = CBCentralManager(delegate: self, queue: nil)
    }
    
    func startScanning() {
        guard centralManager.state == .poweredOn else { return }
        print("Starting scan...")
        connectionStatus = .scanning
        discoveredDevices.removeAll()
        // Scanning for all devices since some cameras might not advertise the service UUID directly
        // or we want to be broad. We can filter by name if needed.
        centralManager.scanForPeripherals(withServices: nil, options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }
    
    func stopScanning() {
        centralManager.stopScan()
        if connectionStatus == .scanning {
            connectionStatus = .disconnected
        }
    }
    
    func connect(to device: DiscoveredDevice) {
        connect(to: device.peripheral)
    }
    
    func connect(to peripheral: CBPeripheral) {
        stopScanning()
        connectionStatus = .connecting
        connectedPeripheral = peripheral
        connectedPeripheral?.delegate = self
        centralManager.connect(peripheral, options: nil)
    }
    
    func disconnect() {
        if let peripheral = connectedPeripheral {
            centralManager.cancelPeripheralConnection(peripheral)
        }
        // Optional: Clear the saved device if the user manually disconnects? 
        // For now, we keep it remembered even if they disconnect manually, 
        // so they can easily reconnect later.
    }
    
    // MARK: - Camera Actions
    
    func startFocus() {
        guard let peripheral = connectedPeripheral, let characteristic = commandCharacteristic else {
            statusMessage = "Not connected"
            return
        }
        
        print("Start Focus")
        isFocusLocked = false
        pendingCapture = false
        statusMessage = "Focusing..."
        
        Task {
            await sendCommand(cmdPressToFocus, to: peripheral, characteristic: characteristic)
        }
    }
    
    func finishCapture() {
        guard let peripheral = connectedPeripheral, let characteristic = commandCharacteristic else { return }
        print("Finish Capture requested")
        
        if isFocusLocked {
            print("Focus is locked, capturing immediately.")
            performCapture(peripheral: peripheral, characteristic: characteristic)
        } else {
            print("Focus not locked yet. Pending capture...")
            statusMessage = "Waiting for focus..."
            pendingCapture = true
            
            // Timeout safety: If focus never locks, cancel pending capture after 3s
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
                guard let self = self else { return }
                if self.pendingCapture {
                    print("Capture timed out waiting for focus.")
                    self.statusMessage = "Focus Timeout"
                    self.pendingCapture = false
                    self.cancelCapture()
                }
            }
        }
    }
    
    private func performCapture(peripheral: CBPeripheral, characteristic: CBCharacteristic) {
        pendingCapture = false
        statusMessage = "Capturing..."
        
        Task {
            // 1. Take Picture
            await sendCommand(cmdTakePicture, to: peripheral, characteristic: characteristic)
            
            // Optional: Wait briefly for the camera to process (or wait for 0xA0 notification if we wanted to be strict)
            try? await Task.sleep(nanoseconds: 200 * 1_000_000)
            
            // 2. Reset Sequence
            // Reference: Release back to focus first, then fully release
            await sendCommand(cmdHoldFocus, to: peripheral, characteristic: characteristic)
            try? await Task.sleep(nanoseconds: 50 * 1_000_000)
            await sendCommand(cmdShutterReleased, to: peripheral, characteristic: characteristic)
            
            DispatchQueue.main.async {
                self.statusMessage = "Ready"
                self.isFocusLocked = false // Usually camera loses focus after shot
            }
        }
    }
    
    func cancelCapture() {
        guard let peripheral = connectedPeripheral, let characteristic = commandCharacteristic else { return }
        Task {
            await sendCommand(cmdShutterReleased, to: peripheral, characteristic: characteristic)
            DispatchQueue.main.async {
                self.statusMessage = "Ready"
            }
        }
    }
    
    private func sendCommand(_ command: UInt16, to peripheral: CBPeripheral, characteristic: CBCharacteristic) async {
        var value = command // Little endian by default on iOS (ARM) usually, but to be safe:
        let data = withUnsafeBytes(of: value.littleEndian) { Data($0) }
        
        peripheral.writeValue(data, for: characteristic, type: .withResponse)
    }
}

// MARK: - CBCentralManagerDelegate
extension BluetoothManager: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        if central.state == .poweredOn {
            print("Bluetooth is powered on")
            
            // Try to reconnect to the last known device
            if let uuidString = UserDefaults.standard.string(forKey: lastConnectedDeviceKey),
               let uuid = UUID(uuidString: uuidString) {
                
                let knownPeripherals = centralManager.retrievePeripherals(withIdentifiers: [uuid])
                if let lastDevice = knownPeripherals.first {
                    print("Found last connected device: \(lastDevice.name ?? "Unknown"). Reconnecting...")
                    connect(to: lastDevice)
                }
            }
            
        } else {
            print("Bluetooth is not available: \(central.state.rawValue)")
            connectionStatus = .error
        }
    }
    
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        let name = peripheral.name ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? "Unknown"
        
        var isSony: Bool = false
        if let manufacturerData = advertisementData[CBAdvertisementDataManufacturerDataKey] as? Data {
            if manufacturerData.starts(with: sonyManufacturerDataPrefix) {
                isSony = true
                print("Discovered a Sony Camera: \(name)")
            }
        }
        
        // Filter: Only show Sony cameras
        guard isSony else {
            print("Discovered non-Sony device: \(name)")
            return // Skip non-Sony devices
        }
        
        let device = DiscoveredDevice(id: peripheral.identifier, name: name, peripheral: peripheral, rssi: RSSI.intValue, isSonyCamera: isSony)
        
        if !discoveredDevices.contains(where: { $0.id == device.id }) {
            discoveredDevices.append(device)
            // Sort the devices, Sony devices will naturally be at the top if we had other types
            // For now, just sort by name within the filtered list.
            discoveredDevices.sort { $0.name < $1.name }
        }
    }
    
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "device")")
        
        // Save this device as the last connected one
        UserDefaults.standard.set(peripheral.identifier.uuidString, forKey: lastConnectedDeviceKey)
        
        connectionStatus = .connected
        peripheral.discoverServices([cameraServiceUUID])
    }
    
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Failed to connect: \(error?.localizedDescription ?? "Unknown error")")
        connectionStatus = .error
    }
    
    func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        print("Disconnected")
        connectionStatus = .disconnected
        connectedPeripheral = nil
        commandCharacteristic = nil
        notifyCharacteristic = nil
        isReadyToCapture = false
        isFocusLocked = false
        pendingCapture = false
    }
}

// MARK: - CBPeripheralDelegate
extension BluetoothManager: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else { return }
        
        for service in services {
            print("Service found: \(service.uuid)")
            if service.uuid == cameraServiceUUID {
                print("Discovered Camera Service")
                DispatchQueue.main.async {
                    self.statusMessage = "Discovering characteristics..."
                }
                // Discover ALL characteristics to ensure we see what's available
                peripheral.discoverCharacteristics(nil, for: service)
            }
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        guard let characteristics = service.characteristics else { return }
        
        for characteristic in characteristics {
            print("Characteristic found: \(characteristic.uuid) (String: \(characteristic.uuid.uuidString))")
            
            // Match against 128-bit UUID OR the short 16-bit string (FF01/FF02)
            if characteristic.uuid == commandCharacteristicUUID || characteristic.uuid.uuidString == "FF01" {
                print("Found Command Characteristic")
                commandCharacteristic = characteristic
            } else if characteristic.uuid == notifyCharacteristicUUID || characteristic.uuid.uuidString == "FF02" {
                print("Found Notify Characteristic")
                notifyCharacteristic = characteristic
                peripheral.setNotifyValue(true, for: characteristic)
            }
        }
        
        if commandCharacteristic != nil && notifyCharacteristic != nil {
            print("All required characteristics found. Ready.")
            DispatchQueue.main.async {
                self.isReadyToCapture = true
                self.statusMessage = "Ready to Capture"
            }
        } else {
             print("Missing characteristics. Found: Cmd: \(commandCharacteristic != nil), Notify: \(notifyCharacteristic != nil)")
        }
    }
    
    func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        if characteristic.uuid == notifyCharacteristicUUID || characteristic.uuid.uuidString == "FF02", let data = characteristic.value {
            // Handle notifications based on reference protocol
            // Format: 0x02 [Type] [Value]
            if data.count >= 3 && data[0] == 0x02 {
                let type = data[1]
                let value = data[2]
                
                DispatchQueue.main.async {
                    if type == 0x3F { // Focus Status
                        if value == 0x20 {
                            print("Focus Acquired")
                            self.isFocusLocked = true
                            // If user already released the button, trigger capture now
                            if self.pendingCapture {
                                print("Pending capture triggered by Focus Lock.")
                                if let p = self.connectedPeripheral, let c = self.commandCharacteristic {
                                    self.performCapture(peripheral: p, characteristic: c)
                                }
                            }
                        } else {
                            print("Focus Lost/Ready")
                            self.isFocusLocked = false
                        }
                    } else if type == 0xA0 { // Shutter Status
                        if value == 0x20 {
                            print("Shutter Active")
                        } else {
                            print("Shutter Ready")
                        }
                    }
                }
            }
        }
    }
}