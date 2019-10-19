package vserhiienko.transferkitty;

import org.jetbrains.annotations.NotNull;

import static vserhiienko.transferkitty.TKBluetoothCommunicatorMessage.*;

@SuppressWarnings("WeakerAccess")
public class TKBluetoothCommunicatorLongMessage {
    private static final String TAG = TKBluetoothCommunicatorLongMessage.class.getSimpleName();

    private int _responseMessageType;
    private int _messageType;
    private int _messageContentsLength;
    private byte[] _messageContents;
    private int _messageContentsOffset;

    public TKBluetoothCommunicatorLongMessage() {
        clear();
    }

    private void start(final int responseMessageType, final int messageType, final int messageContentsLength) {
        TKDebug.dcheck(isEmpty(), TAG, "start: isEmpty()");

        _responseMessageType = responseMessageType;
        _messageType = messageType;
        _messageContentsLength = messageContentsLength;
        _messageContents = new byte[messageContentsLength];
        _messageContentsOffset = 0;
    }

    public void start(@NotNull final byte[] wholeMessageBytes) {
        TKDebug.dcheck(isEmpty(), TAG, "start: isEmpty()");
        start(TKBluetoothCommunicatorMessage.getMessageType(wholeMessageBytes), TKBluetoothCommunicatorMessage.getResponseMessageType(wholeMessageBytes), getMessageContentsByteSize(wholeMessageBytes));

        final int contentsLength = _messageContents.length - BTCM_LONG_MESSAGE_START_BYTE_INDEX;
        if (contentsLength != 0) {
            System.arraycopy(wholeMessageBytes, BTCM_LONG_MESSAGE_START_BYTE_INDEX, _messageContents, 0, contentsLength);
            _messageContentsOffset += contentsLength;
        }
    }

    public boolean canAppend(final int byteArrayLength) {
        final int unfilledByteCount = _messageContentsLength - _messageContentsOffset;
        return unfilledByteCount >= byteArrayLength;
    }

    public boolean isComplete() {
        return _messageContentsLength == _messageContentsOffset;
    }

    public boolean append(@NotNull final byte[] wholeMessageBytes) {
        TKDebug.dcheck(canAppend(wholeMessageBytes.length), TAG, "Caught overflow.");
        System.arraycopy(wholeMessageBytes, 0, _messageContents, _messageContentsOffset, wholeMessageBytes.length);
        _messageContentsOffset += wholeMessageBytes.length;
        return isComplete();
    }

    public int getMessageType()           { return _messageType; }
    public int getResponseMessageType()   { return _responseMessageType; }
    public int getMessageContentsOffset() { return _messageContentsOffset; }
    public int getMessageContentsLength() { return _messageContentsLength; }
    public byte[] getMessageContents()    { return _messageContents; }

    public boolean isEmpty() {
        TKDebug.dcheck(_messageContents != null || _responseMessageType == 0, TAG, "Caught invalid empty state.");
        TKDebug.dcheck(_messageContents != null || _messageType == 0, TAG, "Caught invalid empty state.");
        TKDebug.dcheck(_messageContents != null || _messageContentsLength == 0, TAG, "Caught invalid empty state.");
        TKDebug.dcheck(_messageContents != null || _messageContentsOffset == 0, TAG, "Caught invalid empty state.");
        return _messageContents == null;
    }

    public void clear() {
        _responseMessageType = 0;
        _messageType = 0;
        _messageContentsLength = 0;
        _messageContents = null;
        _messageContentsOffset = 0;
    }
}
