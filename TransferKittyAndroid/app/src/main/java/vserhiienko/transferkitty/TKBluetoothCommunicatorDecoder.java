package vserhiienko.transferkitty;

import android.os.Build;
import androidx.annotation.RequiresApi;
import android.util.Log;

import org.jetbrains.annotations.NotNull;

import java.util.concurrent.ConcurrentHashMap;

import static vserhiienko.transferkitty.TKBluetoothCommunicatorMessage.*;

@SuppressWarnings("WeakerAccess")
@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class TKBluetoothCommunicatorDecoder {
    private static final String TAG = TKBluetoothCommunicatorDecoder.class.getSimpleName();

    private TKBluetoothCommunicator _bluetoothCommunicator;
    private TKBluetoothCommunicatorDecodedMessageHandler _decodedMessageHandler;
    private ConcurrentHashMap<TKBluetoothCommunicatorDevice, TKBluetoothCommunicatorLongMessage> _longMessages;

    public TKBluetoothCommunicatorDecoder(@NotNull final TKBluetoothCommunicator bluetoothCommunicator) {
        _bluetoothCommunicator = bluetoothCommunicator;
        _decodedMessageHandler = new TKBluetoothCommunicatorDecodedMessageHandler(bluetoothCommunicator);
        _longMessages = new ConcurrentHashMap<>();
    }

    private void processMessage(@NotNull final TKBluetoothCommunicatorDevice device, @NotNull final byte[] wholeMessageBytes) {
        TKDebug.dcheck(wholeMessageBytes.length >= 1, TAG, "wholeMessageBytes.length >= 1");

        TKBluetoothCommunicatorLongMessage longMessage = getLongMessage(device);
        if (longMessage != null) {

            //
            // A long message has been started, next messages should be appended until a completeness is reached.
            // Long messages should be cleared upon the processing.
            //

            if (longMessage.append(wholeMessageBytes)) {
                _decodedMessageHandler.processMessage(device, longMessage.getMessageType(), new TKByteArraySpan(longMessage.getMessageContents()));
                clearLongMessage(device);
            }

        } else {
            final int decoratedMessageType = getMessageType(wholeMessageBytes);
            if (!isMessageShort(decoratedMessageType)) {

                // If the received message is long one, allocate a long message instance and start it.
                longMessage = getOrCreateLongMessage(device);
                longMessage.start(wholeMessageBytes);
            } else {

                // The received message is short one, it can be processed immediately.
                _decodedMessageHandler.processMessage(device, decoratedMessageType, TKByteArraySpan.makeSpanOrNull(wholeMessageBytes, BTCM_SHORT_MESSAGE_START_BYTE_INDEX));
            }
        }
    }

    private TKBluetoothCommunicatorLongMessage getLongMessage(@NotNull final TKBluetoothCommunicatorDevice device) {
        return _longMessages.get(device);
    }

    private void clearLongMessage(@NotNull final TKBluetoothCommunicatorDevice device) {
        _longMessages.remove(device);
    }

    @NotNull
    private TKBluetoothCommunicatorLongMessage getOrCreateLongMessage(@NotNull final TKBluetoothCommunicatorDevice device) {
        final TKBluetoothCommunicatorLongMessage longMessage = getLongMessage(device);
        if (longMessage != null) { return longMessage; }

        _longMessages.putIfAbsent(device, new TKBluetoothCommunicatorLongMessage());
        return getLongMessage(device);
    }

    public int processMessageReturnResponseMessageType(@NotNull final TKBluetoothCommunicatorDevice device,
                                                       @NotNull final byte[] wholeMessageBytes) {
        if (wholeMessageBytes.length < BTCM_MINIMAL_MESSAGE_BYTE_LENGTH) {
            TKDebug.dlog(Log.ERROR, TAG, "Caught invalid message.");
            return BTCM_MESSAGE_TYPE_FINISH;
        }

        processMessage(device, wholeMessageBytes);
        return getResponseMessageType(wholeMessageBytes);
    }
}
