//package vserhiienko.transferkitty.app;
//
//import android.Manifest;
//import android.content.Intent;
//import android.content.pm.PackageManager;
//import android.os.Build;
//import android.os.Bundle;
//import androidx.annotation.NonNull;
//import androidx.annotation.RequiresApi;
//import androidx.annotation.UiThread;
//import androidx.core.app.ActivityCompat;
//import androidx.core.content.ContextCompat;
//import android.util.Log;
//
//import vserhiienko.transferkitty.TKBluetoothCommunicator;
//import vserhiienko.transferkitty.TKBluetoothCommunicatorCommand;
//import vserhiienko.transferkitty.TKBluetoothCommunicatorDevice;
//import vserhiienko.transferkitty.TKBluetoothCommunicatorMessage;
//import vserhiienko.transferkitty.TKDebug;
//import vserhiienko.transferkitty.TKBluetoothCommunicatorDelegate;
//
//import org.jetbrains.annotations.NotNull;
//
//import io.flutter.app.FlutterActivity;
//import io.flutter.plugin.common.MethodCall;
//import io.flutter.plugin.common.MethodChannel;
//import io.flutter.plugins.GeneratedPluginRegistrant;
//
//import java.util.ArrayList;
//import java.util.Arrays;
//import java.util.HashSet;
//import java.util.Set;
//
//@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
//public class MainActivity extends FlutterActivity implements TKBluetoothCommunicatorDelegate, MethodChannel.MethodCallHandler {
//    private static final String TAG = MainActivity.class.getSimpleName();
//    private static final String FLUTTER_CHANNEL_DATA_SERVICE = "btcomm_method_channel";
//    private static final int INTENT_REQUEST_ENABLE_BLUETOOTH = 1;
//    private static final int INTENT_REQUEST_PERMISSIONS = 2;
//
//    private TKBluetoothCommunicator _bluetoothCommunicator = null;
//    private Set<TKBluetoothCommunicatorDevice> _connectedDevices = null;
//    private MethodChannel _methodChannel = null;
//
//    //
//    // Activity
//    //
//
//    @Override
//    protected void onCreate(Bundle savedInstanceState) {
//        super.onCreate(savedInstanceState);
//
//        TKDebug.dlog(Log.INFO, TAG, "[Activity] onCreate");
//
//        _bluetoothCommunicator = TKBluetoothCommunicator.getInstance();
//        TKDebug._bluetoothCommunicator = _bluetoothCommunicator;
//        TKDebug._bluetoothCommunicatorDelegate = this;
//
//        _connectedDevices = new HashSet<>();
//
//        TKDebug.dcheck(_bluetoothCommunicator != null, TAG,"_bluetoothCommunicator != null");
//
//        GeneratedPluginRegistrant.registerWith(this);
//
//        _methodChannel = new MethodChannel(getFlutterView(), FLUTTER_CHANNEL_DATA_SERVICE);
//        _methodChannel.setMethodCallHandler(this);
//
//        requestPermissionsIfNeeded();
//    }
//
//    @Override
//    public void onRequestPermissionsResult(final int requestCode,
//                                           @NotNull final String[] permissions,
//                                           @NotNull final int[] grantResults) {
//        TKDebug.dlog(Log.INFO, TAG, "[Activity] onRequestPermissionsResult");
//        if (requestCode == INTENT_REQUEST_PERMISSIONS) {
//            TKDebug.dcheck(permissions.length == grantResults.length, TAG, "permissions.length == grantResults.length");
//
//            boolean allGranted = true;
//            for (int i = 0; i < grantResults.length; ++i) {
//                final boolean isGranted = grantResults[i] == PackageManager.PERMISSION_GRANTED;
//                allGranted &= isGranted;
//
//                TKDebug.dlog(Log.INFO, TAG, permissions[i] + ": " + isGranted);
//            }
//
//            if (allGranted) {
//                TKDebug.dlog(Log.INFO, TAG, "All permissions are granted.");
//            } else {
//                TKDebug.dlog(Log.ERROR, TAG, "Not all permissions are granted.");
//            }
//        } else {
//            super.onRequestPermissionsResult(requestCode, permissions, grantResults);
//        }
//    }
//
//    @Override
//    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
//        TKDebug.dlog(Log.INFO, TAG, "[Activity] onActivityResult");
//
//        if (requestCode == INTENT_REQUEST_ENABLE_BLUETOOTH) {
//            _bluetoothCommunicator.initPeripheralWith(this, this);
//        } else {
//            super.onActivityResult(requestCode, resultCode, data);
//        }
//    }
//
//    @Override
//    protected void onRestart() {
//        super.onRestart();
//        TKDebug.dlog(Log.INFO, TAG, "[Activity] onRestart");
//        reportCurrentStatus();
//    }
//
//    @Override
//    protected void onResume() {
//        super.onResume();
//        TKDebug.dlog(Log.INFO, TAG, "[Activity] onResume");
//        reportCurrentStatus();
//    }
//
//    //
//    // Flutter
//    //
//
//
//    @Override
//    public void onMethodCall(@NonNull MethodCall methodCall, @NonNull MethodChannel.Result result) {
//        // Log.d(TAG, "[Flutter] onMethodCall");
//        runOnUiThread(() -> {
//            // Log.d(TAG, "[Flutter] onMethodCall [UI]");
//            flutterDidReceiveFlutterMethodCall(methodCall, result);
//        });
//    }
//
//    @UiThread
//    private void flutterDidReceiveFlutterMethodCall(@NonNull MethodCall methodCall, @NonNull MethodChannel.Result result) {
//        TKDebug.dlog(Log.INFO, TAG, "[Flutter] flutterDidReceiveFlutterMethodCall");
//
//        TKDebug.dlog(Log.INFO, TAG, "Dart calls: " + methodCall.method);
//        if (methodCall.method.equals("cmd")) {
//
//            // methodCall.arguments != null is covered
//            if (methodCall.arguments instanceof ArrayList) try {
//
//                // https://stackoverflow.com/a/13387897/1474407
//                ArrayList<?> arguments = (ArrayList<?>) methodCall.arguments;
//                Integer cmdId = (Integer) arguments.get(0);
//
//                switch (cmdId) {
//                    case TKBluetoothCommunicatorCommand.START_PERIPHERAL:
//                        startPeripheral();
//                        result.success(Boolean.TRUE);
//                        break;
//                    case TKBluetoothCommunicatorCommand.START_ADVERTISING:
//                        startAdvertising();
//                        result.success(Boolean.TRUE);
//                        break;
//                    case TKBluetoothCommunicatorCommand.STATUS_BITS:
//                        result.success(_bluetoothCommunicator.getStatusBits());
//                        break;
//                    case TKBluetoothCommunicatorCommand.RESET_TO_INITIAL:
//                        result.success(Boolean.TRUE);
//                        break;
//                    case TKBluetoothCommunicatorCommand.SEND_TEST_DATA:
//                        sendTestData();
//                        result.success(Boolean.TRUE);
//                        break;
//
//                    default:
//                        TKDebug.dlog(Log.ERROR, TAG, "Unknown command: " + cmdId);
//                        result.success(Boolean.FALSE);
//                        break;
//                }
//
//            } catch (Exception e) {
//                TKDebug.dlog(Log.ERROR, TAG, TKDebug.strCat(
//                        "Failed to parse method arguments, message \"",
//                        e.getMessage(),
//                        "\", stack trace \"",
//                        Arrays.toString(e.getStackTrace()), "\""));
//            }
//        }
//    }
//
//    private void sendTestData() {
//        final String string = getResources().getString(R.string.DEMO_LONG_TEXT_FILE_CONTENTS);
//
//        for (final TKBluetoothCommunicatorDevice device : _connectedDevices) {
//            final int responseMessageType = TKBluetoothCommunicatorMessage.BTCM_MESSAGE_TYPE_CONFIRM;
//            _bluetoothCommunicator.getScheduler().scheduleFileMessageToOrPanic(device, "Lorem.txt", string.getBytes(), responseMessageType);
//        }
//    }
//
//    //
//    // TKBluetoothCommunicator
//    //
//
//    @Override
//    public void bluetoothCommunicatorDidChangeStatusBits(final TKBluetoothCommunicator bluetoothCommunicator, final long statusBits) {
//        // TKDebug.dlog(Log.INFO, TAG, "[BtComm] bluetoothCommunicatorDidChangeStatusBits");
//
//        runOnUiThread(() -> {
//            Object _0 = TKBluetoothCommunicatorCommand.DID_CHANGE_STATUS_BITS;
//            Object _1 = statusBits;
//            ArrayList<Object> arguments = new ArrayList<>(2);
//            arguments.add(_0);
//            arguments.add(_1);
//            _methodChannel.invokeMethod("cmd", arguments);
//        });
//    }
//
//    @Override
//    public void bluetoothCommunicatorDidConnectDevice(final TKBluetoothCommunicator bluetoothCommunicator, final TKBluetoothCommunicatorDevice device) {
//        // TKDebug.dlog(Log.INFO, TAG, "[BtComm] bluetoothCommunicatorDidConnectDevice: " + device.getDeviceName());
//        _connectedDevices.add(device);
//
//        runOnUiThread(() -> {
//            Object _0 = TKBluetoothCommunicatorCommand.DID_CONNECT_DEVICE;
//            Object _1 = device.getLocalId();
//            Object _2 = device.getAddress(); // getDeviceName();
//
//            ArrayList<Object> arguments = new ArrayList<>(3);
//            arguments.add(_0);
//            arguments.add(_1);
//            arguments.add(_2);
//            _methodChannel.invokeMethod("cmd", arguments);
//        });
//    }
//
//    @Override
//    public void bluetoothCommunicatorDidUpdateDevice(TKBluetoothCommunicator bluetoothCommunicator, TKBluetoothCommunicatorDevice device) {
//
//        runOnUiThread(() -> {
//            Object _0 = TKBluetoothCommunicatorCommand.DID_UPDATE_DEVICE;
//            Object _1 = device.getLocalId();
//            Object _2 = device.getDeviceStringUUID();
//            Object _3 = device.getDeviceName();
//            Object _4 = device.getDeviceModel();
//            Object _5 = device.getDeviceFriendlyModel();
//
//            ArrayList<Object> arguments = new ArrayList<>(3);
//            arguments.add(_0);
//            arguments.add(_1);
//            arguments.add(_2);
//            arguments.add(_3);
//            arguments.add(_4);
//            arguments.add(_5);
//            _methodChannel.invokeMethod("cmd", arguments);
//        });
//    }
//
//    @Override
//    public void bluetoothCommunicatorDidDisconnectDevice(TKBluetoothCommunicator bluetoothCommunicator, TKBluetoothCommunicatorDevice device) {
//        // TKDebug.dlog(Log.INFO, TAG, "[BtComm] bluetoothCommunicatorDidDisconnectDevice: " + device.getDeviceName());
//        _connectedDevices.remove(device);
//
//        runOnUiThread(() -> {
//            Object _0 = TKBluetoothCommunicatorCommand.DID_DISCONNECT_DEVICE;
//            Object _1 = device.getLocalId();
//            Object _2 = device.getAddress(); // getDeviceName();
//
//            ArrayList<Object> arguments = new ArrayList<>(3);
//            arguments.add(_0);
//            arguments.add(_1);
//            arguments.add(_2);
//            _methodChannel.invokeMethod("cmd", arguments);
//        });
//    }
//
//    @Override
//    public void bluetoothCommunicatorDidLog(TKBluetoothCommunicator bluetoothCommunicator, String log) {
//        runOnUiThread(() -> {
//            Object _0 = TKBluetoothCommunicatorCommand.DID_LOG;
//            @SuppressWarnings("UnnecessaryLocalVariable") Object _1 = log;
//
//            ArrayList<Object> arguments = new ArrayList<>(2);
//            arguments.add(_0);
//            arguments.add(_1);
//            _methodChannel.invokeMethod("cmd", arguments);
//        });
//
//    }
//
//    //
//    // Utils
//    //
//
//    private void reportCurrentStatus() {
//        // TKDebug.dlog(Log.INFO, TAG, "reportCurrentStatus");
//
//        final TKBluetoothCommunicator bluetoothCommunicator = TKBluetoothCommunicator.getInstance();
//        final long bits = bluetoothCommunicator.getStatusBits();
//        bluetoothCommunicatorDidChangeStatusBits(bluetoothCommunicator, bits);
//    }
//
//    private void requestPermissionsIfNeeded() {
//        // TODO: Should resolve from manifest.
//        final String[] permissions = new String[] {
//                Manifest.permission.BLUETOOTH,
//                Manifest.permission.BLUETOOTH_ADMIN,
//                Manifest.permission.ACCESS_COARSE_LOCATION,
//                Manifest.permission.WRITE_EXTERNAL_STORAGE};
//
//        // https://developer.android.com/training/permissions/requesting
//        if (ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
//            ActivityCompat.requestPermissions(this, permissions, INTENT_REQUEST_PERMISSIONS);
//        }
//    }
//
//    private void startPeripheral() {
//        _bluetoothCommunicator.initPeripheralWith(this,this);
//    }
//
//    private void startAdvertising() {
//        _bluetoothCommunicator.startAdvertising();
//    }
//
//}
