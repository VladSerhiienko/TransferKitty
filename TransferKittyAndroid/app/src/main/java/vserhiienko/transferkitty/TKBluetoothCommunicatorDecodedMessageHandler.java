package vserhiienko.transferkitty;

import android.util.Log;

import org.jetbrains.annotations.NotNull;
import java.util.UUID;
import static vserhiienko.transferkitty.TKBluetoothCommunicatorMessage.*;

@SuppressWarnings("WeakerAccess")
public class TKBluetoothCommunicatorDecodedMessageHandler {
    private static final String TAG = TKBluetoothCommunicatorDecodedMessageHandler.class.getSimpleName();

    private TKBluetoothCommunicator _bluetoothCommunicator;

    // @Contract(pure = true)
    public TKBluetoothCommunicatorDecodedMessageHandler(@NotNull final TKBluetoothCommunicator bluetoothCommunicator) {
        _bluetoothCommunicator = bluetoothCommunicator;
    }

    public void processMessage(@NotNull final TKBluetoothCommunicatorDevice device, final int decoratedMessageType, final TKByteArraySpan messageContents) {
        if (isMessageEncrypted(decoratedMessageType)) {
            TKDebug.dlog(Log.ERROR, TAG, "Caught unsupported feature, encrypted message.");
            throw new RuntimeException("Unexpected message type.");
        }

        if (messageContents == null) {
            return;
        }

        final int undecoratedMessageType = undecoratedMessageType(decoratedMessageType);
        switch (undecoratedMessageType) {
            case BTCM_MESSAGE_TYPE_FINISH: {
                TKDebug.dlog(Log.INFO, TAG, "Received EOM.");
            } break;

            case BTCM_MESSAGE_TYPE_NAME: {
                processNameMessage(device, messageContents);
            } break;

            case BTCM_MESSAGE_TYPE_DEVICE_MODEL: {
                processModelMessage(device, messageContents);
            } break;

            case BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL: {
                processFriendlyModelMessage(device, messageContents);
            } break;

            case BTCM_MESSAGE_TYPE_UUID: {
                processUuidMessage(device, messageContents);
            } break;

            case BTCM_MESSAGE_TYPE_FILE: {
                processFileMessage(messageContents, _bluetoothCommunicator);
            } break;
        }
    }

    private void processNameMessage(@NotNull TKBluetoothCommunicatorDevice device, TKByteArraySpan messageContents) {
        if (device.getDeviceName().isEmpty()) {
            final String string = new String(messageContents.bytes, messageContents.offset, messageContents.length);
            device.setDeviceName(string);

            TKDebug.dlog(Log.INFO, TAG, "Assigning a device name: \"" + string + "\"");
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "A device already has an assigned name, the message is skipped.");
        }
    }

    private void processModelMessage(@NotNull TKBluetoothCommunicatorDevice device, TKByteArraySpan messageContents) {
        if (device.getDeviceModel().isEmpty()) {
            final String string = new String(messageContents.bytes, messageContents.offset, messageContents.length);
            device.setDeviceModel(string);

            TKDebug.dlog(Log.INFO, TAG, "Assigning a device model: \"" + string + "\"");
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "A device already has an assigned model, the message is skipped.");
        }
    }

    private void processFriendlyModelMessage(@NotNull TKBluetoothCommunicatorDevice device, TKByteArraySpan messageContents) {
        if (device.getDeviceFriendlyModel().isEmpty()) {
            final String string = new String(messageContents.bytes, messageContents.offset, messageContents.length);
            device.setDeviceFriendlyModel(string);

            TKDebug.dlog(Log.INFO, TAG, "Assigning a device friendly model: \"" + string + "\"");
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "A device already has an assigned friendly model, the message is skipped.");
        }
    }

    private void processUuidMessage(@NotNull TKBluetoothCommunicatorDevice device, TKByteArraySpan messageContents) {
        if (device.getDeviceUuid() == null) {
            final UUID uuid = bytesToUuid(messageContents.bytes, messageContents.offset, messageContents.length);
            device.setDeviceUuid(uuid);

            TKDebug.dlog(Log.INFO, TAG, "Assigning a device UUID: \"" + uuid + "\"");
        } else {
            TKDebug.dlog(Log.ERROR, TAG, "A device already has an assigned UUID, the message is skipped.");
        }
    }

    private static void processFileMessage(@NotNull final TKByteArraySpan messageContents, @NotNull final TKBluetoothCommunicator _bluetoothCommunicator) {
        int fileNameLength = 0;
        for (int i = messageContents.offset + 1; i < messageContents.length; ++i) {
            if (messageContents.bytes[i - 1] == 0 && messageContents.bytes[i] == 0) {
                fileNameLength = i - 1;
                break;
            }
        }

        final String fileName = new String(messageContents.bytes, messageContents.offset, fileNameLength);
        final TKByteArraySpan fileData = new TKByteArraySpan(messageContents.bytes, messageContents.offset + fileNameLength, messageContents.length - (messageContents.offset + fileNameLength));

        TKFileSaver.saveFile(_bluetoothCommunicator.getAppContext(), fileName, fileData);
    }

}
