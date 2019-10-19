package vserhiienko.transferkitty;

import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.concurrent.atomic.AtomicInteger;

public class TKBluetoothCommunicatorExecutor {
    private static final String TAG = TKBluetoothCommunicatorExecutor.class.getSimpleName();
    private static final int EXECUTOR_STATE_IDLE = 0;
    private static final int EXECUTOR_STATE_SCHEDULED = 1;
    private static final int EXECUTOR_STATE_RUNNING = 2;

    private Executor _executor;
    private AtomicInteger _executorState;

    public TKBluetoothCommunicatorExecutor() {
        _executor = Executors.newSingleThreadExecutor();
        _executorState = new AtomicInteger(EXECUTOR_STATE_IDLE);
    }

    public boolean isIdle() {
        return _executorState.get() == EXECUTOR_STATE_IDLE;
    }
    public boolean isRunning() {
        return _executorState.get() == EXECUTOR_STATE_RUNNING;
    }
    public boolean isScheduled() {
        return _executorState.get() == EXECUTOR_STATE_SCHEDULED;
    }

    public void setIdle() {
        _executorState.set(EXECUTOR_STATE_IDLE);
    }
    public void setRunning() {
        _executorState.set(EXECUTOR_STATE_RUNNING);
    }
    public void setScheduled() {
        _executorState.set(EXECUTOR_STATE_SCHEDULED);
    }

    public void execute(Runnable runnable) {
        _executor.execute(runnable);
    }
}
