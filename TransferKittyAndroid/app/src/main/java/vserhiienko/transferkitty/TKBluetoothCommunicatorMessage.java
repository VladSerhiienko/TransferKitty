package vserhiienko.transferkitty;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;

import java.nio.ByteBuffer;
import java.util.UUID;

@SuppressWarnings("WeakerAccess")
public class TKBluetoothCommunicatorMessage {
     private static final String TAG = TKBluetoothCommunicatorMessage.class.getSimpleName();

    public static final int BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX = 0;
    public static final int BTCM_MESSAGE_TYPE_BYTE_INDEX = 1;
    public static final int BTCM_SHORT_MESSAGE_START_BYTE_INDEX = 2;
    public static final int BTCM_MESSAGE_LENGTH_0_BYTE_INDEX = 2;
    public static final int BTCM_MESSAGE_LENGTH_1_BYTE_INDEX = 3;
    public static final int BTCM_MESSAGE_LENGTH_2_BYTE_INDEX = 4;
    public static final int BTCM_MESSAGE_LENGTH_3_BYTE_INDEX = 5;
    public static final int BTCM_LONG_MESSAGE_START_BYTE_INDEX = 6;
    public static final int BTCM_MINIMAL_MESSAGE_BYTE_LENGTH = 2;

    public static final int BTCM_INT_BYTE_LENGTH = 4;
    public static final int BTCM_UUID_BYTE_LENGTH = 16;

    public static final int BTCM_MESSAGE_TYPE_ENCRYPTED_BIT = 1 << 7;
    public static final int BTCM_MESSAGE_TYPE_SHORT_BIT = 1 << 6;

    public static final int BTCM_MESSAGE_TYPE_FINISH = 0; // Finishes a talk.
    public static final int BTCM_MESSAGE_TYPE_UUID = 1;
    public static final int BTCM_MESSAGE_TYPE_NAME = 2;
    public static final int BTCM_MESSAGE_TYPE_DEVICE_MODEL = 3;
    public static final int BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL = 4;
    public static final int BTCM_MESSAGE_TYPE_FAILURE = 5; // Notifies about failure with message processing.
    public static final int BTCM_MESSAGE_TYPE_CONFIRM = 6; // Confirms that message was received.
    public static final int BTCM_MESSAGE_TYPE_FILE = 7;

    @Contract(pure = true)
    public static boolean isMessageEncrypted(final int msg) {
        return (msg & BTCM_MESSAGE_TYPE_ENCRYPTED_BIT) == BTCM_MESSAGE_TYPE_ENCRYPTED_BIT;
    }

    @Contract(pure = true)
    public static boolean isMessageShort(final int msg) {
        return (msg & BTCM_MESSAGE_TYPE_SHORT_BIT) == BTCM_MESSAGE_TYPE_SHORT_BIT;
    }

    @Contract(pure = true)
    public static byte shortMessageType(int messageType) {
        return (byte)(messageType | BTCM_MESSAGE_TYPE_SHORT_BIT);
    }

    @Contract(pure = true)
    public static byte longMessageType(int messageType) {
        return (byte)(messageType & ~BTCM_MESSAGE_TYPE_SHORT_BIT);
    }

    @Contract(pure = true)
    public static int undecoratedMessageType(int msg) {
        msg = msg & ~BTCM_MESSAGE_TYPE_SHORT_BIT;
        msg = msg & ~BTCM_MESSAGE_TYPE_ENCRYPTED_BIT;
        return msg;
    }

    @NotNull
    @Contract(pure = true)
    public static byte[] intToBytes(final int i) {
        ByteBuffer bb = ByteBuffer.allocate(BTCM_INT_BYTE_LENGTH);
        bb.putInt(i);
        return bb.array();
    }

    @Contract(pure = true)
    public static int bytesToInt(@NotNull final byte[] bytes) {
        return bytesToInt(bytes, 0, BTCM_INT_BYTE_LENGTH);
    }

    @Contract(pure = true)
    public static int bytesToInt(@NotNull final byte[] bytes, final int offset, final int length) {
        TKDebug.dcheck(offset >= 0, TAG, "bytesToInt: offset >= 0");
        TKDebug.dcheck(length == BTCM_INT_BYTE_LENGTH, TAG, "bytesToInt: length == BTCM_INT_BYTE_LENGTH");
        TKDebug.dcheck(bytes.length >= (offset + length), TAG, "bytesToInt: bytes.length >= (offset + length)");

        ByteBuffer bb = ByteBuffer.wrap(bytes, offset, length);
        return bb.getInt();
    }

    @Contract(pure = true)
    public static int getResponseMessageType(@NotNull final byte[] wholeMessageBytes) {
        final int responseMessageType = (int) wholeMessageBytes[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX];
        TKDebug.dcheck(!isMessageShort(responseMessageType), TAG, "bytesToUuid: offset >= 0");
        TKDebug.dcheck(!isMessageEncrypted(responseMessageType), TAG, "bytesToUuid: offset >= 0");
        return responseMessageType;
    }

    @Contract(pure = true)
    public static int getMessageType(@NotNull byte[] wholeMessageBytes) {
        return (int) wholeMessageBytes[BTCM_MESSAGE_TYPE_BYTE_INDEX];
    }

    @Contract(pure = true)
    public static int getMessageContentsByteSize(@NotNull final byte[] wholeMessageBytes) {
        return bytesToInt(wholeMessageBytes, BTCM_MESSAGE_LENGTH_0_BYTE_INDEX, BTCM_INT_BYTE_LENGTH);
    }

    @NotNull
    @Contract(pure = true)
    public static UUID bytesToUuid(@NotNull final byte[] bytes) {
        return bytesToUuid(bytes, 0, bytes.length);
    }

    @NotNull
    @Contract(pure = true)
    public static UUID bytesToUuid(@NotNull final byte[] bytes, final int offset, final int length) {
        TKDebug.dcheck(offset >= 0, TAG, "bytesToUuid: offset >= 0");
        TKDebug.dcheck(length == BTCM_UUID_BYTE_LENGTH, TAG, "bytesToUuid: length == BTCM_UUID_BYTE_LENGTH");
        TKDebug.dcheck(bytes.length >= (offset + length), TAG, "bytesToUuid: bytes.length >= (offset + length)");

        ByteBuffer bb = ByteBuffer.wrap(bytes, offset, length);
        long firstLong = bb.getLong();
        long secondLong = bb.getLong();
        return new UUID(firstLong, secondLong);
    }

    @NotNull
    @Contract(pure = true)
    public static byte[] uuidToBytes(@NotNull final UUID uuid) {
        ByteBuffer bb = ByteBuffer.wrap(new byte[BTCM_UUID_BYTE_LENGTH]);
        bb.putLong(uuid.getMostSignificantBits());
        bb.putLong(uuid.getLeastSignificantBits());
        return bb.array();
    }

    @Contract(pure = true)
    public static boolean requiresResponse(@NotNull final byte[] messageBytes) {
        final byte responseMessageType = messageBytes[BTCM_RESPONSE_MESSAGE_TYPE_BYTE_INDEX];
        return responseMessageType != BTCM_MESSAGE_TYPE_FINISH;
    }
}
