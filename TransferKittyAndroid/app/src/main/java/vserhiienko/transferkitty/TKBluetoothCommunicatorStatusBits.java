package vserhiienko.transferkitty;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;

@SuppressWarnings("PointlessBitwiseExpression")
public class TKBluetoothCommunicatorStatusBits {
    private static final String TAG = TKBluetoothCommunicatorStatusBits.class.getSimpleName();

    public static final long INITIAL = 0;
    public static final long STARTING_CENTRAL = 1 << 0;
    public static final long CENTRAL = 1 << 1;
    public static final long SCANNING = 1 << 2;
    public static final long RECEIVING = 1 << 3;
    public static final long STARTING_PERIPHERAL = 1 << 4;
    public static final long PERIPHERAL = 1 << 5;
    public static final long ADVERTISING = 1 << 6;
    public static final long SENDING = 1 << 7;
    public static final long CONNECTING = 1 << 8;
    public static final long CONNECTED = 1 << 9;
    public static final long WAITING_FOR_SYSTEM = 1 << 10;
    public static final long WAITING_FOR_USER_INPUT = 1 << 11;
    public static final long UNSUPPORTED = 1 << 12;
    public static final long PANIC = 1 << 13;

    @Contract(pure = true)
    public static boolean isBitSet(final long bits, final long bit) { return (bits & bit) == bit; }
    @Contract(pure = true)
    public static long setBit(final long bits, final long bit) {
        return bits | bit;
    }
    @Contract(pure = true)
    public static long unsetBit(final long bits, final long bit) {
        return bits & ~bit;
    }

    @NotNull
    static String toString(long bits) {
        if (bits == INITIAL) return "INITIAL";
        String s = "";

        if (isBitSet(bits, STARTING_CENTRAL)) s += "STARTING_CENTRAL|";
        if (isBitSet(bits, CENTRAL)) s += "CENTRAL|";
        if (isBitSet(bits, SCANNING)) s += "SCANNING|";
        if (isBitSet(bits, RECEIVING)) s += "RECEIVING|";
        if (isBitSet(bits, STARTING_PERIPHERAL)) s += "STARTING_PERIPHERAL|";
        if (isBitSet(bits, PERIPHERAL)) s += "PERIPHERAL|";
        if (isBitSet(bits, ADVERTISING)) s += "ADVERTISING|";
        if (isBitSet(bits, SENDING)) s += "SENDING|";
        if (isBitSet(bits, CONNECTING)) s += "CONNECTING|";
        if (isBitSet(bits, CONNECTED)) s += "CONNECTED|";
        if (isBitSet(bits, WAITING_FOR_SYSTEM)) s += "WAITING_FOR_SYSTEM|";
        if (isBitSet(bits, WAITING_FOR_USER_INPUT)) s += "WAITING_FOR_USER_INPUT|";
        if (isBitSet(bits, UNSUPPORTED)) s += "UNSUPPORTED|";
        if (isBitSet(bits, PANIC)) s += "PANIC|";

        TKDebug.dcheck(!s.isEmpty(), TAG, "!s.isEmpty()");
        return s.substring(0, s.length() - 1);
    }


}
