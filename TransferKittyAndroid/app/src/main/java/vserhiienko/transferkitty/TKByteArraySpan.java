package vserhiienko.transferkitty;

import org.jetbrains.annotations.Contract;
import org.jetbrains.annotations.NotNull;
import org.jetbrains.annotations.Nullable;

@SuppressWarnings("WeakerAccess")
public class TKByteArraySpan {
    private static final String TAG = TKByteArraySpan.class.getSimpleName();

    @NotNull
    public final byte[] bytes;
    public final int offset;
    public final int length;

    public TKByteArraySpan(@NotNull final byte[] arr, final int off, final int len) {
        TKDebug.dcheck(off < arr.length, TAG, "Caught invalid span offset.");
        TKDebug.dcheck(len <= arr.length, TAG, "Caught invalid span length.");

        bytes = arr;
        offset = off;
        length = len;
    }

    public TKByteArraySpan(@NotNull final byte[] arr, final int off) {
        TKDebug.dcheck(off < arr.length, TAG, "Caught invalid span offset.");

        bytes = arr;
        offset = off;
        length = arr.length - off;
    }

    public TKByteArraySpan(@NotNull final byte[] arr) {
        bytes = arr;
        offset = 0;
        length = arr.length;
    }

    public TKByteArraySpan subspan(final int off, final int len) {
        TKDebug.dcheck(off < length, TAG, "Caught invalid subspan offset.");
        TKDebug.dcheck(len <= (off + length), TAG, "Caught invalid subspan length.");
        return new TKByteArraySpan(bytes, offset + off, len);
    }

    public TKByteArraySpan first(final int len) {
        TKDebug.dcheck(len <= length, TAG, "Caught invalid subspan length.");
        return subspan(0, len);
    }

    public TKByteArraySpan last(final int len) {
        TKDebug.dcheck(len <= length, TAG, "Caught invalid subspan length.");
        return subspan(length - len, len);
    }

    @NotNull
    @Contract(value = "_ -> new", pure = true)
    public static TKByteArraySpan makeSpan(@NotNull final byte[] bytes) {
        return new TKByteArraySpan(bytes);
    }

    @Nullable
    public static TKByteArraySpan makeSpanOrNull(@NotNull final byte[] bytes, final int off) {
        if (off < bytes.length)
            return new TKByteArraySpan(bytes, off);

        return null;
    }
}
