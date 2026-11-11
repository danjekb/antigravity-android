package com.agy.bridge;

import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.util.Log;
import android.webkit.JavascriptInterface;

import com.agy.util.AppFileProvider;

import org.json.JSONObject;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileOutputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

/**
 * Native bridge for Settings > Tools and Security Shield operations.
 * Executes operations via agy_tools.sh in the background.
 */
public final class AgyToolsBridge {

    private static final String TAG = "AgyToolsBridge";
    private final Context context;
    private final ExecutorService executor = Executors.newCachedThreadPool();
    private final Map<String, JobState> jobs = new ConcurrentHashMap<>();

    private static class JobState {
        volatile String rc = "";
        final StringBuilder log = new StringBuilder();
        Process process;
    }

    public AgyToolsBridge(Context context) {
        this.context = context.getApplicationContext();
        ensureScript();
    }

    private File getScriptFile() {
        return new File(context.getFilesDir(), "bin/agy_tools.sh");
    }

    private void ensureScript() {
        try {
            File scriptFile = getScriptFile();
            if (scriptFile.getParentFile() != null && !scriptFile.getParentFile().exists()) {
                scriptFile.getParentFile().mkdirs();
            }
            try (InputStream in = context.getAssets().open("web/agy_tools.sh");
                 FileOutputStream out = new FileOutputStream(scriptFile)) {
                byte[] buf = new byte[8192];
                int len;
                while ((len = in.read(buf)) > 0) {
                    out.write(buf, 0, len);
                }
            } catch (Exception ignored) {
                // Asset might already be extracted or available via alternate path
            }
            if (scriptFile.exists()) {
                scriptFile.setExecutable(true, false);
                scriptFile.setReadable(true, false);
            }
        } catch (Exception e) {
            Log.w(TAG, "Failed to ensure script: " + e.getMessage());
        }
    }

    @JavascriptInterface
    public String start(final String op, final String arg) {
        final String jobId = "job_" + System.currentTimeMillis() + "_" + UUID.randomUUID().toString().substring(0, 4);
        final JobState state = new JobState();
        jobs.put(jobId, state);

        executor.submit(() -> {
            try {
                File script = getScriptFile();
                if (!script.exists() || script.length() == 0) {
                    File[] candidates = new File[]{
                            new File(context.getFilesDir(), "web/agy_tools.sh"),
                            new File(context.getFilesDir(), "usr/bin/agy-tools"),
                            new File(context.getFilesDir(), "../app_assets/web/agy_tools.sh")
                    };
                    for (File c : candidates) {
                        if (c.exists() && c.length() > 0) {
                            script = c;
                            break;
                        }
                    }
                }
                if (script.exists()) {
                    script.setExecutable(true, false);
                    script.setReadable(true, false);
                }

                String home = context.getFilesDir().getAbsolutePath();
                String prefix = home + "/usr";

                File bashBin = new File(prefix, "bin/bash");
                String shell = bashBin.canExecute() ? bashBin.getAbsolutePath() : "/system/bin/sh";

                ProcessBuilder pb = new ProcessBuilder(shell, script.getAbsolutePath(), op, arg != null ? arg : "");
                pb.redirectErrorStream(true);
                pb.environment().put("HOME", home);
                pb.environment().put("PREFIX", prefix);
                pb.environment().put("PATH", prefix + "/bin:" + home + "/runtime/bin:/system/bin:" + System.getenv("PATH"));
                pb.environment().remove("LD_LIBRARY_PATH");
                pb.directory(context.getFilesDir());

                Process proc = pb.start();
                state.process = proc;

                try (BufferedReader reader = new BufferedReader(new InputStreamReader(proc.getInputStream(), StandardCharsets.UTF_8))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        synchronized (state.log) {
                            state.log.append(line).append("\n");
                        }
                    }
                }

                int code = proc.waitFor();
                state.rc = String.valueOf(code);
            } catch (Exception e) {
                Log.w(TAG, "Job " + jobId + " failed: " + e.getMessage());
                synchronized (state.log) {
                    state.log.append("\n@@error ").append(e.getMessage()).append("\n");
                }
                state.rc = "1";
            }
        });

        return jobId;
    }

    @JavascriptInterface
    public String read(String id) {
        JobState state = jobs.get(id);
        if (state == null) {
            return "{\"rc\":\"1\",\"log\":\"job not found\"}";
        }
        JSONObject obj = new JSONObject();
        try {
            obj.put("rc", state.rc);
            synchronized (state.log) {
                obj.put("log", state.log.toString());
            }
        } catch (Exception ignored) {}
        return obj.toString();
    }

    @JavascriptInterface
    public String readTail(String id, int maxLines) {
        return read(id);
    }

    @JavascriptInterface
    public void cancel(String id) {
        JobState state = jobs.get(id);
        if (state != null && state.process != null) {
            try {
                state.process.destroy();
            } catch (Exception ignored) {}
            state.rc = "130";
        }
    }

    @JavascriptInterface
    public void installApk(String path) {
        try {
            File apkFile = new File(path);
            if (!apkFile.exists()) return;
            Intent intent = new Intent(Intent.ACTION_VIEW);
            Uri apkUri = AppFileProvider.getUriForFile(context, apkFile);
            intent.addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
            intent.setDataAndType(apkUri, "application/vnd.android.package-archive");
            intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
            context.startActivity(intent);
        } catch (Exception e) {
            Log.w(TAG, "installApk failed: " + e.getMessage());
        }
    }
}
