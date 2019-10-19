package vserhiienko.transferkitty;

import android.util.Log;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;

public class TKDebug {
    private static final String EMPTY_STRING = "";
    private static final String NULL_OBJECT_STRING = "<null>";
    public static TKBluetoothCommunicator _bluetoothCommunicator = null;
    public static TKBluetoothCommunicatorDelegate _bluetoothCommunicatorDelegate = null;

    private static char priorityChar(final int priority) {
        switch (priority) {
            case Log.DEBUG: return 'D';
            case Log.INFO: return 'I';
            case Log.WARN: return 'W';
            case Log.ERROR: return 'E';
            case Log.ASSERT: return 'A';
            default: return 'V';
        }
    }

    public static void dcheck(final boolean condition, @NotNull final String tag, @NotNull final String msg) {
        if (BuildConfig.DEBUG && !condition) {
            Log.e(tag, msg);
            throw new AssertionError(strCat('[', tag, "] Caught error, msg = \"", msg, '\"'));
        }
    }

    public static void dlog(final int priority, @NotNull final String tag, @NotNull final String log) {
        Log.println(priority, tag, log);
        if (BuildConfig.DEBUG && _bluetoothCommunicatorDelegate != null && _bluetoothCommunicator != null) {
            _bluetoothCommunicatorDelegate.bluetoothCommunicatorDidLog(_bluetoothCommunicator, strCat(priorityChar(priority), '/', tag, ' ', log));
        }
    }

    @Contract("!null -> !null")
    private static String toStringOrNullObjectString(Object object) {
        return object != null ? object.toString() : NULL_OBJECT_STRING;
    }

    public static String strCat(Object... objects) {
        if (objects == null || objects.length == 0) { return EMPTY_STRING; }

        StringBuilder result = new StringBuilder(toStringOrNullObjectString(objects[0]));
        for (int i = 1; i < objects.length; ++i) { result.append(toStringOrNullObjectString(objects[i])); }
        return result.toString();
    }
}
