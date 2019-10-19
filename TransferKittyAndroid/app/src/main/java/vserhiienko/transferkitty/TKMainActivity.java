package vserhiienko.transferkitty;

import android.app.AlertDialog;
import android.app.NativeActivity;
import android.content.Context;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.os.Bundle;
import android.util.Log;
import android.view.Choreographer;
import android.view.Choreographer.FrameCallback;
import android.view.View;
import android.view.inputmethod.InputMethodManager;

import com.google.firebase.analytics.FirebaseAnalytics;

import java.lang.reflect.Field;
import java.util.Date;

public class TKMainActivity extends NativeActivity implements FrameCallback {
    private static final String TAG = TKMainActivity.class.getSimpleName();

    public String mCommandLine = "";
    public String mLibName = null;
    public boolean mUseChoreographer = false;
    public boolean mChoreographerSupported = false;
    private FirebaseAnalytics mFirebaseAnalytics = null;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        Log.v(TAG, "onCreate");

        mFirebaseAnalytics = FirebaseAnalytics.getInstance(this);
        Bundle params = new Bundle();
        params.putString("app_tag", TAG);
        params.putString("app_timestamp", new Date().toString());
        mFirebaseAnalytics.logEvent("app_start", params);

        Intent launchIntent = getIntent();
        String extra = launchIntent.getStringExtra("arguments");
        if (extra != null) {
            mCommandLine = extra;
            Log.v(TAG, "command line = " + mCommandLine);
        }

        // Allow the subclass to manually set the library name
        // For the samples it should be the class name, so we
        // fall back gracefully
        if (mLibName == null) {
            // First, use the NativeActivity method
            try {
                ActivityInfo ai = getPackageManager().getActivityInfo(
                    getIntent().getComponent(), PackageManager.GET_META_DATA);
                if (ai.metaData != null) {
                    String ln = ai.metaData.getString(META_DATA_LIB_NAME);
                    if (ln != null)
                        mLibName = ln;
                    ln = ai.metaData.getString(META_DATA_FUNC_NAME);
                    if (ln != null)
                        mLibName = ln;
                }
            } catch (Exception e) {
                Bundle errorBundle = new Bundle();
                errorBundle.putString("exception_message", e.toString());
                mFirebaseAnalytics.logEvent("app_package_manager", errorBundle);
            }

            // Failing that, grab the class name
            if (mLibName == null) {
                mLibName = this.getClass().getSimpleName();
            }
        }

        try {
            // Fail gracefully if we cannot load the lib
            // or if Choreographer is not available
            System.loadLibrary(mLibName);
            Choreographer.getInstance().postFrameCallback(this);
            Log.v(TAG, "Installing Choreo calback");
            mChoreographerSupported = true;
        } catch (Exception e) {
            Bundle errorBundle = new Bundle();
            errorBundle.putString("exception_message", e.toString());
            mFirebaseAnalytics.logEvent("app_load_library", errorBundle);
        }
    }

    /**
     * Called from native application.
     **/
    @SuppressWarnings("unused")
    public void setTrueFullscreen() {
        View windowView =
            (getWindow() != null) ? getWindow().getDecorView() : null;
        if (windowView != null) {
            View root = windowView.getRootView();
            if (root != null) {
                Class aClass = View.class;
                try {
                    Field field = aClass.getField("SYSTEM_UI_FLAG_IMMERSIVE");
                    root.setSystemUiVisibility(
                        View.SYSTEM_UI_FLAG_HIDE_NAVIGATION
                        | (Integer)field.get(null));
                } catch (Exception e) {
                    Bundle errorBundle = new Bundle();
                    errorBundle.putString("exception_message", e.toString());
                    mFirebaseAnalytics.logEvent("app_set_true_fullscreen",
                                                errorBundle);
                }
            }
        }
    }

    /**
     * We call this function from native to display a toast string.
     **/
    @SuppressWarnings("unused")
    public void showAlert(String title, String contents, boolean exitApp) {
        // We need to use a runnable here to ensure that when the spawned
        // native_app_glue thread calls, we actually post the work to the UI
        // thread.  Otherwise, we'll likely get exceptions because there's no
        // prepared Looper on the native_app_glue main thread.
        final String finalTitle = title;
        final String finalContents = contents;
        final boolean finalExit = exitApp;
        runOnUiThread(new Runnable() {
            public void run() {
                AlertDialog.Builder builder =
                    new AlertDialog.Builder(TKMainActivity.this);
                builder.setMessage(finalContents)
                    .setTitle(finalTitle)
                    .setCancelable(true)
                    .setPositiveButton("OK",
                                       new DialogInterface.OnClickListener() {
                                           public void onClick(
                                               DialogInterface dialog, int id) {
                                               dialog.cancel();
                                               if (finalExit)
                                                   TKMainActivity.this.finish();
                                           }
                                       });

                builder.create().show();
            }
        });
    }

    public void doFrame(long frameTimeNanos) {
        if (mUseChoreographer) {
            postRedraw(frameTimeNanos);
            Choreographer.getInstance().postFrameCallback(this);
        }
    }

    /**
     * Called from native application.
     **/
    @SuppressWarnings("unused")
    public boolean useChoreographer(boolean use) {
        if (mChoreographerSupported) {
            mUseChoreographer = use;

            if (mUseChoreographer) {
                runOnUiThread(new Runnable() {
                    public void run() {
                        Choreographer.getInstance().postFrameCallback(
                            TKMainActivity.this);
                    }
                });
            }
            return mUseChoreographer;
        } else {
            return false;
        }
    }

    /**
     * Called from native application.
     **/
    @SuppressWarnings("unused")
    public boolean showKeyboard(boolean show) {
        InputMethodManager imm =
            (InputMethodManager)getSystemService(Context.INPUT_METHOD_SERVICE);
        return imm != null
            && (show ? imm.showSoftInput(this.getWindow().getDecorView(),
                                         InputMethodManager.SHOW_FORCED)
                     : imm.hideSoftInputFromWindow(
                         this.getWindow().getDecorView().getWindowToken(), 0));
    }

    native void postRedraw(long time);
}
