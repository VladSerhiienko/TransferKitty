package vserhiienko.transferkitty;

import android.os.Build;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import android.util.Log;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;

import java.util.UUID;

import static vserhiienko.transferkitty.TKBluetoothCommunicatorMessage.*;

@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class TKBluetoothCommunicatorEncoder {
    private static final String TAG = TKBluetoothCommunicatorEncoder.class.getSimpleName();

    private TKBluetoothCommunicator _bluetoothCommunicator;

    public TKBluetoothCommunicatorEncoder(TKBluetoothCommunicator bluetoothCommunicator) {
        TKDebug.dcheck(bluetoothCommunicator != null, TAG, "bluetoothCommunicator != null");
        _bluetoothCommunicator = bluetoothCommunicator;
    }

    @NotNull
    @Contract(pure = true)
    public static byte[] confirmationResponse() {
        final byte[] result = new byte[2];
        //noinspection ConstantConditions
        result[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX] = BTCM_MESSAGE_TYPE_FINISH;
        result[BTCM_MESSAGE_TYPE_BYTE_INDEX] = shortMessageType(BTCM_MESSAGE_TYPE_CONFIRM);
        return result;
    }

    @NotNull
    @Contract(pure = true)
    public static byte[] failureResponse() {
        final byte[] result = new byte[2];
        //noinspection ConstantConditions
        result[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX] = BTCM_MESSAGE_TYPE_FINISH;
        result[BTCM_MESSAGE_TYPE_BYTE_INDEX] = shortMessageType(BTCM_MESSAGE_TYPE_FAILURE);
        return result;
    }

    @NotNull
    public byte[] composeMessage(@NonNull final TKBluetoothCommunicatorDevice device,
                                 @NotNull final byte[] messageContents,
                                 final int messageType,
                                 final int responseMessageType) {
        TKDebug.dlog(Log.DEBUG, TAG, "buildShortMessageRequireShortResponse");

        final int maxShortMessage = device.getConnectionMTU();
        final int estimatedMessageLength = messageContents.length + 2;
        byte[] messageBytes;
        int messageStartPosition;

        if (estimatedMessageLength > maxShortMessage) {
            //
            // Long message initialization:
            // Allocated 4 bytes more for storing a message length.
            //

            final int messageLength = estimatedMessageLength + BTCM_INT_BYTE_LENGTH;
            messageBytes = new byte[messageLength];
            messageBytes[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX] = (byte)responseMessageType;
            messageBytes[BTCM_MESSAGE_TYPE_BYTE_INDEX] = longMessageType(messageType);

            final byte[] messageLengthBytes = intToBytes(messageContents.length);
            TKDebug.dcheck(messageLengthBytes.length == BTCM_INT_BYTE_LENGTH, TAG, "Caught unexpected int byte size.");

            messageBytes[BTCM_MESSAGE_LENGTH_0_BYTE_INDEX] = messageLengthBytes[3];
            messageBytes[BTCM_MESSAGE_LENGTH_1_BYTE_INDEX] = messageLengthBytes[2];
            messageBytes[BTCM_MESSAGE_LENGTH_2_BYTE_INDEX] = messageLengthBytes[1];
            messageBytes[BTCM_MESSAGE_LENGTH_3_BYTE_INDEX] = messageLengthBytes[0];
            messageStartPosition = BTCM_LONG_MESSAGE_START_BYTE_INDEX;
        } else {
            messageBytes = new byte[estimatedMessageLength];
            messageBytes[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX] = (byte)responseMessageType;
            messageBytes[BTCM_MESSAGE_TYPE_BYTE_INDEX] = shortMessageType(messageType);
            messageStartPosition = BTCM_SHORT_MESSAGE_START_BYTE_INDEX;
        }

        System.arraycopy(messageContents, 0, messageBytes, messageStartPosition, messageContents.length);
        return messageBytes;
    }

    @NotNull
    public byte[] composeStringMessage(@NonNull final TKBluetoothCommunicatorDevice device,
                                       @NotNull String string,
                                       final int messageType,
                                       final int responseMessageType) {
        return composeMessage(device, string.getBytes(), messageType, responseMessageType);
    }

    @NotNull
    public byte[] composeUuidMessage(@NonNull final TKBluetoothCommunicatorDevice device,
                                     @NotNull UUID uuid,
                                     final int responseMessageType) {
        return composeMessage(device, uuidToBytes(uuid), BTCM_MESSAGE_TYPE_UUID, responseMessageType);
    }

    @NotNull
    public byte[] composeFileMessage(@NonNull final TKBluetoothCommunicatorDevice device,
                                     @NotNull String fileName,
                                     @NotNull byte[] fileContents,
                                     final int responseMessageType) {
        final int charByteLength = 2; // == Character.SIZE / Byte.SIZE;

        final byte[] fileNameBytes = fileName.getBytes();
        final int messageContentsLength = fileNameBytes.length + charByteLength + fileContents.length;
        final byte[] messageContents = new byte[messageContentsLength];
        int messageInsertPosition = 0;

        System.arraycopy(fileNameBytes, 0, messageContents, messageInsertPosition, fileNameBytes.length);

        // Zero terminated string.
        messageInsertPosition = fileNameBytes.length;
        messageContents[messageInsertPosition++] = 0;
        messageContents[messageInsertPosition++] = 0;

        System.arraycopy(fileContents, 0, messageContents, messageInsertPosition, fileContents.length);
        return composeMessage(device, messageContents, BTCM_MESSAGE_TYPE_FILE, responseMessageType);
    }

    private int decideResponseMessageTypeFor(@NotNull final TKBluetoothCommunicatorDevice device, final int message) {
        switch (message) {
            case BTCM_MESSAGE_TYPE_NAME:
                return device.getDeviceName().isEmpty() ? BTCM_MESSAGE_TYPE_NAME : BTCM_MESSAGE_TYPE_FINISH;
            case BTCM_MESSAGE_TYPE_DEVICE_MODEL:
                return device.getDeviceModel().isEmpty() ? BTCM_MESSAGE_TYPE_DEVICE_MODEL : BTCM_MESSAGE_TYPE_FINISH;
            case BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL:
                return device.getDeviceFriendlyModel().isEmpty() ? BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL : BTCM_MESSAGE_TYPE_FINISH;
            case BTCM_MESSAGE_TYPE_UUID:
                return device.getDeviceStringUUID().isEmpty() ? BTCM_MESSAGE_TYPE_UUID : BTCM_MESSAGE_TYPE_FINISH;
            case BTCM_MESSAGE_TYPE_FILE:
                return BTCM_MESSAGE_TYPE_CONFIRM;

            default:
                return BTCM_MESSAGE_TYPE_FINISH;
        }
    }

    private byte[] processResponseMessage(@NotNull final TKBluetoothCommunicatorDevice device, final int messageType) {
        switch (messageType) {
            case BTCM_MESSAGE_TYPE_NAME: {
                TKDebug.dlog(Log.INFO, TAG, "processResponseMessage: BTCM_MESSAGE_TYPE_NAME");
                final int responseType = decideResponseMessageTypeFor(device, messageType);
                return composeStringMessage(device, _bluetoothCommunicator.getName(), BTCM_MESSAGE_TYPE_NAME, responseType);
            }

            case BTCM_MESSAGE_TYPE_DEVICE_MODEL: {
                TKDebug.dlog(Log.INFO, TAG, "processResponseMessage: BTCM_MESSAGE_TYPE_DEVICE_MODEL");
                final int responseType = decideResponseMessageTypeFor(device, messageType);
                return composeStringMessage(device, _bluetoothCommunicator.getModel(), BTCM_MESSAGE_TYPE_NAME, responseType);
            }

            case BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL: {
                TKDebug.dlog(Log.INFO, TAG, "processResponseMessage: BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL");
                final int responseType = decideResponseMessageTypeFor(device, messageType);
                return composeStringMessage(device, _bluetoothCommunicator.getFriendlyModel(), BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL, responseType);
            }

            case BTCM_MESSAGE_TYPE_UUID: {
                TKDebug.dlog(Log.INFO, TAG, "processResponseMessage: BTCM_MESSAGE_TYPE_UUID");
                final int responseType = decideResponseMessageTypeFor(device, messageType);
                return composeUuidMessage(device, _bluetoothCommunicator.getUUID(), responseType);
            }
        }

        return failureResponse();

    }

    byte[] buildResponseMessage(@NotNull final TKBluetoothCommunicatorDevice device, final int responseMessageType) {
        switch (responseMessageType) {
            case BTCM_MESSAGE_TYPE_FINISH:
            case BTCM_MESSAGE_TYPE_CONFIRM:
                TKDebug.dlog(Log.INFO, TAG, "processResponseMessage: BTCM_MESSAGE_TYPE_FINISH | BTCM_MESSAGE_TYPE_CONFIRM");
                return null;

            default:
                return processResponseMessage(device, responseMessageType);
        }
    }

}
