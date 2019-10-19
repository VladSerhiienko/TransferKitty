package vserhiienko.transferkitty;

import android.os.Build;
import androidx.annotation.NonNull;
import androidx.annotation.RequiresApi;
import android.util.Log;

import org.jetbrains.annotations.NotNull;

import java.util.Arrays;
import java.util.Queue;

import static vserhiienko.transferkitty.TKBluetoothCommunicatorMessage.*;


/* TODO(vserhiienko.transferkitty), this should definitely be optimized.
 * The main idea is to have multiple write providers, each one should be associated with a device.
 * Those providers should fetch small writes from queued messages that can fit into negotiated MTU size.
 */
@RequiresApi(api = Build.VERSION_CODES.LOLLIPOP)
public class TKBluetoothCommunicatorScheduler {
    private static final String TAG = TKBluetoothCommunicatorScheduler.class.getSimpleName();

    private TKBluetoothCommunicatorExecutor _writeExecutor;
    private TKBluetoothCommunicatorScheduledOperations _scheduledWrites;

    private TKBluetoothCommunicatorExecutor _readExecutor;
    private TKBluetoothCommunicatorScheduledOperations _scheduledReads;

    private TKBluetoothCommunicator _bluetoothCommunicator;
    private TKBluetoothCommunicatorEncoder _encoder;
    private TKBluetoothCommunicatorDecoder _decoder;

    public TKBluetoothCommunicatorScheduler(TKBluetoothCommunicator bluetoothCommunicator) {
        TKDebug.dcheck(bluetoothCommunicator != null, TAG, "bluetoothCommunicator != null");

        _scheduledWrites = new TKBluetoothCommunicatorScheduledOperations();
        _writeExecutor = new TKBluetoothCommunicatorExecutor();

        _scheduledReads = new TKBluetoothCommunicatorScheduledOperations();
        _readExecutor = new TKBluetoothCommunicatorExecutor();

        _bluetoothCommunicator = bluetoothCommunicator;
        _encoder = new TKBluetoothCommunicatorEncoder(bluetoothCommunicator);
        _decoder = new TKBluetoothCommunicatorDecoder(bluetoothCommunicator);
    }

    public void flush() {
        TKDebug.dlog(Log.VERBOSE, TAG, "flush");

        if (_writeExecutor.isIdle()) {
            _writeExecutor.setScheduled();
            _writeExecutor.execute(this::executeWrites);
        }

        if (_readExecutor.isIdle()) {
            _readExecutor.setScheduled();
            _readExecutor.execute(this::executeReads);
        }
    }

    private boolean scheduleWrite(@NotNull final TKBluetoothCommunicatorDevice device,
                                  @NotNull final byte[] data,
                                  final boolean requiresResponse) {
        if (!_scheduledWrites.schedule(device, data, requiresResponse)) { return false; }

        flush();
        return true;
    }

    public boolean scheduleRead(@NotNull final TKBluetoothCommunicatorDevice device,
                                @NotNull final byte[] data) {
        if (!_scheduledReads.schedule(device, data, false)) { return false; }

        flush();
        return true;
    }

    private static boolean hasScheduledOperations(@NotNull final TKBluetoothCommunicatorExecutor executor,
                                                  @NotNull final TKBluetoothCommunicatorScheduledOperations ops) {
        if (ops.isEmpty()) {
            executor.setIdle();
            return false;
        }

        executor.setRunning();
        return true;
    }

    private void executeReads() {
        TKDebug.dcheck(_readExecutor.isScheduled(), TAG, "_readExecutor.isScheduled()");
        TKDebug.dlog(Log.DEBUG, TAG, "executeReads");

        while (hasScheduledOperations(_readExecutor, _scheduledReads)) {
            _scheduledReads.visitDeviceOperations((@NotNull final TKBluetoothCommunicatorDevice device,
                                                   @NotNull final Queue<TKBluetoothCommunicatorScheduledOperation> reads) -> {
                final TKBluetoothCommunicatorScheduledOperation readOp = reads.poll();
                if (readOp == null) { return null; }
                if (readOp.data() == null) { return null; }

                device.clearPendingWrite();
                final int responseMessageType = _decoder.processMessageReturnResponseMessageType(device, readOp.data());

                byte[] response = _encoder.buildResponseMessage(device, responseMessageType);
                if (response != null) {
                    scheduleWrite(device, response, true);
                } else {
                    flush();
                }

                return null;
            });
        }
    }

    private void submitWrite(@NotNull final TKBluetoothCommunicatorDevice device,
                            @NotNull final byte[] write) {
        _bluetoothCommunicator.bluetoothGattServerSetValue(device, write);
    }

    private void executeWrites() {
        TKDebug.dcheck(_writeExecutor.isScheduled(), TAG, "_writeExecutor.isScheduled()");
        TKDebug.dlog(Log.DEBUG, TAG, "executeWrites");

        while (hasScheduledOperations(_writeExecutor, _scheduledWrites)) {
            _scheduledWrites.visitDeviceOperations((@NotNull final TKBluetoothCommunicatorDevice device,
                                                    @NotNull final Queue<TKBluetoothCommunicatorScheduledOperation> writes) -> {
                if (device.getPendingWrite()) { return null; }

                final TKBluetoothCommunicatorScheduledOperation writeOp = writes.poll();
                if (writeOp == null) { return null; }
                if (writeOp.data() == null) { return null; }

                if (writeOp.requiresResponse()) {
                    TKDebug.dlog(Log.INFO, TAG, "Setting pending write.");
                    device.setPendingWrite();
                }

                submitWrite(device, writeOp.data());
                return null;
            });
        }
    }

    private boolean scheduleMessageTo(@NonNull final TKBluetoothCommunicatorDevice device,
                                      @NotNull byte[] messageBytes) {
        TKDebug.dlog(Log.DEBUG, TAG, "scheduleMessageTo, device = " + device.toString());

        if (messageBytes.length <= device.getConnectionMTU()) {
            return scheduleWrite(device, messageBytes, requiresResponse(messageBytes));
        } else {
            int messageChunkFrom = 0;
            while (messageChunkFrom < messageBytes.length) {

                int writableLength = messageBytes.length - messageChunkFrom;
                writableLength = Math.min(device.getConnectionMTU(), writableLength);
                TKDebug.dcheck(writableLength > 0, TAG, "writableLength > 0");

                final int messageChunkTo = messageChunkFrom + writableLength;

                final byte[] messageChunk = Arrays.copyOfRange(messageBytes, messageChunkFrom, messageChunkTo);
                if (!scheduleWrite(device, messageChunk, true)) {
                    return false;
                }

                messageChunkFrom += writableLength;
            }
        }

        return true;
    }

    public void scheduleMessageToOrPanic(@NonNull final TKBluetoothCommunicatorDevice device,
                                         @NotNull byte[] messageBytes) {
        TKDebug.dlog(Log.DEBUG, TAG, "scheduleMessageToOrPanic, device = " + device.toString());

        if (!scheduleMessageTo(device, messageBytes)) {
            _bluetoothCommunicator.panic(device);
        }
    }

    private boolean scheduleFileMessageTo(@NonNull final TKBluetoothCommunicatorDevice device,
                                          @NotNull String fileName,
                                          @NotNull byte[] fileContents,
                                          final int responseMessageType) {
        TKDebug.dlog(Log.DEBUG, TAG, "scheduleFileMessageTo, device = " + device.toString());

        final byte[] messageBytes = _encoder.composeFileMessage(device, fileName, fileContents, responseMessageType);
        return scheduleMessageTo(device, messageBytes);
    }

    public void scheduleFileMessageToOrPanic(@NonNull final TKBluetoothCommunicatorDevice device,
                                             @NotNull String fileName,
                                             @NotNull byte[] fileContents,
                                             final int responseMessageType) {
        if (!scheduleFileMessageTo(device, fileName, fileContents, responseMessageType)) {
            _bluetoothCommunicator.panic(device);
        }
    }

    public void scheduleIntroductionMessagesTo(@NotNull final TKBluetoothCommunicatorDevice device) {
        TKDebug.dlog(Log.DEBUG, TAG, "scheduleIntroductionMessagesTo");

        final byte[] uuidMsg = _encoder.composeMessage(device,
                uuidToBytes(_bluetoothCommunicator.getUUID()),
                BTCM_MESSAGE_TYPE_UUID,
                BTCM_MESSAGE_TYPE_UUID);
        scheduleMessageToOrPanic(device, uuidMsg);

        final byte[] nameMsg = _encoder.composeMessage(device,
                _bluetoothCommunicator.getName().getBytes(),
                BTCM_MESSAGE_TYPE_NAME,
                BTCM_MESSAGE_TYPE_NAME);
        scheduleMessageToOrPanic(device, nameMsg);

        final byte[] modelMsg = _encoder.composeMessage(device,
                _bluetoothCommunicator.getModel().getBytes(),
                BTCM_MESSAGE_TYPE_DEVICE_MODEL,
                BTCM_MESSAGE_TYPE_DEVICE_MODEL);
        scheduleMessageToOrPanic(device, modelMsg);

        final byte[] prodMsg = _encoder.composeMessage(device,
                _bluetoothCommunicator.getFriendlyModel().getBytes(),
                BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL,
                BTCM_MESSAGE_TYPE_DEVICE_FRIENDLY_MODEL);
        scheduleMessageToOrPanic(device, prodMsg);
    }
}
