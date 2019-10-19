package vserhiienko.transferkitty;

import android.app.DownloadManager;
import android.content.Context;
import android.util.Log;

//import com.google.firebase.database.annotations.NotNull;
import org.jetbrains.annotations.NotNull;

import java.io.File;
import java.io.FileOutputStream;

import static android.content.Context.DOWNLOAD_SERVICE;
import static android.os.Environment.DIRECTORY_DOWNLOADS;
import static android.os.Environment.getExternalStoragePublicDirectory;

@SuppressWarnings("WeakerAccess")
public class TKFileSaver {
    private static final String TAG = TKFileSaver.class.getSimpleName();

    public static void saveFile(@NotNull final Context appContext, @NotNull final String fileName, @NotNull final TKByteArraySpan fileData) {
        final File downloadDirectory = getExternalStoragePublicDirectory(DIRECTORY_DOWNLOADS);
        TKDebug.dcheck(downloadDirectory != null && downloadDirectory.isDirectory(), TAG, "Caught invalid download directory.");

        // TODO: What does a term "file owner" mean in this API?
        final File receivedFile = new File(downloadDirectory, fileName);
        if (!receivedFile.setWritable(true)) { TKDebug.dlog(Log.ERROR, TAG, "Failed to enable writing for a received file."); }
        if (!receivedFile.setReadable(true)) { TKDebug.dlog(Log.ERROR, TAG, "Failed to enable reading for a received file."); }

        try {
            final FileOutputStream os = new FileOutputStream(receivedFile);
            os.write(fileData.bytes, fileData.offset, fileData.length);
            os.close();

            final DownloadManager downloadManager = (DownloadManager) appContext.getSystemService(DOWNLOAD_SERVICE);
            if (downloadManager != null) {

                final boolean scannable = true;
                final boolean notification = true;
                final String binaryMime = "application/octet-stream";

                downloadManager.addCompletedDownload(
                        receivedFile.getName(),
                        receivedFile.getName(),
                        scannable,
                        binaryMime,
                        receivedFile.getAbsolutePath(),
                        receivedFile.length(),
                        notification);

            } else {
                TKDebug.dlog(Log.ERROR, TAG, "Caught null download manager.");
            }

        } catch (Exception e) {
            // FileNotFoundException
            // IOException

            TKDebug.dlog(Log.ERROR, TAG, e.getMessage());
            e.printStackTrace();
        }
    }
}
