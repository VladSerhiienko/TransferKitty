package vserhiienko.transferkitty;

import android.app.Activity;
import android.bluetooth.BluetoothAdapter;
import android.bluetooth.BluetoothDevice;
import android.bluetooth.BluetoothGatt;
import android.bluetooth.BluetoothGattCharacteristic;
import android.bluetooth.BluetoothGattDescriptor;
import android.bluetooth.BluetoothGattServer;
import android.bluetooth.BluetoothGattServerCallback;
import android.bluetooth.BluetoothGattService;
import android.bluetooth.BluetoothManager;
import android.bluetooth.le.AdvertiseCallback;
import android.bluetooth.le.AdvertiseData;
import android.bluetooth.le.AdvertiseSettings;
import android.bluetooth.le.BluetoothLeAdvertiser;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.os.ParcelUuid;
import android.preference.PreferenceManager;
import android.provider.Settings;
import androidx.annotation.RequiresApi;
import android.util.Log;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;

import java.nio.charset.Charset;
import java.util.Arrays;
import java.util.HashMap;
import java.util.UUID;


/**
 * BLE-related links:
 * https://www.bluetooth.com/specifications/gatt/services/
 * https://www.bluetooth.com/specifications/gatt/characteristics/
 * https://www.bluetooth.com/specifications/gatt/descriptors/
 *
 * MTU, maximum transmission unit:
 * https://punchthrough.com/maximizing-ble-throughput-part-2-use-larger-att-mtu-2/
 * https://github.com/greatscottgadgets/ubertooth/wiki/One-minute-to-understand-BLE-MTU-data-package
 */
@SuppressWarnings("WeakerAccess")
@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class TKBluetoothCommunicator {
    private static final String TAG = TKBluetoothCommunicator.class.getSimpleName();
    private static final String EMPTY_STRING = "";
    private static final TKBluetoothCommunicator instance = new TKBluetoothCommunicator();
    public static final Charset UTF_8 = Charset.forName("UTF-8");

    @Contract(pure = true)
    public static TKBluetoothCommunicator getInstance() {

        return instance;
    }

    public static int INTENT_REQUEST_ENABLE_BLUETOOTH = 1;
    public static int MINIMAL_MTU_IN_BYTES = 20;


    //
    // List of generated UUIDs:
    //
    // 07BDC246-B8DD-4240-9743-EDD6B9AFF20F
    // 4035D667-4896-4C38-8010-837506F54932
    // E5741B16-323A-4A5D-8F57-27110E1D1FDF
    // 9DB839F1-5DC7-4C8D-835D-BCCEB664DE73
    // A0B923F3-494C-43B0-B0D1-65C2ED9783B9
    // 1CDFEE60-EF10-4D69-B9C1-189959A8591D
    // 4B7F1D25-2D23-457A-AF8F-51B2E08461DA
    // 1EB66E9C-BC06-465E-B8FA-010D83B2CCF6

    private static final String UUID_KEY = "BluetoothCommunicatorUUID";
    private static final String UUID_EMPTY_VALUE = "?";
    private static final UUID TRANSFER_SERVICE_UUID = UUID.fromString("07BDC246-B8DD-4240-9743-EDD6B9AFF20F");
    private static final UUID TRANSFER_CHARACTERISTIC_UUID = UUID.fromString("4035D667-4896-4C38-8010-837506F54932");
    private static final UUID CLIENT_CHARACTERISTIC_CONFIGURATION_UUID = UUID.fromString("00002902-0000-1000-8000-00805f9b34fb");
    private static final UUID CHARACTERISTIC_USER_DESCRIPTION_UUID = UUID.fromString("00002901-0000-1000-8000-00805f9b34fb");

    // private static final String STRING_DATA_REQUEST_DESCRIPTION = "DATA_REQUEST";
    private static final String STRING_DATA_RESPOND_DESCRIPTION = "DATA_RESPOND";

    private UUID _uuid;
    private long _statusBits;
    private BluetoothManager _bluetoothManager;
    private BluetoothLeAdvertiser _bluetoothAdvertiser;
    private BluetoothAdapter _bluetoothAdapter;
    private BluetoothGattService _dataTransferService;
    private BluetoothGattCharacteristic _characteristic;
    private HashMap<BluetoothDevice, TKBluetoothCommunicatorDevice> _bluetoothDevices = new HashMap<>();
    private BluetoothGattServer _gattServer;
    private BluetoothGattServerCallback _gattServerCallback;
    @SuppressWarnings("FieldCanBeLocal")
    private AdvertiseCallback _advertiseCallback;
    private AdvertiseSettings _advertiseSettings;
    private Activity _associatedActivity;
    private TKBluetoothCommunicatorDelegate _delegate;
    private TKBluetoothCommunicatorScheduler _scheduler;
    private String _name = EMPTY_STRING;

    private TKBluetoothCommunicator() {
        _statusBits = TKBluetoothCommunicatorStatusBits.INITIAL;
        _scheduler = new TKBluetoothCommunicatorScheduler(this);
    }

    public long getStatusBits() {
        return _statusBits;
    }
    public UUID getUUID() {
        return _uuid;
    }
    public String getName() { return _name; }
    public String getModel() { return Build.MODEL; }
    public String getFriendlyModel() { return Build.MANUFACTURER + " " + Build.PRODUCT; }
    public TKBluetoothCommunicatorScheduler getScheduler() {
        return _scheduler;
    }

    private void setStatusBits(final long statusBits) {
        if (_statusBits != statusBits) {
            _statusBits = statusBits;

            TKDebug.dlog(Log.INFO, TAG, "_statusBits=" + TKBluetoothCommunicatorStatusBits.toString(_statusBits));
            _delegate.bluetoothCommunicatorDidChangeStatusBits(this, _statusBits);
        }
    }

    private void prepareUUID() {
        if (_uuid == null) {
            SharedPreferences preferences = null;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.N) {
                // https://developer.android.com/training/data-storage/shared-preferences.html#java
                // If this scope is not executed, use the next one. The information will be stored at the activity level (not app).

                final Context context = _associatedActivity.getApplicationContext();
                preferences = PreferenceManager.getDefaultSharedPreferences(context);
            }

            if (preferences == null) {
                // Store settings at the level of activity.
                preferences = _associatedActivity.getPreferences(Context.MODE_PRIVATE);
            }

            String uuid = null;
            if (preferences == null) {
                uuid = UUID.randomUUID().toString();
            } else {
                if (preferences.contains(UUID_KEY)) {
                    uuid = preferences.getString(UUID_KEY, UUID_EMPTY_VALUE);
                }
                if (uuid == null || uuid.isEmpty() || uuid == UUID_EMPTY_VALUE) {
                    uuid = UUID.randomUUID().toString();

                    // Use apply() instead of commit to flush settings in the background (IDE tip).
                    preferences.edit().putString(UUID_KEY, uuid).apply();
                }
            }

            _uuid = UUID.fromString(uuid);
            TKDebug.dlog(Log.INFO, TAG, "_uuid=" + _uuid);
        }
    }

    // Returns either good result or an empty string.
    private static String getStringSafely(TKFunc<Void, String> func) {
        try {
            String result = func.apply(null);
            return result != null ? result : EMPTY_STRING;
        } catch (Exception e) {
            TKDebug.dlog(Log.ERROR, TAG, "Failed to execute.");
            return EMPTY_STRING;
        }
    }

    // https://medium.com/@pribble88/how-to-get-an-android-device-nickname-4b4700b3068c
    private void prepareName() {
        if (_name.isEmpty()) {

            //
            // Try to get the name from bluetooth settings.
            //

            final TKFunc<Void, String> adapterBluetoothNameFn = v -> BluetoothAdapter.getDefaultAdapter().getName();
            if (BuildConfig.DEBUG) {
                TKDebug.dlog(Log.INFO, TAG, "BluetoothAdapter.default.name = " + getStringSafely(adapterBluetoothNameFn));
            }

            _name = getStringSafely(adapterBluetoothNameFn);
            if (!EMPTY_STRING.equals(_name)) return;

            //
            // Try to get the name of the device using other services.
            // TODO: Maybe we should search for more approaches.
            //

            final ContentResolver contentResolver = _associatedActivity.getContentResolver();
            final TKFunc<Void, String> systemBluetoothNameFn = v -> Settings.System.getString(contentResolver, "bluetooth_name");
            final TKFunc<Void, String> systemDeviceNameFn = v -> Settings.System.getString(contentResolver, "device_name");
            final TKFunc<Void, String> secureBluetoothNameFn = v -> Settings.Secure.getString(contentResolver, "bluetooth_name");
            final TKFunc<Void, String> secureLsoNameFn = v -> Settings.Secure.getString(contentResolver, "lock_screen_owner_info");

            if (BuildConfig.DEBUG) {
                TKDebug.dlog(Log.INFO, TAG,"BluetoothAdapter.default.name = " + getStringSafely(adapterBluetoothNameFn));
                TKDebug.dlog(Log.INFO, TAG,"System.bluetooth_name = " + getStringSafely(systemBluetoothNameFn));
                TKDebug.dlog(Log.INFO, TAG,"System.device_name = " + getStringSafely(systemDeviceNameFn));
                TKDebug.dlog(Log.INFO, TAG,"Secure.bluetooth_name = " + getStringSafely(secureBluetoothNameFn));
                TKDebug.dlog(Log.INFO, TAG,"Secure.lock_screen_owner_info = " + getStringSafely(secureLsoNameFn));
            }

            _name = getStringSafely(systemBluetoothNameFn);
            if (!EMPTY_STRING.equals(_name))
                return;

            _name = getStringSafely(systemDeviceNameFn);
            if (!EMPTY_STRING.equals(_name))
                return;

            _name = getStringSafely(secureBluetoothNameFn);
            if (!EMPTY_STRING.equals(_name))
                return;

            _name = getStringSafely(secureLsoNameFn);
            if (!EMPTY_STRING.equals(_name))
                return;

            _name = getFriendlyModel();
        }
    }

    private static BluetoothGattDescriptor getClientCharacteristicConfigurationDescriptor() {
        final int READ_WRITE_PERMISSION = BluetoothGattDescriptor.PERMISSION_READ | BluetoothGattDescriptor.PERMISSION_WRITE;

        final BluetoothGattDescriptor descriptor = new BluetoothGattDescriptor(CLIENT_CHARACTERISTIC_CONFIGURATION_UUID, READ_WRITE_PERMISSION);
        descriptor.setValue(BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);
        return descriptor;
    }

    private static BluetoothGattDescriptor getCharacteristicUserDescriptionDescriptor(@SuppressWarnings("SameParameterValue") @NotNull String defaultValue) {
        final int READ_WRITE_PERMISSION = BluetoothGattDescriptor.PERMISSION_READ | BluetoothGattDescriptor.PERMISSION_WRITE;

        final BluetoothGattDescriptor descriptor = new BluetoothGattDescriptor(CHARACTERISTIC_USER_DESCRIPTION_UUID, READ_WRITE_PERMISSION);
        descriptor.setValue(defaultValue.getBytes(UTF_8));
        return descriptor;
    }

    private BluetoothGattService initializeBluetoothGattService() {
        final int READ_WRITE_NOTIFY_PROPERTY = BluetoothGattCharacteristic.PROPERTY_READ | BluetoothGattCharacteristic.PROPERTY_WRITE | BluetoothGattCharacteristic.PROPERTY_NOTIFY;
        final int READ_WRITE_NOTIFY_PERMISSION = BluetoothGattCharacteristic.PERMISSION_READ | BluetoothGattCharacteristic.PERMISSION_WRITE;

        BluetoothGattCharacteristic dataTransferCharacteristic = new BluetoothGattCharacteristic(TRANSFER_CHARACTERISTIC_UUID, READ_WRITE_NOTIFY_PROPERTY, READ_WRITE_NOTIFY_PERMISSION);
        dataTransferCharacteristic.addDescriptor(getClientCharacteristicConfigurationDescriptor());
        dataTransferCharacteristic.addDescriptor(getCharacteristicUserDescriptionDescriptor(STRING_DATA_RESPOND_DESCRIPTION));

        BluetoothGattService dataTransferService = new BluetoothGattService(TRANSFER_SERVICE_UUID, BluetoothGattService.SERVICE_TYPE_PRIMARY);
        dataTransferService.addCharacteristic(dataTransferCharacteristic);
        return dataTransferService;
    }

    private BluetoothGattServer initializeBluetoothGattServer() {
        initializeBluetoothGattServerCallback();
        TKDebug.dcheck(_gattServerCallback != null, TAG, "_gattServerCallback != null");
        TKDebug.dcheck(_associatedActivity != null, TAG, "_associatedActivity != null");
        final Context context = _associatedActivity.getApplicationContext();

        TKDebug.dcheck(context != null, TAG, "context != null");
        TKDebug.dcheck(_bluetoothManager != null, TAG, "_bluetoothManager != null");
        TKDebug.dcheck(_gattServerCallback != null, TAG, "_gattServerCallback != null");
        return _bluetoothManager.openGattServer(context, _gattServerCallback);
    }

    private void startPeripheral() {
        TKDebug.dlog(Log.INFO, TAG, "startPeripheral");

        long bits = _statusBits;
        bits = TKBluetoothCommunicatorStatusBits.setBit(bits, TKBluetoothCommunicatorStatusBits.STARTING_PERIPHERAL);
        setStatusBits(bits);

        if (_gattServer != null) {
            TKDebug.dcheck(_dataTransferService != null, TAG, "_dataTransferService != null");
            TKDebug.dcheck(_characteristic != null, TAG, "_characteristic != null");

            TKDebug.dlog(Log.WARN, TAG, "Already peripheral.");
            return;
        }

        _gattServer = initializeBluetoothGattServer();
        _dataTransferService = initializeBluetoothGattService();

        if (_gattServer != null && _dataTransferService != null) {
            _characteristic = _dataTransferService.getCharacteristic(TRANSFER_CHARACTERISTIC_UUID);
            _gattServer.addService(_dataTransferService);
        }
    }

    private void startPeripheralAfterUserInput(final TKBluetoothCommunicatorDelegate delegate) {
        if (delegate == null || delegate != _delegate) {
            /* Delegate should match to the previously assigned one.
             */
            setStatusBits(TKBluetoothCommunicatorStatusBits.PANIC);
            return;
        }

        if (_bluetoothAdapter == null) {
            /* This should never happen, notify UI about the internal error.
             */
            setStatusBits(TKBluetoothCommunicatorStatusBits.PANIC);
        } else if (_bluetoothAdapter.isEnabled()) {
            /* Remove waiting status and start as peripheral.
             */
            long bits = TKBluetoothCommunicatorStatusBits.unsetBit(_statusBits, TKBluetoothCommunicatorStatusBits.WAITING_FOR_USER_INPUT);
            setStatusBits(bits);
            startPeripheral();
        } else {
            /* Continue waiting.
             */
            long bits = TKBluetoothCommunicatorStatusBits.setBit(_statusBits, TKBluetoothCommunicatorStatusBits.WAITING_FOR_USER_INPUT);
            setStatusBits(bits);
        }
    }

    public void panic(@NotNull final TKBluetoothCommunicatorDevice device) {
        TKDebug.dlog(Log.ERROR, TAG, "panic: canceling connection with the device, forgetting the device, " + device.toString());

        _bluetoothDevices.remove(device.getBluetoothDevice());
        _gattServer.cancelConnection(device.getBluetoothDevice());
        _delegate.bluetoothCommunicatorDidDisconnectDevice(this, device);
    }

    public void startAdvertising() {
        if (_bluetoothAdvertiser == null) {
            _bluetoothAdvertiser = _bluetoothAdapter.getBluetoothLeAdvertiser();
        }

        if (_advertiseCallback == null) {
            _advertiseCallback = new AdvertiseCallback() {
                @Override
                public void onStartFailure(final int errorCode) {
                    super.onStartFailure(errorCode);
                    bluetoothAdvertiserDidNotStartAdvertising(errorCode);
                }

                @Override
                public void onStartSuccess(final AdvertiseSettings settingsInEffect) {
                    super.onStartSuccess(settingsInEffect);
                    bluetoothAdvertiserDidStartAdvertising(settingsInEffect);
                }
            };
        }

        final AdvertiseSettings advertiseSettings = new AdvertiseSettings.Builder()
                .setAdvertiseMode(AdvertiseSettings.ADVERTISE_MODE_BALANCED)
                .setTxPowerLevel(AdvertiseSettings.ADVERTISE_TX_POWER_MEDIUM)
                .setConnectable(true)
                .build();

        final AdvertiseData advertiseData = new AdvertiseData.Builder()
                .setIncludeTxPowerLevel(true)
                .addServiceUuid(new ParcelUuid(_dataTransferService.getUuid()))
                .build();

        final AdvertiseData advertiseScanResponse = new AdvertiseData.Builder()
                .setIncludeDeviceName(true)
                .build();

        assert _bluetoothAdvertiser != null;
        assert _advertiseCallback != null;

        _bluetoothAdvertiser.startAdvertising(
                advertiseSettings,
                advertiseData,
                advertiseScanResponse,
                _advertiseCallback);
    }

    public void cancelAdvertising() {
        if (_bluetoothAdvertiser != null && _advertiseCallback != null) {
            _bluetoothAdvertiser.stopAdvertising(_advertiseCallback);
        }
    }

    public void initPeripheralWith(final Activity activity,
                                   final TKBluetoothCommunicatorDelegate delegate) {

        if (TKBluetoothCommunicatorStatusBits.isBitSet(_statusBits, TKBluetoothCommunicatorStatusBits.WAITING_FOR_USER_INPUT)) {
            /* This function must have been called for the second time from
             * the parent activity after a user was asked to turn on the Bluetooth device.
             */
            startPeripheralAfterUserInput(delegate);
        } else if (TKBluetoothCommunicatorStatusBits.isBitSet(_statusBits, TKBluetoothCommunicatorStatusBits.UNSUPPORTED)) {
            /* We set UNSUPPORTED previously, nothing to dcheck now.
             */
            setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
        } else if (_statusBits == TKBluetoothCommunicatorStatusBits.INITIAL) {
            /* The first call to this function, ensure nothing was set previously.
             */
            TKDebug.dcheck(_delegate == null, TAG, "_delegate == null");
            TKDebug.dcheck(_associatedActivity == null, TAG, "_associatedActivity == null");

            /* Generate or read previously generated UUID for this device.
             */
            _associatedActivity = activity;
            prepareUUID();
            prepareName();

            /* Set the delegate and the associated activity.
             * Try to initialize the bluetooth adapter.
             */
            _delegate = delegate;
            _bluetoothManager = (BluetoothManager) _associatedActivity.getSystemService(Context.BLUETOOTH_SERVICE);
            _bluetoothAdapter = _bluetoothManager != null ? _bluetoothManager.getAdapter() : null;

            TKDebug.dlog(Log.INFO, TAG, "_bluetoothManager=" + _bluetoothManager);
            TKDebug.dlog(Log.INFO, TAG, "_bluetoothAdapter=" + _bluetoothAdapter);

            if (_bluetoothAdapter == null) {
                /* Set UNSUPPORTED status.
                 */
                setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
            } else if (_bluetoothAdapter.isEnabled()) {
                /* We are ok to try to start this device as a peripheral.
                 */
                startPeripheral();
            } else {
                assert _delegate != null;
                assert _associatedActivity != null;

                /* Request user to turn on the bluetooth device.
                 */
                setStatusBits(TKBluetoothCommunicatorStatusBits.WAITING_FOR_USER_INPUT);
                Intent enableBluetoothIntent = new Intent(BluetoothAdapter.ACTION_REQUEST_ENABLE);
                _associatedActivity.startActivityForResult(enableBluetoothIntent, INTENT_REQUEST_ENABLE_BLUETOOTH);
            }
        }
    }

    public void bluetoothCommunicatorDeviceDidChangeProperty(@NotNull final TKBluetoothCommunicatorDevice device) {
        _delegate.bluetoothCommunicatorDidUpdateDevice(this, device);
    }

    private void bluetoothGattServerDidChangeDeviceMTU(final BluetoothDevice bluetoothDevice,
                                                       final int mtu) {
        TKBluetoothCommunicatorDevice device = _bluetoothDevices.get(bluetoothDevice);
        if (device != null) {
            device.setConnectionMTU(mtu - 5);
            TKDebug.dlog(Log.INFO, TAG, "bluetoothGattServerDidChangeDeviceMTU: Changed MTU to " + mtu + " bytes for device @ " + device.getAddress());
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "bluetoothGattServerDidChangeDeviceMTU: Reported device is not connected");
        }
    }

    private void bluetoothGattServerDidAddService(final int status,
                                                  final BluetoothGattService service) {
        if (status == BluetoothGatt.GATT_SUCCESS) {
            assert service != null;
            TKDebug.dlog(Log.INFO, TAG, "bluetoothGattServerDidAddService: service added: " + service.toString());

            long bits = _statusBits;
            bits = TKBluetoothCommunicatorStatusBits.unsetBit(bits, TKBluetoothCommunicatorStatusBits.STARTING_PERIPHERAL);
            bits = TKBluetoothCommunicatorStatusBits.setBit(bits, TKBluetoothCommunicatorStatusBits.PERIPHERAL);
            setStatusBits(bits);
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "bluetoothGattServerDidAddService: service not added: " + service.toString() + ", error: " + status);
            setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
        }
    }

    private void bluetoothGattServerDidRequestRead(@NotNull final BluetoothDevice device,
                                                   final int requestId,
                                                   final int offset,
                                                   final BluetoothGattCharacteristic characteristic) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidRequestRead: device=" + device.toString()
                        + ", requestId=" + requestId + ", offset=" + offset + ", char=" + characteristic);

        if (offset == 0) {
            TKDebug.dlog(Log.INFO, TAG, "processMessageReturnResponseMessageType: responding with GATT_SUCCESS");
            _gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, null);
        } else {
            TKDebug.dlog(Log.INFO, TAG, "processMessageReturnResponseMessageType: responding with GATT_INVALID_OFFSET");
            _gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
        }
    }

    public Context getAppContext() {
        return _associatedActivity.getApplicationContext();
    }

    private void bluetoothGattServerDidRequestWrite(@NotNull final BluetoothDevice bluetoothDevice,
                                                    final int requestId,
                                                    @NotNull final BluetoothGattCharacteristic characteristic,
                                                    final boolean preparedWrite,
                                                    final boolean responseNeeded,
                                                    final int offset,
                                                    final byte[] value) {

        TKDebug.dlog(Log.INFO, TAG,
                "processMessageReturnResponseMessageType: device=" + bluetoothDevice.toString()
                        + ", requestId=" + requestId + ", char=" + characteristic + ", preparedWrite=" + preparedWrite
                        + ", responseNeeded=" + responseNeeded + ", offset=" + offset + ", value=" + Arrays.toString(value));

        TKBluetoothCommunicatorDevice device = _bluetoothDevices.get(bluetoothDevice);

        if (device == null) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: Caught disconnected device, GATT_FAILURE");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_FAILURE, offset, null);
        } else if (!device.getBluetoothDevice().getAddress().equals(bluetoothDevice.getAddress())) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: Caught device address mismatch, GATT_FAILURE");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_FAILURE, offset, null);
            panic(device);
        } else if (characteristic != _characteristic) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: Caught characteristic mismatch, GATT_FAILURE");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_FAILURE, offset, null);
            panic(device);
        }  else if (offset != 0) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: Caught non-zero offset, GATT_INVALID_OFFSET");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
            panic(device);
        } else if (value == null) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: Caught null value, GATT_FAILURE");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_FAILURE, offset, null);
            panic(device);
        } else {
            TKDebug.dlog(Log.INFO, TAG, "processMessageReturnResponseMessageType: GATT_SUCCESS");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_SUCCESS, offset, null);

            if (!_scheduler.scheduleRead(device, value)) {
                panic(device);
            }
        }

    }

    private void bluetoothGattServerDidRequestRead(@NotNull final BluetoothDevice device,
                                                   final int requestId,
                                                   final int offset,
                                                   @NotNull final BluetoothGattDescriptor descriptor) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidRequestRead: device=" + device.toString()
                        + ", requestId=" + requestId + ", offset=" + offset + ", descriptor=" + descriptor.toString());

        final byte[] value = descriptor.getValue();
        if (offset >= value.length) {
            _gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_INVALID_OFFSET, offset, null);
        } else {
            final byte[] responseBytes = offset == 0 ? value : Arrays.copyOfRange(value, offset, value.length);
            _gattServer.sendResponse(device, requestId, BluetoothGatt.GATT_SUCCESS, offset, responseBytes);
        }
    }

    private void bluetoothGattServerDidRequestWrite(@NotNull final BluetoothDevice bluetoothDevice,
                                                    final int requestId,
                                                    @NotNull final BluetoothGattDescriptor descriptor,
                                                    final boolean preparedWrite,
                                                    final boolean responseNeeded,
                                                    final int offset,
                                                    final byte[] value) {
        TKDebug.dlog(Log.INFO, TAG,
                "processMessageReturnResponseMessageType"
                        + ": device=" + bluetoothDevice.toString() + ", requestId=" + requestId + ", offset=" + offset
                        + ", descriptor=" + descriptor.toString() + ", preparedWrite=" + preparedWrite
                        + ", responseNeeded=" + responseNeeded + ", offset=" + offset + ", value=" + Arrays.toString(value));

        TKBluetoothCommunicatorDevice device = _bluetoothDevices.get(bluetoothDevice);
        if (device == null) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: device not connected.");
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_FAILURE, 0, null);
            return;
        }

        // Most likely, value is BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE {1, 0}.
        // descriptor.setValue(value);

        if (responseNeeded) {
            _gattServer.sendResponse(bluetoothDevice, requestId, BluetoothGatt.GATT_SUCCESS, 0, null);
        }

        final BluetoothGattDescriptor clientConfiguration = _characteristic.getDescriptor(CLIENT_CHARACTERISTIC_CONFIGURATION_UUID);
        if (clientConfiguration == null) {
            TKDebug.dlog(Log.ERROR, TAG, "processMessageReturnResponseMessageType: descriptor is not found.");
            return;
        }

        final boolean isSameDescriptor = clientConfiguration.getUuid() == descriptor.getUuid();
        final boolean isEnableNotificationValue = Arrays.equals(value, BluetoothGattDescriptor.ENABLE_NOTIFICATION_VALUE);

        if (isSameDescriptor && isEnableNotificationValue) {
            TKDebug.dlog(Log.INFO, TAG, "processMessageReturnResponseMessageType: device is enabling notifications.");
            TKDebug.dlog(Log.INFO, TAG, "processMessageReturnResponseMessageType: scheduling introduction messages.");
            _scheduler.scheduleIntroductionMessagesTo(device);
        }
    }

    private void bluetoothGattServerDidChangeConnection(final BluetoothDevice bluetoothDevice,
                                                        final int status,
                                                        final int newState) {
        if (status == BluetoothGatt.GATT_SUCCESS) {
            if (newState == BluetoothGatt.STATE_CONNECTED) {
                TKDebug.dlog(Log.INFO, TAG, "Connecting to device: " + bluetoothDevice.getAddress());

                TKBluetoothCommunicatorDevice device = new TKBluetoothCommunicatorDevice(this, bluetoothDevice, _bluetoothDevices.size());

                _bluetoothDevices.put(bluetoothDevice, device);
                _delegate.bluetoothCommunicatorDidConnectDevice(this, device);

                final long bits = _statusBits | TKBluetoothCommunicatorStatusBits.CONNECTED;
                setStatusBits(bits);

            } else if (newState == BluetoothGatt.STATE_DISCONNECTED) {
                TKDebug.dlog(Log.INFO, TAG, "Disconnecting from device: " + bluetoothDevice.getAddress());

                TKBluetoothCommunicatorDevice device = _bluetoothDevices.get(bluetoothDevice);
                if (device != null) {
                    panic(device);
                }
            }
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "Error when connecting: " + status);

            TKBluetoothCommunicatorDevice device = _bluetoothDevices.get(bluetoothDevice);
            if (device != null) {
                panic(device);
            }
        }

        if (_bluetoothDevices.isEmpty()) {
            final long bits = TKBluetoothCommunicatorStatusBits.unsetBit(_statusBits, TKBluetoothCommunicatorStatusBits.CONNECTED);
            setStatusBits(bits);
            startAdvertising();
        } else {
            final long bits = TKBluetoothCommunicatorStatusBits.setBit(_statusBits, TKBluetoothCommunicatorStatusBits.CONNECTED);
            setStatusBits(bits);
            cancelAdvertising();
        }
    }

    private void bluetoothAdvertiserDidStartAdvertising(final AdvertiseSettings advertiseSettings) {
        _advertiseSettings = advertiseSettings;

        final long bits = _statusBits | TKBluetoothCommunicatorStatusBits.ADVERTISING;
        setStatusBits(bits);
    }

    private void bluetoothAdvertiserDidNotStartAdvertising(final int errorCode) {
        switch (errorCode) {
            case AdvertiseCallback.ADVERTISE_FAILED_ALREADY_STARTED:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_ALREADY_STARTED");
                if (_advertiseSettings != null) {
                    long bits = _statusBits | TKBluetoothCommunicatorStatusBits.ADVERTISING;
                    setStatusBits(bits);
                } break;

            case AdvertiseCallback.ADVERTISE_FAILED_DATA_TOO_LARGE:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_DATA_TOO_LARGE");
                setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
                break;
            case AdvertiseCallback.ADVERTISE_FAILED_FEATURE_UNSUPPORTED:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_FEATURE_UNSUPPORTED");
                setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
                break;
            case AdvertiseCallback.ADVERTISE_FAILED_INTERNAL_ERROR:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_INTERNAL_ERROR");
                setStatusBits(TKBluetoothCommunicatorStatusBits.UNSUPPORTED);
                break;

            case AdvertiseCallback.ADVERTISE_FAILED_TOO_MANY_ADVERTISERS:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_TOO_MANY_ADVERTISERS");
                long bits = _statusBits | TKBluetoothCommunicatorStatusBits.WAITING_FOR_SYSTEM;
                setStatusBits(bits);
                break;

            default:
                TKDebug.dlog(Log.INFO, TAG, "bluetoothAdvertiserDidNotStartAdvertising: ADVERTISE_FAILED_FEATURE_UNSUPPORTED");
                setStatusBits(TKBluetoothCommunicatorStatusBits.PANIC);
                break;
        }
    }

    public void bluetoothGattServerSetValue(@NotNull final TKBluetoothCommunicatorDevice device,
                                               @NotNull final byte[] value) {
        TKDebug.dcheck(null != _gattServer, TAG, "null != _gattServer");
        TKDebug.dcheck(null != _characteristic, TAG, "null != _characteristic");
        TKDebug.dlog(Log.INFO, TAG, "bluetoothGattServerSetValue: " + Arrays.toString(value));

        if (_characteristic.setValue(value)) {
            if (_gattServer.notifyCharacteristicChanged(device.getBluetoothDevice(), _characteristic, false)) {
                return;
            }
        }

        panic(device);
    }

    @Contract(pure = true)
    private void initializeBluetoothGattServerCallback() {
        _gattServerCallback = new BluetoothGattServerCallback() {
            @Override
            public void onMtuChanged(final BluetoothDevice device,
                                     final int mtu) {
                super.onMtuChanged(device, mtu);
                bluetoothGattServerDidChangeDeviceMTU(device, mtu);
            }

            @Override
            public void onServiceAdded(final int status,
                                       final BluetoothGattService service) {
                super.onServiceAdded(status, service);
                bluetoothGattServerDidAddService(status, service);
            }

            @Override
            public void onCharacteristicReadRequest(final BluetoothDevice device,
                                                    final int requestId,
                                                    final int offset,
                                                    final BluetoothGattCharacteristic characteristic) {
                super.onCharacteristicReadRequest(device, requestId, offset, characteristic);
                bluetoothGattServerDidRequestRead(device, requestId, offset, characteristic);
            }

            @Override
            public void onCharacteristicWriteRequest(final BluetoothDevice device,
                                                     final int requestId,
                                                     final BluetoothGattCharacteristic characteristic,
                                                     final boolean preparedWrite,
                                                     final boolean responseNeeded,
                                                     final int offset,
                                                     final byte[] value) {
                super.onCharacteristicWriteRequest(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value);
                bluetoothGattServerDidRequestWrite(device, requestId, characteristic, preparedWrite, responseNeeded, offset, value);
            }

            @Override
            public void onDescriptorReadRequest(final BluetoothDevice device,
                                                final int requestId,
                                                final int offset,
                                                final BluetoothGattDescriptor descriptor) {
                super.onDescriptorReadRequest(device, requestId, offset, descriptor);
                bluetoothGattServerDidRequestRead(device, requestId, offset, descriptor);
            }

            @Override
            public void onDescriptorWriteRequest(final BluetoothDevice device,
                                                 final int requestId,
                                                 final BluetoothGattDescriptor descriptor,
                                                 final boolean preparedWrite,
                                                 final boolean responseNeeded,
                                                 final int offset,
                                                 final byte[] value) {
                super.onDescriptorWriteRequest(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value);
                bluetoothGattServerDidRequestWrite(device, requestId, descriptor, preparedWrite, responseNeeded, offset, value);
            }

            @Override
            public void onExecuteWrite(final BluetoothDevice device,
                                       final int requestId,
                                       final boolean execute) {
                super.onExecuteWrite(device, requestId, execute);
                bluetoothGattServerDidRequestExecuteWrite(device, requestId, execute);
            }

            @Override
            public void onNotificationSent(final BluetoothDevice device,
                                           final int status) {
                super.onNotificationSent(device, status);
                bluetoothGattServerDidSendNotification(device, status);
            }

            @Override
            public void onPhyUpdate(final BluetoothDevice device,
                                    final int txPhy,
                                    final int rxPhy,
                                    final int status) {
                super.onPhyUpdate(device, txPhy, rxPhy, status);
                bluetoothGattServerDidUpdatePhy(device, txPhy, rxPhy, status);
            }

            @Override
            public void onPhyRead(final BluetoothDevice device,
                                  final int txPhy,
                                  final int rxPhy,
                                  final int status) {
                super.onPhyRead(device, txPhy, rxPhy, status);
                bluetoothGattServerDidReadPhy(device, txPhy, rxPhy, status);
            }

            @Override
            public void onConnectionStateChange(final BluetoothDevice device,
                                                final int status,
                                                final int newState) {
                super.onConnectionStateChange(device, status, newState);
                bluetoothGattServerDidChangeConnection(device, status, newState);
            }
        };
    }

    private void bluetoothGattServerDidRequestExecuteWrite(@NotNull final BluetoothDevice device,
                                                           final int requestId,
                                                           final boolean execute) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidRequestExecuteWrite"
                        + ": device=" + device.toString()
                        + ", requestId=" + requestId
                        + ", execute=" + execute);
    }

    private void bluetoothGattServerDidSendNotification(@NotNull final BluetoothDevice device,
                                                        final int status) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidSendNotification"
                        + ": device=" + device.toString()
                        + ", status=" + status);
    }

    private void bluetoothGattServerDidUpdatePhy(@NotNull final BluetoothDevice device,
                                                 final int txPhy,
                                                 final int rxPhy,
                                                 final int status) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidUpdatePhy"
                        + ": device=" + device.toString()
                        + ", txPhy=" + txPhy
                        + ", rxPhy=" + rxPhy
                        + ", status=" + status);
    }

    private void bluetoothGattServerDidReadPhy(@NotNull final BluetoothDevice device,
                                               final int txPhy,
                                               final int rxPhy,
                                               final int status) {
        TKDebug.dlog(Log.INFO, TAG,
                "bluetoothGattServerDidReadPhy"
                        + ": device=" + device.toString()
                        + ", txPhy=" + txPhy
                        + ", rxPhy=" + rxPhy
                        + ", status=" + status);
    }
}
