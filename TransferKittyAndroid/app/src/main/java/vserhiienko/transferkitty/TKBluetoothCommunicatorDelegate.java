package vserhiienko.transferkitty;

public interface TKBluetoothCommunicatorDelegate {
    void bluetoothCommunicatorDidChangeStatusBits(TKBluetoothCommunicator bluetoothCommunicator, long statusBits);
    void bluetoothCommunicatorDidConnectDevice(TKBluetoothCommunicator bluetoothCommunicator, TKBluetoothCommunicatorDevice device);
    void bluetoothCommunicatorDidUpdateDevice(TKBluetoothCommunicator bluetoothCommunicator, TKBluetoothCommunicatorDevice device);
    void bluetoothCommunicatorDidDisconnectDevice(TKBluetoothCommunicator bluetoothCommunicator, TKBluetoothCommunicatorDevice device);
    void bluetoothCommunicatorDidLog(TKBluetoothCommunicator bluetoothCommunicator, String log);


    // void onCentralDeviceFound(TKBluetoothCommunicatorDevice device);
    // void onCentralDeviceLost(TKBluetoothCommunicatorDevice device);
    // Activity getParentActivity();
}
