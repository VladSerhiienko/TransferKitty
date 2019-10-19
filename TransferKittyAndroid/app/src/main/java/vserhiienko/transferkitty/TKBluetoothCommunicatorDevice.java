package vserhiienko.transferkitty;

import android.bluetooth.BluetoothDevice;

import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

import java.util.UUID;
import java.util.concurrent.atomic.AtomicBoolean;

public class TKBluetoothCommunicatorDevice {
    private static final String TAG = TKBluetoothCommunicatorDevice.class.getSimpleName();
    private static final String EMPTY_STRING = "";

    private static String goodOrEmptyString(String string) {
        if (string != null) return string;
        return EMPTY_STRING;
    }

    private @NotNull TKBluetoothCommunicator _bluetoothCommunicator;
    private @NotNull BluetoothDevice _bluetoothDevice;
    private @NotNull AtomicBoolean pendingWrite = new AtomicBoolean(false);

    private int _id;
    private int _mtu = TKBluetoothCommunicator.MINIMAL_MTU_IN_BYTES;
    private @Nullable UUID _deviceUUID = null;
    private @NotNull String _deviceUUIDString = EMPTY_STRING;
    private @NotNull String _deviceName = EMPTY_STRING;
    private @NotNull String _deviceModel = EMPTY_STRING;
    private @NotNull String _deviceManufacturerProduct = EMPTY_STRING;

    public TKBluetoothCommunicatorDevice(@NotNull final TKBluetoothCommunicator bluetoothCommunicator, @NotNull final BluetoothDevice deviceReference, int id) {
        _bluetoothCommunicator = bluetoothCommunicator;
        _bluetoothDevice = deviceReference;
        _id = id;
    }

    public int getLocalId() {
        return _id;
    }

    public int getConnectionMTU() {
        return _mtu;
    }

    public void setConnectionMTU(int mtu) {
        _mtu = mtu;
        _bluetoothCommunicator.bluetoothCommunicatorDeviceDidChangeProperty(this);
    }

    @Nullable
    public UUID getDeviceUuid() {
        return _deviceUUID;
    }

    @NotNull
    public String getDeviceStringUUID() {
        return _deviceUUIDString;
    }

    public void setDeviceUuid(UUID uuid) {
        _deviceUUID = uuid;
        _deviceUUIDString = uuid.toString();
        _bluetoothCommunicator.bluetoothCommunicatorDeviceDidChangeProperty(this);
    }

    public void setDeviceName(String deviceName) {
        _deviceName = goodOrEmptyString(deviceName);
        _bluetoothCommunicator.bluetoothCommunicatorDeviceDidChangeProperty(this);
    }

    @NotNull
    public String getDeviceName() {
        return _deviceName;
    }

    public void setDeviceModel(String deviceModel) {
        _deviceModel = goodOrEmptyString(deviceModel);
        _bluetoothCommunicator.bluetoothCommunicatorDeviceDidChangeProperty(this);
    }

    @NotNull
    public String getDeviceModel() {
        return _deviceModel;
    }

    public void setDeviceFriendlyModel(String deviceManufacturerProduct) {
        _deviceManufacturerProduct = goodOrEmptyString(deviceManufacturerProduct);
        _bluetoothCommunicator.bluetoothCommunicatorDeviceDidChangeProperty(this);
    }

    @NotNull
    public String getDeviceFriendlyModel() {
        return _deviceManufacturerProduct;
    }

    @NotNull
    public BluetoothDevice getBluetoothDevice() {
        return _bluetoothDevice;
    }

    public String getAddress() {
        return _bluetoothDevice.getAddress() != null ? _bluetoothDevice.getAddress() : EMPTY_STRING;
    }

    public boolean getPendingWrite() {
        return pendingWrite.get();
    }

    public void setPendingWrite() {
        pendingWrite.set(true);
    }

    public void clearPendingWrite() {
        pendingWrite.set(false);
    }

    @NotNull
    public String toString() {
        String result = "TKBluetoothCommunicatorDevice id=" + _id + ", bluetoothAddress=" + _bluetoothDevice.getAddress();
        if (!EMPTY_STRING.equals(_bluetoothDevice.getName())) result += ", deviceName=" + _deviceName;
        if (!EMPTY_STRING.equals(_deviceName)) result += ", userName=" + _deviceName;
        if (!EMPTY_STRING.equals(_deviceModel)) result += ", model=" + _deviceModel;
        if (!EMPTY_STRING.equals(_deviceManufacturerProduct)) result += ", friendlyModel=" + _deviceManufacturerProduct;
        return result;
    }
}
