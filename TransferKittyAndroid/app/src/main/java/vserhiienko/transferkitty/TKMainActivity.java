package vserhiienko.transferkitty;

import android.app.AlertDialog;

import android.app.NativeActivity;
import android.content.DialogInterface;
import android.content.Intent;
import android.content.SharedPreferences;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;

import android.preference.PreferenceManager;
import android.util.Log;
import android.view.Choreographer;
import android.view.Choreographer.FrameCallback;
import android.view.KeyEvent;
import android.view.MotionEvent;
import android.view.View;

//import com.android.volley.Request;
//import com.android.volley.RequestQueue;
//import com.android.volley.Response;
//import com.android.volley.VolleyError;
//import com.android.volley.toolbox.StringRequest;
//import com.android.volley.toolbox.Volley;
//import com.google.firebase.analytics.FirebaseAnalytics;

import android.view.inputmethod.InputMethodManager;
import android.content.Context;


import androidx.core.view.MotionEventCompat;

import com.google.firebase.analytics.FirebaseAnalytics;

import java.lang.reflect.Field;
import java.lang.Runnable;
import java.util.Date;

public class TKMainActivity extends NativeActivity implements FrameCallback {
    private static final String TAG = TKMainActivity.class.getSimpleName();

    public String mCommandLine = "";
    public String mLibName = null;
    public boolean mUseChoreographer = false;
    public boolean mChoreographerSupported = false;

     private FirebaseAnalytics mFirebaseAnalytics;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        Log.v("EzriNativeActivity", "Calling EzriNativeActivity onCreate");

        mFirebaseAnalytics = FirebaseAnalytics.getInstance(this);
        Bundle params = new Bundle();
        params.putString("app_tag", TAG);
        params.putString("app_timestamp", new Date().toString());
        mFirebaseAnalytics.logEvent("app_start", params);

        Intent launchIntent = getIntent();
        String extra = launchIntent.getStringExtra("arguments");
        if (extra != null) {
            mCommandLine = extra;
            Log.v("EzriNativeActivity", "command line = " + mCommandLine);
        }

        super.onCreate(savedInstanceState);

        // mFirebaseAnalytics = FirebaseAnalytics.getInstance(this);

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
                    if (ln != null) mLibName = ln;
                    ln = ai.metaData.getString(META_DATA_FUNC_NAME);
                    if (ln != null) mLibName = ln;
                }
            } catch (PackageManager.NameNotFoundException e) {
                // Bundle errorBundle = new Bundle();
                // errorBundle.putString(FirebaseAnalytics.Param.VALUE, e.toString());
                // mFirebaseAnalytics.logEvent(e.getClass().getName(), errorBundle);
            }
            // Failing that, grab the class name
            if (mLibName == null)
                mLibName = this.getClass().getSimpleName();
        }

        try {
            // Fail gracefully if we cannot load the lib
            // or if Choreographer is not available
            System.loadLibrary(mLibName);
            Choreographer.getInstance().postFrameCallback(this);
            Log.v("EzriNativeActivity", "Installing Choreo calback");
            mChoreographerSupported = true;
        } catch (Exception e) {
            // Bundle errorBundle = new Bundle();
            // errorBundle.putString(FirebaseAnalytics.Param.VALUE, e.toString());
            // mFirebaseAnalytics.logEvent(e.getClass().getName(), errorBundle);
        }

        Log.v("EzriNativeActivity", "Exiting EzriNativeActivity onCreate");
    }

    /**
     * Called from native application.
     **/
    @SuppressWarnings("unused")
    public void setTrueFullscreen() {
        View windowView = (getWindow() != null) ? getWindow().getDecorView() : null;
        if (windowView != null) {
            View root = windowView.getRootView();
            if (root != null) {
                Class aClass = View.class;
                try {
                    Field field = aClass.getField("SYSTEM_UI_FLAG_IMMERSIVE");
                    root.setSystemUiVisibility(
                            View.SYSTEM_UI_FLAG_HIDE_NAVIGATION |
                                    (Integer) field.get(null));
                } catch (Exception e) {
                    // Bundle errorBundle = new Bundle();
                    // errorBundle.putString(FirebaseAnalytics.Param.VALUE, e.toString());
                    // mFirebaseAnalytics.logEvent(e.getClass().getName(), errorBundle);
                }
            }
        }
    }

    @Override
    public boolean onTouchEvent(MotionEvent event){
        int action = event.getAction(); //MotionEventCompat.getActionMasked(event);

        switch(action) {
            case (MotionEvent.ACTION_DOWN) :
                Log.d(TAG,"Action was DOWN");
                return true;
            case (MotionEvent.ACTION_MOVE) :
                Log.d(TAG,"Action was MOVE");
                return true;
            case (MotionEvent.ACTION_UP) :
                Log.d(TAG,"Action was UP");
                return true;
            case (MotionEvent.ACTION_CANCEL) :
                Log.d(TAG,"Action was CANCEL");
                return true;
            case (MotionEvent.ACTION_OUTSIDE) :
                Log.d(TAG,"Movement occurred outside bounds " +
                        "of current screen element");
                return true;
            default :
                return super.onTouchEvent(event);
        }
    }

    @Override
    public boolean onKeyDown(int keyCode, KeyEvent event) {

        switch (keyCode) {
            case KeyEvent.KEYCODE_A: {
                //your Action code
                return true;
            }
        }
        return super.onKeyDown(keyCode, event);
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
                AlertDialog.Builder builder = new AlertDialog.Builder(TKMainActivity.this);
                builder.setMessage(finalContents)
                        .setTitle(finalTitle)
                        .setCancelable(true)
                        .setPositiveButton("OK", new DialogInterface.OnClickListener() {
                            public void onClick(DialogInterface dialog, int id) {
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
        InputMethodManager imm = (InputMethodManager) getSystemService(Context.INPUT_METHOD_SERVICE);
        return imm != null && (show ? imm.showSoftInput(this.getWindow().getDecorView(), InputMethodManager.SHOW_FORCED)
                : imm.hideSoftInputFromWindow(this.getWindow().getDecorView().getWindowToken(), 0));
    }

    native void postRedraw(long time);
}
