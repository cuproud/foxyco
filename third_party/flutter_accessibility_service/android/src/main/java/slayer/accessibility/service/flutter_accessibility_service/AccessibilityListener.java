package slayer.accessibility.service.flutter_accessibility_service;

import static slayer.accessibility.service.flutter_accessibility_service.Constants.*;
import static slayer.accessibility.service.flutter_accessibility_service.FlutterAccessibilityServicePlugin.CACHED_TAG;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.AccessibilityServiceInfo;
import android.annotation.TargetApi;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Bitmap;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.hardware.HardwareBuffer;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.os.SystemClock;
import android.util.Log;
import android.view.Display;
import android.view.Gravity;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;

import androidx.annotation.RequiresApi;


import com.google.gson.Gson;
import com.google.mlkit.vision.common.InputImage;
import com.google.mlkit.vision.text.Text;
import com.google.mlkit.vision.text.TextRecognition;
import com.google.mlkit.vision.text.TextRecognizer;
import com.google.mlkit.vision.text.latin.TextRecognizerOptions;

import java.util.ArrayList;
import java.util.Collections;
import java.util.HashMap;
import java.util.List;
import java.util.HashSet;
import java.util.Objects;
import java.util.stream.Collectors;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;


public class AccessibilityListener extends AccessibilityService {
    private static volatile AccessibilityListener instance;
    // FoxyCo: per-event walk diagnostics (FOXYCO_WALK logcat). Costs a full
    // extra node scan + per-window getRoot() IPC on every a11y event — keep
    // OFF outside active parser debugging.
    private static final boolean DEBUG_WALK = false;
    private static WindowManager mWindowManager;
    private static FlutterView mOverlayView;
    static private boolean isOverlayShown = false;
    // FoxyCo patch: was 15 — too shallow for Uber Driver, whose RIBs UI nests
    // views 20–40 deep. Chrome (tab bar) sits shallow and was captured; the
    // offer card's $/legs/Accept sit deeper and were truncated away, so Uber
    // reads arrived with only chrome text (device log 2026-07-16). 60 is a
    // recursion-bomb guard, not a tuning knob.
    private static final int DEFAULT_MAX_TREE_DEPTH = 60;
    private int maximumTreeDepth = DEFAULT_MAX_TREE_DEPTH;

    // FoxyCo patch — the "everything hangs" root cause. All of this processing
    // (a depth-60 recursive walk of EVERY same-package window, per-node binder
    // IPC, then Gson-serializing the whole node dump to SharedPreferences) ran
    // on the app process's MAIN thread on every accessibility event (~3/s while
    // an offer card animates). That starved the overlay window's touch handling
    // — unresponsive/undraggable/unclosable bubble and pill, taps not opening
    // the app — and backed parsing up by seconds. Node access is binder IPC and
    // safe off the main thread, so run it all on one background HandlerThread.
    // Queue depth 1: a new event evicts any not-yet-started walk, so we always
    // parse the freshest frame instead of grinding through a stale backlog.
    private static final Handler sWorker;
    private static final Handler sMain = new Handler(Looper.getMainLooper());
    static {
        HandlerThread thread = new HandlerThread("foxyco-a11y");
        thread.start();
        sWorker = new Handler(thread.getLooper());
    }
    private final Object eventLock = new Object();
    private AccessibilityEvent pendingEvent;
    private boolean eventDrainScheduled = false;
    private final Runnable eventDrain = this::drainLatestEvent;
    // Offer windows can finish attaching just after the event that announced
    // them. Re-read twice, then stop; a cooldown prevents animated maps from
    // turning this into continuous polling.
    private static final long POLL_BURST_COOLDOWN_MS = 1500;
    private static final long[] POLL_BURST_DELAYS_MS = {180, 450};
    private long lastPollBurstAt = 0;

    // FoxyCo opt-in OCR. Accessibility nodes remain primary; this path takes
    // one screenshot only when Dart requests a fallback. The bitmap never
    // leaves memory and is cleared immediately after ML Kit finishes.
    public interface OcrCallback {
        void onResult(String packageName, List<String> lines);
    }
    private static final long OCR_TIMEOUT_MS = 1500;
    private OcrCallback pendingOcr;
    private Runnable ocrTimeout;
    private long ocrToken = 0;
    private String pendingOcrPackage = "";
    private TextRecognizer ocrRecognizer;
    private Bitmap activeOcrBitmap;

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onAccessibilityEvent(AccessibilityEvent accessibilityEvent) {
        // Copy: the framework may recycle the event after this callback returns.
        final AccessibilityEvent event = AccessibilityEvent.obtain(accessibilityEvent);
        synchronized (eventLock) {
            // Queue depth one: release the superseded copy instead of removing
            // a Runnable that still owns it. The old removeCallbacks approach
            // leaked every discarded AccessibilityEvent on animated screens.
            if (pendingEvent != null) pendingEvent.recycle();
            pendingEvent = event;
            if (!eventDrainScheduled) {
                eventDrainScheduled = true;
                sWorker.post(eventDrain);
            }
        }
    }

    private void drainLatestEvent() {
        AccessibilityEvent event;
        synchronized (eventLock) {
            event = pendingEvent;
            pendingEvent = null;
        }
        if (event != null) {
            // Keep one framework-safe copy as the package/window seed for the
            // bounded follow-up reads; processEvent recycles its own argument.
            AccessibilityEvent pollSeed = AccessibilityEvent.obtain(event);
            processEvent(event);
            schedulePollBurst(pollSeed);
        }
        synchronized (eventLock) {
            if (pendingEvent != null) {
                sWorker.post(eventDrain);
            } else {
                eventDrainScheduled = false;
            }
        }
    }

    private void schedulePollBurst(AccessibilityEvent seed) {
        final long now = SystemClock.uptimeMillis();
        if (now - lastPollBurstAt < POLL_BURST_COOLDOWN_MS) {
            seed.recycle();
            return;
        }
        lastPollBurstAt = now;
        for (long delay : POLL_BURST_DELAYS_MS) {
            final AccessibilityEvent poll = AccessibilityEvent.obtain(seed);
            sWorker.postDelayed(() -> {
                if (instance == this) {
                    processEvent(poll);
                } else {
                    poll.recycle();
                }
            }, delay);
        }
        seed.recycle();
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    private void processEvent(AccessibilityEvent accessibilityEvent) {
        try {
            final int eventType = accessibilityEvent.getEventType();
            AccessibilityNodeInfo parentNodeInfo = accessibilityEvent.getSource();
            // FoxyCo patch: window-level events (a new window appearing — e.g.
            // Uber's offer card, which is its OWN focused window) routinely carry
            // a NULL source. Upstream bailed here, so the card was never walked
            // and Uber offers were invisible. Fall back to the active window's
            // root — at card time the card IS the active window (ground-truth
            // uiautomator dump 2026-07-16).
            if (parentNodeInfo == null) {
                parentNodeInfo = getRootInActiveWindow();
            }
            AccessibilityWindowInfo windowInfo = null;
            List<String> nextTexts = new ArrayList<>();
            List<Integer> actions = new ArrayList<>();
            List<HashMap<String, Object>> subNodeActions = new ArrayList<>();
            HashSet<AccessibilityNodeInfo> traversedNodes = new HashSet<>();
            HashMap<String, Object> data = new HashMap<>();
            if (parentNodeInfo == null) {
                return;
            }
            String nodeId = generateNodeId(parentNodeInfo);
            String rootPackageName = String.valueOf(parentNodeInfo.getPackageName());
            CharSequence eventPackage = accessibilityEvent.getPackageName();
            // An Uber overlay event can outlive its source node while Lyft is
            // still the active root. Keep the event's package and emit an empty
            // Uber frame instead of mislabelling Lyft text; Dart then requests
            // the opt-in Uber-only OCR fallback without waiting for an app switch.
            String packageName = eventPackage == null || eventPackage.length() == 0
                    ? rootPackageName
                    : eventPackage.toString();
            boolean rootMatchesEvent = packageName.equals(rootPackageName);
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                windowInfo = parentNodeInfo.getWindow();
            }


            Intent intent = new Intent(ACCESSIBILITY_INTENT);

            data.put("mapId", nodeId);
            data.put("packageName", packageName);
            data.put("eventType", eventType);
            data.put("actionType", accessibilityEvent.getAction());
            data.put("eventTime", accessibilityEvent.getEventTime());
            data.put("movementGranularity", accessibilityEvent.getMovementGranularity());
            Rect rect = new Rect();
            parentNodeInfo.getBoundsInScreen(rect);
            data.put("screenBounds", getBoundingPoints(rect));
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.KITKAT) {
                data.put("contentChangeTypes", accessibilityEvent.getContentChangeTypes());
            }
            // FoxyCo patch: fall back to contentDescription. Uber Driver's offer
            // card exposes its content ($, mins, km, Accept) ONLY via
            // contentDescription — getText() is empty on those nodes — so
            // text-only capture reads Uber cards as blank (device log 2026-07-16).
            CharSequence parentText = parentNodeInfo.getText();
            if (parentText == null || parentText.length() == 0) {
                parentText = parentNodeInfo.getContentDescription();
            }
            if (rootMatchesEvent && parentText != null) {
                data.put("capturedText", parentText.toString());
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                data.put("nodeId", parentNodeInfo.getViewIdResourceName());
            }
            // Preserve Android's top-first window ownership. The old code walked
            // the source, active root and every same-package window into one bag;
            // a dismissed lower offer could then be combined with the visible
            // browse/trip window and look live forever.
            List<HashMap<String, Object>> windowSnapshots =
                    collectSamePackageWindows(subNodeActions, packageName);
            // Some OEMs do not expose interactive windows for every event. Keep
            // the source/root walk as a compatibility fallback only.
            if (windowSnapshots.isEmpty() && rootMatchesEvent) {
                getSubNodes(parentNodeInfo, subNodeActions, traversedNodes, 0);
                AccessibilityNodeInfo activeRoot = getRootInActiveWindow();
                if (activeRoot != null
                        && packageName.equals(String.valueOf(activeRoot.getPackageName()))) {
                    getSubNodes(activeRoot, subNodeActions, traversedNodes, 0);
                }
            }
            // FoxyCo diagnostic (2026-07-19, root causes fixed same day): stage
            // counts + text scan proved where card text was lost. Gated OFF now —
            // this ran a full node scan + string build on EVERY a11y event, real
            // battery/CPU load over a shift. Flip DEBUG_WALK to re-arm.
            if (DEBUG_WALK) {
                Log.i("FOXYCO_WALK", "windows=" + windowSnapshots.size()
                        + " total=" + subNodeActions.size()
                        + " srcNull=" + (accessibilityEvent.getSource() == null)
                        + " type=" + eventType);
                int withText = 0; String cardHit = null;
                for (HashMap<String, Object> n : subNodeActions) {
                    Object t = n.get("capturedText");
                    if (t != null && t.toString().trim().length() > 0) {
                        withText++;
                        String s = t.toString();
                        if (cardHit == null && (s.contains("$") || s.contains("Match") || s.contains("Accept") || s.contains("away"))) {
                            cardHit = s.length() > 40 ? s.substring(0, 40) : s;
                        }
                    }
                }
                Log.i("FOXYCO_WALK", "withText=" + withText + " cardHit=" + cardHit);
            }
            data.put("nodesText", nextTexts);
            actions.addAll(parentNodeInfo.getActionList().stream().map(AccessibilityNodeInfo.AccessibilityAction::getId).collect(Collectors.toList()));
            data.put("parentActions", actions);
            data.put("subNodesActions", subNodeActions);
            data.put("windows", windowSnapshots);
            data.put("isClickable", parentNodeInfo.isClickable());
            data.put("isScrollable", parentNodeInfo.isScrollable());
            data.put("isFocusable", parentNodeInfo.isFocusable());
            data.put("isCheckable", parentNodeInfo.isCheckable());
            data.put("isLongClickable", parentNodeInfo.isLongClickable());
            data.put("isEditable", parentNodeInfo.isEditable());
            if (windowInfo != null) {
                data.put("isActive", windowInfo.isActive());
                data.put("isFocused", windowInfo.isFocused());
                data.put("windowType", windowInfo.getType());
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    data.put("isPip", windowInfo.isInPictureInPictureMode());
                }
            }
            storeToSharedPrefs(data);
            intent.putExtra(SEND_BROADCAST, true);
            sendBroadcast(intent);
        } catch (Exception ex) {
            Log.e("EVENT", "onAccessibilityEvent: " + ex.getMessage());
        } finally {
            // Balances the AccessibilityEvent.obtain() copy made on the main thread.
            accessibilityEvent.recycle();
        }
    }

    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        // START_STICKY may recreate the service with a null Intent after the
        // process/service is reclaimed. The OS binding, not this started-service
        // command, owns accessibility monitoring; there is no command to replay.
        // Upstream dereferenced the null Intent and crash-looped on restart.
        if (intent == null) {
            Log.w("CMD_STARTED", "Restarted without an intent; ignoring command");
            return START_NOT_STICKY;
        }
        Log.d("CMD_STARTED", "onStartCommand: " + startId);
        return START_STICKY;
    }


    @RequiresApi(api = Build.VERSION_CODES.N)
    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    void getSubNodes(AccessibilityNodeInfo node, List<HashMap<String, Object>> arr, HashSet<AccessibilityNodeInfo> traversedNodes, int currentDepth) {
        // FoxyCo: no per-node logging here — it fires in a hot recursion on every
        // a11y event and floods logcat / burns main-thread time.
        if (currentDepth >= maximumTreeDepth || node == null) {
            return;
        }
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
            if (traversedNodes.contains(node)) return;
            traversedNodes.add(node);
            // FoxyCo patch — THE Uber root cause (device 2026-07-19). Per-node
            // metadata below is live binder IPC against a window that may die
            // mid-walk. Uber's offer/Radar cards are transient animating windows:
            // getWindow() was checked once, then called AGAIN 3x for
            // isActive/isFocused/getType — the re-call returned null mid-
            // animation and the NPE unwound the whole recursion into
            // processEvent's catch, discarding the ENTIRE frame. Every card
            // frame contains card nodes, so every card frame died and Uber
            // never parsed, while stable map-only frames sailed through.
            // Fix: (a) reuse the ONE getWindow() result, (b) per-node
            // try-catch so a dying node skips itself, never the frame.
            try {
            String mapId = generateNodeId(node);
            AccessibilityWindowInfo windowInfo = null;
            HashMap<String, Object> nested = new HashMap<>();
            Rect rect = new Rect();
            node.getBoundsInScreen(rect);
            windowInfo = node.getWindow();
            nested.put("mapId", mapId);
            nested.put("nodeId", node.getViewIdResourceName());
            // FoxyCo patch: same contentDescription fallback as the event source —
            // Uber's card content lives ONLY in contentDescription.
            CharSequence nodeText = node.getText();
            if (nodeText == null || nodeText.length() == 0) {
                nodeText = node.getContentDescription();
            }
            nested.put("capturedText", nodeText);
            nested.put("screenBounds", getBoundingPoints(rect));
            nested.put("isClickable", node.isClickable());
            nested.put("isScrollable", node.isScrollable());
            nested.put("isFocusable", node.isFocusable());
            nested.put("isCheckable", node.isCheckable());
            nested.put("isLongClickable", node.isLongClickable());
            nested.put("isEditable", node.isEditable());
            nested.put("parentActions", node.getActionList().stream().map(AccessibilityNodeInfo.AccessibilityAction::getId).collect(Collectors.toList()));
            if (windowInfo != null) {
                nested.put("isActive", windowInfo.isActive());
                nested.put("isFocused", windowInfo.isFocused());
                nested.put("windowType", windowInfo.getType());
            }
            arr.add(nested);
            for (int i = 0; i < node.getChildCount(); i++) {
                AccessibilityNodeInfo child = node.getChild(i);
                if (child == null)
                    continue;
                getSubNodes(child, arr, traversedNodes, currentDepth + 1);
            }
            } catch (Exception ex) {
                // Node/window died mid-walk (transient offer card animating away).
                // Skip just this subtree — the rest of the frame must survive.
                Log.d("EVENT", "getSubNodes: skipped dying node: " + ex.getMessage());
            }
        }
    }

    /// Walk every same-package window once, preserving Android's descending
    /// layer order while also filling the legacy flat node list.
    @RequiresApi(api = Build.VERSION_CODES.N)
    private List<HashMap<String, Object>> collectSamePackageWindows(
            List<HashMap<String, Object>> arr, String packageName) {
        List<HashMap<String, Object>> snapshots = new ArrayList<>();
        if (packageName == null) return snapshots;
        try {
            List<AccessibilityWindowInfo> windows = getWindows();
            if (windows == null) return snapshots;
            // FoxyCo diagnostic (2026-07-19, gated with DEBUG_WALK): list every
            // window the service can see. getRoot() is an IPC round-trip per
            // window — too dear to pay on every event once the bug was fixed.
            if (DEBUG_WALK) {
                StringBuilder sb = new StringBuilder();
                for (AccessibilityWindowInfo w : windows) {
                    if (w == null) continue;
                    AccessibilityNodeInfo r = w.getRoot();
                    sb.append('[').append(w.getType()).append(':')
                      .append(r == null ? "nullRoot" : String.valueOf(r.getPackageName()))
                      .append("] ");
                }
                Log.i("FOXYCO_WALK", "windows=" + windows.size() + " " + sb);
            }
            for (AccessibilityWindowInfo window : windows) {
                if (window == null) continue;
                AccessibilityNodeInfo root = window.getRoot();
                if (root == null) continue;
                CharSequence pkg = root.getPackageName();
                if (pkg != null && packageName.equals(pkg.toString())) {
                    List<HashMap<String, Object>> nodes = new ArrayList<>();
                    getSubNodes(root, nodes, new HashSet<>(), 0);
                    if (nodes.isEmpty()) continue;
                    arr.addAll(nodes);
                    HashMap<String, Object> snapshot = new HashMap<>();
                    snapshot.put("windowId", window.getId());
                    snapshot.put("windowLayer", window.getLayer());
                    snapshot.put("isActive", window.isActive());
                    snapshot.put("isFocused", window.isFocused());
                    snapshot.put("windowType", window.getType());
                    snapshot.put("subNodesActions", nodes);
                    snapshots.add(snapshot);
                }
            }
        } catch (Exception ex) {
            Log.e("EVENT", "collectSamePackageWindows: " + ex.getMessage());
        }
        return snapshots;
    }

    private HashMap<String, Integer> getBoundingPoints(Rect rect) {
        HashMap<String, Integer> frame = new HashMap<>();
        frame.put("left", rect.left);
        frame.put("right", rect.right);
        frame.put("top", rect.top);
        frame.put("bottom", rect.bottom);
        frame.put("width", rect.width());
        frame.put("height", rect.height());
        return frame;
    }

    /** True only while Android has this service connected with screenshot capability. */
    public static boolean isOcrAvailable() {
        AccessibilityListener service = instance;
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.R || service == null) return false;
        AccessibilityServiceInfo info = service.getServiceInfo();
        return info != null
                && (info.getCapabilities()
                & AccessibilityServiceInfo.CAPABILITY_CAN_TAKE_SCREENSHOT) != 0;
    }

    /** Requests one memory-only screenshot and returns recognized lines. */
    public static boolean captureOcr(OcrCallback callback) {
        AccessibilityListener service = instance;
        return service != null && service.requestOcr(callback);
    }

    /** Invalidates any pending screenshot/result; late bitmaps are still wiped. */
    public static void cancelOcr() {
        AccessibilityListener service = instance;
        if (service != null) sMain.post(service::cancelOcrInternal);
    }

    private boolean requestOcr(OcrCallback callback) {
        if (callback == null || !isOcrAvailable() || pendingOcr != null) return false;
        final long token = ++ocrToken;
        pendingOcr = callback;
        AccessibilityNodeInfo activeRoot = getRootInActiveWindow();
        CharSequence activePackage = activeRoot == null ? null : activeRoot.getPackageName();
        pendingOcrPackage = activePackage == null ? "" : activePackage.toString();
        ocrTimeout = () -> finishOcr(token, Collections.emptyList());
        sMain.postDelayed(ocrTimeout, OCR_TIMEOUT_MS);
        try {
            takeScreenshot(
                    Display.DEFAULT_DISPLAY,
                    getMainExecutor(),
                    new TakeScreenshotCallback() {
                        @Override
                        public void onSuccess(ScreenshotResult screenshot) {
                            handleScreenshot(token, screenshot);
                        }

                        @Override
                        public void onFailure(int errorCode) {
                            finishOcr(token, Collections.emptyList());
                        }
                    }
            );
        } catch (RuntimeException error) {
            finishOcr(token, Collections.emptyList());
        }
        return true;
    }

    @TargetApi(Build.VERSION_CODES.R)
    private void handleScreenshot(long token, ScreenshotResult screenshot) {
        Bitmap hardwareBitmap = null;
        Bitmap bitmap = null;
        HardwareBuffer buffer = screenshot.getHardwareBuffer();
        try {
            hardwareBitmap = Bitmap.wrapHardwareBuffer(buffer, screenshot.getColorSpace());
            if (hardwareBitmap != null) {
                bitmap = hardwareBitmap.copy(Bitmap.Config.ARGB_8888, true);
            }
        } catch (RuntimeException ignored) {
            // A protected/vanished window can invalidate the hardware buffer.
        } finally {
            if (hardwareBitmap != null) hardwareBitmap.recycle();
            buffer.close();
        }
        if (bitmap == null) {
            finishOcr(token, Collections.emptyList());
            return;
        }
        if (!isCurrentOcr(token)) {
            wipeAndRecycle(bitmap);
            return;
        }
        redactFoxyOverlay(bitmap);
        activeOcrBitmap = bitmap;
        try {
            if (ocrRecognizer == null) {
                ocrRecognizer = TextRecognition.getClient(
                        TextRecognizerOptions.DEFAULT_OPTIONS
                );
            }
            final Bitmap captured = bitmap;
            ocrRecognizer.process(InputImage.fromBitmap(captured, 0))
                    .addOnSuccessListener(result -> {
                        List<Text.Line> lines = new ArrayList<>();
                        for (Text.TextBlock block : result.getTextBlocks()) {
                            lines.addAll(block.getLines());
                        }
                        lines.sort((left, right) -> {
                            Rect a = left.getBoundingBox();
                            Rect b = right.getBoundingBox();
                            int top = Integer.compare(
                                    a == null ? Integer.MAX_VALUE : a.top,
                                    b == null ? Integer.MAX_VALUE : b.top
                            );
                            if (top != 0) return top;
                            return Integer.compare(
                                    a == null ? Integer.MAX_VALUE : a.left,
                                    b == null ? Integer.MAX_VALUE : b.left
                            );
                        });
                        List<String> text = new ArrayList<>();
                        for (Text.Line line : lines) {
                            String value = line.getText().trim();
                            if (!value.isEmpty()) text.add(value);
                        }
                        finishOcr(token, text);
                    })
                    .addOnFailureListener(error ->
                            finishOcr(token, Collections.emptyList()))
                    .addOnCompleteListener(task -> {
                        if (activeOcrBitmap == captured) activeOcrBitmap = null;
                        wipeAndRecycle(captured);
                    });
        } catch (RuntimeException error) {
            activeOcrBitmap = null;
            wipeAndRecycle(bitmap);
            finishOcr(token, Collections.emptyList());
        }
    }

    private boolean isCurrentOcr(long token) {
        return instance == this && pendingOcr != null && ocrToken == token;
    }

    private void finishOcr(long token, List<String> lines) {
        if (!isCurrentOcr(token)) return;
        OcrCallback callback = pendingOcr;
        pendingOcr = null;
        String packageName = pendingOcrPackage;
        pendingOcrPackage = "";
        if (ocrTimeout != null) sMain.removeCallbacks(ocrTimeout);
        ocrTimeout = null;
        callback.onResult(packageName, lines);
    }

    private void cancelOcrInternal() {
        OcrCallback callback = pendingOcr;
        pendingOcr = null;
        String packageName = pendingOcrPackage;
        pendingOcrPackage = "";
        ++ocrToken;
        if (ocrTimeout != null) sMain.removeCallbacks(ocrTimeout);
        ocrTimeout = null;
        if (callback != null) callback.onResult(packageName, Collections.emptyList());
    }

    private static void redactFoxyOverlay(Bitmap bitmap) {
        try {
            Class<?> overlay = Class.forName(
                    "flutter.overlay.window.flutter_overlay_window.OverlayService"
            );
            overlay.getMethod("redactCapture", Bitmap.class).invoke(null, bitmap);
        } catch (ReflectiveOperationException | RuntimeException ignored) {
            // The fox bubble carries no text; strict parsing still fails safe.
        }
    }

    private static void wipeAndRecycle(Bitmap bitmap) {
        if (bitmap == null || bitmap.isRecycled()) return;
        try {
            bitmap.eraseColor(Color.TRANSPARENT);
        } catch (RuntimeException ignored) {
            // Recycling still releases an unexpectedly immutable bitmap.
        } finally {
            bitmap.recycle();
        }
    }


    /// FoxyCo patch (device 2026-07-19): Uber's fullscreen Accept/Exclusive offer
    /// activity sets FLAG_HIDE_NON_SYSTEM_OVERLAY_WINDOWS, which hides every
    /// TYPE_APPLICATION_OVERLAY window (our bubble/pill) for exactly as long as
    /// the card is on screen. TYPE_ACCESSIBILITY_OVERLAY windows are exempt —
    /// but only THIS service's WindowManager can add them. flutter_overlay_window
    /// grabs it via reflection (no gradle coupling) and falls back to the normal
    /// app-overlay type when the service isn't connected.
    public static WindowManager getA11yWindowManager() {
        return instance != null ? mWindowManager : null;
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP_MR1)
    @Override
    protected void onServiceConnected() {
        instance = this;
        mWindowManager = (WindowManager) getSystemService(WINDOW_SERVICE);
        // FoxyCo patch — THE root-cause crash. Upstream unconditionally attaches a
        // FlutterView to this plugin's OWN accessibility-overlay engine
        // (CACHED_TAG, entry point `accessibilityOverlay`). FoxyCo never defines
        // that entry point (we draw our bubble with flutter_overlay_window), so the
        // engine is never created and get(CACHED_TAG) is null → requireNonNull threw
        // an NPE in onServiceConnected → the a11y service CRASH-LOOPED on every
        // connect and never delivered a single event. Only wire the overlay view up
        // if that engine actually exists; otherwise the service still reads content
        // (which is all we use) without crashing.
        FlutterEngine overlayEngine = FlutterEngineCache.getInstance().get(CACHED_TAG);
        if (overlayEngine != null) {
            mOverlayView = new FlutterView(getApplicationContext(), new FlutterTextureView(getApplicationContext()));
            mOverlayView.attachToFlutterEngine(overlayEngine);
            mOverlayView.setFitsSystemWindows(true);
            mOverlayView.setFocusable(true);
            mOverlayView.setFocusableInTouchMode(true);
            mOverlayView.setBackgroundColor(Color.TRANSPARENT);
        }
    }

    @RequiresApi(api = Build.VERSION_CODES.LOLLIPOP_MR1)
    static public void showOverlay(int width, int height, int gravity, boolean clickableThrough) {
        if (!isOverlayShown) {
            WindowManager.LayoutParams lp = new WindowManager.LayoutParams();
            lp.type = WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY;
            lp.format = PixelFormat.TRANSLUCENT;
            lp.width = width;
            lp.height = height;
            if (!clickableThrough) {
                lp.flags |= WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE;
            } else {
                lp.flags |= WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
                        WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;
            }
            lp.gravity = gravity;
            mWindowManager.addView(mOverlayView, lp);
            isOverlayShown = true;
        }
    }

    static public void removeOverlay() {
        if (isOverlayShown) {
            mWindowManager.removeView(mOverlayView);
            isOverlayShown = false;
        }
    }

    @Override
    public void onDestroy() {
        cancelOcrInternal();
        if (ocrRecognizer != null) ocrRecognizer.close();
        ocrRecognizer = null;
        if (activeOcrBitmap != null) wipeAndRecycle(activeOcrBitmap);
        activeOcrBitmap = null;
        synchronized (eventLock) {
            sWorker.removeCallbacks(eventDrain);
            if (pendingEvent != null) pendingEvent.recycle();
            pendingEvent = null;
            eventDrainScheduled = false;
        }
        super.onDestroy();
        instance = null;
        removeOverlay();
        SharedPreferences sharedPreferences = getSharedPreferences(SHARED_PREFS_TAG, MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.remove(ACCESSIBILITY_NODE).apply();
    }

    @Override
    public void onInterrupt() {
        cancelOcrInternal();
    }

    private String generateNodeId(AccessibilityNodeInfo node) {
        return node.getWindowId() + "_" + node.getClassName() + "_" + node.getText() + "_" + node.getContentDescription(); //UUID.randomUUID().toString();
    }

    // FoxyCo: one Gson for the service — was allocated per event (~3/s while a
    // card animates), pure garbage-collector churn on the hot path.
    private static final Gson GSON = new Gson();

    void storeToSharedPrefs(HashMap<String, Object> data) {
        SharedPreferences sharedPreferences = getSharedPreferences(SHARED_PREFS_TAG, MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        String json = GSON.toJson(data);
        editor.putString(ACCESSIBILITY_NODE, json);
        editor.apply();
    }

}
