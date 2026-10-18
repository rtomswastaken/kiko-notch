import Foundation
import IOBluetooth

public struct BluetoothPeripheral: Sendable, Identifiable, Equatable {
    public let id: String
    public let name: String
    public let isConnected: Bool
    public let batteryLevel: Int?
    
    public init(id: String, name: String, isConnected: Bool, batteryLevel: Int? = nil) {
        self.id = id
        self.name = name
        self.isConnected = isConnected
        self.batteryLevel = batteryLevel
    }
}

/// IOBluetooth peripheral monitoring and connect/disconnect events.
/// Implements BT-001 and BT-002.
public final class BluetoothMonitor: ObservableObject, @unchecked Sendable {
    public static let shared = BluetoothMonitor()
    
    @Published public private(set) var connectedDevices: [BluetoothPeripheral] = []
    public var onDevicesUpdated: (@Sendable ([BluetoothPeripheral]) -> Void)?
    public var onDeviceConnectionChanged: (@Sendable (String, Bool, Int?) -> Void)?
    
    private var isMonitoring: Bool = false
    private var knownDevices: [String: Bool] = [:]
    
    public init() {}
    
    public func start() {
        guard !isMonitoring else { return }
        isMonitoring = true
        
        // Register for IOBluetooth connection notifications
        IOBluetoothDevice.register(
            forConnectNotifications: self,
            selector: #selector(deviceConnectedNotification(_:fromDevice:))
        )
        
        // Initial scan
        refreshConnectedDevices()
    }
    
    public func stop() {
        guard isMonitoring else { return }
        isMonitoring = false
    }
    
    @objc private func deviceConnectedNotification(_ notification: IOBluetoothUserNotification, fromDevice device: IOBluetoothDevice) {
        let name = device.nameOrAddress ?? "Bluetooth Device"
        let address = device.addressString ?? UUID().uuidString
        knownDevices[address] = true
        
        let battery = queryBatteryLevel(for: device)
        onDeviceConnectionChanged?(name, true, battery)
        refreshConnectedDevices()
    }
    
    public func refreshConnectedDevices() {
        guard let paired = IOBluetoothDevice.pairedDevices() as? [IOBluetoothDevice] else {
            onDevicesUpdated?([])
            return
        }
        
        var list: [BluetoothPeripheral] = []
        for device in paired {
            guard device.isConnected() else { continue }
            let name = device.nameOrAddress ?? "Unknown Device"
            let id = device.addressString ?? UUID().uuidString
            let battery = queryBatteryLevel(for: device)
            
            list.append(BluetoothPeripheral(
                id: id,
                name: name,
                isConnected: true,
                batteryLevel: battery
            ))
            
            // Check if newly connected
            if knownDevices[id] != true {
                knownDevices[id] = true
                onDeviceConnectionChanged?(name, true, battery)
            }
        }
        
        // Check for disconnections
        for (id, wasConnected) in knownDevices where wasConnected {
            if !list.contains(where: { $0.id == id }) {
                knownDevices[id] = false
                let name = paired.first(where: { $0.addressString == id })?.nameOrAddress ?? "Bluetooth Device"
                onDeviceConnectionChanged?(name, false, nil)
            }
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.connectedDevices = list
        }
        onDevicesUpdated?(list)
    }
    
    private func queryBatteryLevel(for device: IOBluetoothDevice) -> Int? {
        // macOS reads battery percent for Apple Bluetooth accessories via IORegistry or private property
        // Fallback safely to nil if not reported
        return nil
    }
    
    /// Test helper for simulation in tests or virtual machines without Bluetooth hardware
    public func setSimulatedDevices(_ devices: [BluetoothPeripheral]) {
        DispatchQueue.main.async { [weak self] in
            self?.connectedDevices = devices
        }
        onDevicesUpdated?(devices)
    }
    
    public func simulateDeviceEvent(name: String, isConnected: Bool, batteryLevel: Int? = nil) {
        onDeviceConnectionChanged?(name, isConnected, batteryLevel)
    }
}
