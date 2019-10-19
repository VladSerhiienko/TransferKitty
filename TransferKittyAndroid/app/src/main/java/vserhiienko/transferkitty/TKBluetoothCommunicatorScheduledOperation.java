package vserhiienko.transferkitty;

public class TKBluetoothCommunicatorScheduledOperation {
    private byte[] _data;
    private boolean _requiresResponse;

    public TKBluetoothCommunicatorScheduledOperation(byte[] data, boolean requiresResponse) {
        _data = data;
        _requiresResponse = requiresResponse;
    }

    public byte[] data() { return _data; }
    public boolean requiresResponse() { return _requiresResponse; }
}
