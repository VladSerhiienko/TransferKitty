package vserhiienko.transferkitty;

import org.jetbrains.annotations.NotNull;

import java.util.Map;
import java.util.Queue;
import java.util.Set;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ConcurrentLinkedQueue;

public class TKBluetoothCommunicatorScheduledOperations {
    private ConcurrentHashMap<TKBluetoothCommunicatorDevice, ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation>> _ops;

    public TKBluetoothCommunicatorScheduledOperations() {
        _ops = new ConcurrentHashMap<>();
    }

    @SuppressWarnings("BooleanMethodIsAlwaysInverted")
    public boolean schedule(@NotNull final TKBluetoothCommunicatorDevice device,
                            @NotNull final byte[] data,
                            final boolean requiresResponse) {
        ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation> queue = _ops.get(device);
        if (queue == null) { queue = _ops.putIfAbsent(device, new ConcurrentLinkedQueue<>()); }
        if (queue == null) { queue = _ops.get(device); }

        final TKBluetoothCommunicatorScheduledOperation op = new TKBluetoothCommunicatorScheduledOperation(data, requiresResponse);
        queue.add(op);
        return true;
    }

    public boolean isEmpty() {
        final Set<Map.Entry<TKBluetoothCommunicatorDevice, ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation>>> entrySet = _ops.entrySet();
        for (Map.Entry<TKBluetoothCommunicatorDevice, ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation>> entry : entrySet) {
            final ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation> value = entry.getValue();
            if (value != null && !value.isEmpty()) {
                return false;
            }
        }

        return true;
    }

    public void visitDeviceOperations(TKFunc2<TKBluetoothCommunicatorDevice, Queue<TKBluetoothCommunicatorScheduledOperation>, Void> fn) {
        final Set<Map.Entry<TKBluetoothCommunicatorDevice, ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation>>> entrySet = _ops.entrySet();
        for (Map.Entry<TKBluetoothCommunicatorDevice, ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation>> entry : entrySet) {
            final TKBluetoothCommunicatorDevice device = entry.getKey();
            final ConcurrentLinkedQueue<TKBluetoothCommunicatorScheduledOperation> ops = entry.getValue();
            if (device == null || ops == null || ops.isEmpty())
                continue;

            fn.apply(device, ops);
        }
    }
}
