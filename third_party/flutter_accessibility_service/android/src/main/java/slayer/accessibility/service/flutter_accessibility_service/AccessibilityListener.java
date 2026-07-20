package slayer.accessibility.service.flutter_accessibility_service;

import static slayer.accessibility.service.flutter_accessibility_service.Constants.*;
import static slayer.accessibility.service.flutter_accessibility_service.FlutterAccessibilityServicePlugin.CACHED_TAG;

import android.accessibilityservice.AccessibilityService;
import android.accessibilityservice.GestureDescription;
import android.annotation.TargetApi;
import android.content.Intent;
import android.content.SharedPreferences;
import android.graphics.Color;
import android.graphics.Path;
import android.graphics.PixelFormat;
import android.graphics.Rect;
import android.os.Build;
import android.os.Handler;
import android.os.HandlerThread;
import android.os.Looper;
import android.util.Log;
import android.util.LruCache;
import android.view.Gravity;
import android.view.WindowManager;
import android.view.accessibility.AccessibilityEvent;
import android.view.accessibility.AccessibilityNodeInfo;
import android.view.accessibility.AccessibilityWindowInfo;

import androidx.annotation.RequiresApi;


import com.google.gson.Gson;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.HashSet;
import java.util.Objects;
import java.util.stream.Collectors;

import io.flutter.plugin.common.MethodChannel;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;


public class AccessibilityListener extends AccessibilityService {
    private static AccessibilityListener instance;
    // FoxyCo: per-event walk diagnostics (FOXYCO_WALK logcat). Costs a full
    // extra node scan + per-window getRoot() IPC on every a11y event — keep
    // OFF outside active parser debugging.
    private static final boolean DEBUG_WALK = false;
    private static WindowManager mWindowManager;
    private static FlutterView mOverlayView;
    static private boolean isOverlayShown = false;
    // FoxyCo patch: LruCache's ctor arg is ENTRY COUNT (default sizeOf() == 1),
    // not bytes — the old 4*1024*1024 retained ~4M AccessibilityNodeInfo
    // snapshots, an unbounded leak in practice (every node of every walk is
    // stored). FoxyCo never taps gig-app nodes, so a small cache is plenty.
    private static final int CACHE_SIZE = 512;
    private static final int maxDepth = 20;
    private static LruCache<String, AccessibilityNodeInfo> nodeMap =
            new LruCache<>(CACHE_SIZE);
    // FoxyCo patch: was 15 — too shallow for Uber Driver, whose RIBs UI nests
    // views 20–40 deep. Chrome (tab bar) sits shallow and was captured; the
    // offer card's $/legs/Accept sit deeper and were truncated away, so Uber
    // reads arrived with only chrome text (device log 2026-07-16). 60 is a
    // recursion-bomb guard, not a tuning knob.
    private static final int DEFAULT_MAX_TREE_DEPTH = 60;
    private int maximumTreeDepth = DEFAULT_MAX_TREE_DEPTH;

    public static AccessibilityNodeInfo getNodeInfo(String id) {
        return nodeMap.get(id);
    }

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
    static {
        HandlerThread thread = new HandlerThread("foxyco-a11y");
        thread.start();
        sWorker = new Handler(thread.getLooper());
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onAccessibilityEvent(AccessibilityEvent accessibilityEvent) {
        // Copy: the framework may recycle the event after this callback returns.
        final AccessibilityEvent event = AccessibilityEvent.obtain(accessibilityEvent);
        sWorker.removeCallbacksAndMessages(null); // coalesce — latest frame wins
        sWorker.post(() -> processEvent(event));
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
            String packageName = parentNodeInfo.getPackageName().toString();
            storeNode(nodeId, parentNodeInfo);
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
            if (parentText != null) {
                data.put("capturedText", parentText.toString());
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                data.put("nodeId", parentNodeInfo.getViewIdResourceName());
            }
            getSubNodes(parentNodeInfo, subNodeActions, traversedNodes, 0);
            final int nAfterSource = subNodeActions.size();
            // FoxyCo patch: ALSO walk the active window's ROOT. The event source
            // is only the subtree that fired the event — on Uber that's the map
            // container, while the offer card is a SIBLING subtree that never
            // fires its own events. uiautomator (which dumps from the active
            // root) sees the card fine; source-only traversal never does
            // (ground-truth dump 2026-07-16, $15.18 card present at depth 19).
            // traversedNodes dedupes the overlap with the source subtree.
            AccessibilityNodeInfo activeRoot = getRootInActiveWindow();
            if (activeRoot != null && packageName.equals(String.valueOf(activeRoot.getPackageName()))) {
                getSubNodes(activeRoot, subNodeActions, traversedNodes, 0);
            }
            final int nAfterActive = subNodeActions.size();
            // FoxyCo patch: the event source is only ONE node's subtree. An offer
            // card that lives in a SEPARATE window (e.g. Uber's card drawn over the
            // map) is never in that subtree when the event fires from another window,
            // so it never reaches the parser (Uber gap) and a valid pill flickers
            // out the instant a map-window event yields no card. Traverse EVERY
            // window that belongs to the same package and merge its nodes into the
            // same flat list. The shared traversedNodes set dedupes overlaps, so the
            // active window isn't double-counted (which would e.g. give Lyft 4 legs
            // instead of 2). Package-scoped so our own overlay pill, the status/nav
            // bars, and the IME never leak their text into the gig app's read.
            // NOTE: a bisect once shipped with this line commented out — that broke
            // Uber AND Hopp parsing entirely (their cards are separate windows).
            // Keep it enabled.
            collectSamePackageWindows(subNodeActions, traversedNodes, packageName);
            // FoxyCo diagnostic (2026-07-19, root causes fixed same day): stage
            // counts + text scan proved where card text was lost. Gated OFF now —
            // this ran a full node scan + string build on EVERY a11y event, real
            // battery/CPU load over a shift. Flip DEBUG_WALK to re-arm.
            if (DEBUG_WALK) {
                Log.i("FOXYCO_WALK", "src=" + nAfterSource
                        + " active=" + (nAfterActive - nAfterSource)
                        + " windows=" + (subNodeActions.size() - nAfterActive)
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
        boolean globalAction = intent.getBooleanExtra(INTENT_GLOBAL_ACTION, false);
        boolean systemActions = intent.getBooleanExtra(INTENT_SYSTEM_GLOBAL_ACTIONS, false);
        if (systemActions && android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.R) {
            List<Integer> actions = getSystemActions().stream().map(AccessibilityNodeInfo.AccessibilityAction::getId).collect(Collectors.toList());
            Intent broadcastIntent = new Intent(BROD_SYSTEM_GLOBAL_ACTIONS);
            broadcastIntent.putIntegerArrayListExtra("actions", new ArrayList<>(actions));
            sendBroadcast(broadcastIntent);
        }
        if (globalAction) {
            int actionId = intent.getIntExtra(INTENT_GLOBAL_ACTION_ID, 8);
            performGlobalAction(actionId);
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
            storeNode(mapId, node);
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

    /// FoxyCo patch: walk every window that belongs to `packageName` and append
    /// its nodes into the same flat list the event-source traversal filled. This
    /// is what surfaces an offer card living in its own window (Uber draws its
    /// card as a separate window over the map, so it never appears under the map
    /// window's event source). Package-scoped so system windows, the IME, and our
    /// own overlay bubble/pill never bleed their text into the gig app's read; the
    /// shared `traversedNodes` set means the active window that fired the event is
    /// not traversed twice. Fails soft — any window error is swallowed so a single
    /// bad window can't drop the whole read.
    @RequiresApi(api = Build.VERSION_CODES.N)
    private void collectSamePackageWindows(List<HashMap<String, Object>> arr,
                                           HashSet<AccessibilityNodeInfo> traversedNodes,
                                           String packageName) {
        if (packageName == null) return;
        try {
            List<AccessibilityWindowInfo> windows = getWindows();
            if (windows == null) return;
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
            // FoxyCo: MUST pass the SHARED traversedNodes set. A diagnostic build
            // once walked each window into a separate set — every node the event
            // source already captured was appended AGAIN, so every leg line
            // appeared twice and foldLegs summed doubled distances (the
            // "39.2 km for a 19.6 km ride" pill-math bug, screenshots 2026-07-17).
            for (AccessibilityWindowInfo window : windows) {
                if (window == null) continue;
                AccessibilityNodeInfo root = window.getRoot();
                if (root == null) continue;
                CharSequence pkg = root.getPackageName();
                if (pkg != null && packageName.equals(pkg.toString())) {
                    getSubNodes(root, arr, traversedNodes, 0);
                }
            }
        } catch (Exception ex) {
            Log.e("EVENT", "collectSamePackageWindows: " + ex.getMessage());
        }
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
        super.onDestroy();
        instance = null;
        removeOverlay();
        SharedPreferences sharedPreferences = getSharedPreferences(SHARED_PREFS_TAG, MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        editor.remove(ACCESSIBILITY_NODE).apply();
    }

    @Override
    public void onInterrupt() {
    }

    @SuppressWarnings("unchecked")
    @RequiresApi(api = Build.VERSION_CODES.N)
    public static void performDispatchGesture(List<Object> strokes, MethodChannel.Result result) {
        if (instance == null) {
            result.success(false);
            return;
        }
        try {
            GestureDescription.Builder gestureBuilder = new GestureDescription.Builder();
            for (Object strokeObj : strokes) {
                Map<String, Object> stroke = (Map<String, Object>) strokeObj;
                List<Object> pointObjs = (List<Object>) stroke.get("path");
                int startTime = ((Number) stroke.get("startTime")).intValue();
                int duration = ((Number) stroke.get("duration")).intValue();

                Path path = new Path();
                if (pointObjs != null && !pointObjs.isEmpty()) {
                    Map<String, Object> first = (Map<String, Object>) pointObjs.get(0);
                    path.moveTo(((Number) first.get("x")).floatValue(), ((Number) first.get("y")).floatValue());
                    for (int i = 1; i < pointObjs.size(); i++) {
                        Map<String, Object> pt = (Map<String, Object>) pointObjs.get(i);
                        path.lineTo(((Number) pt.get("x")).floatValue(), ((Number) pt.get("y")).floatValue());
                    }
                }
                gestureBuilder.addStroke(new GestureDescription.StrokeDescription(path, startTime, duration));
            }

            instance.dispatchGesture(gestureBuilder.build(), new AccessibilityService.GestureResultCallback() {
                @Override
                public void onCompleted(GestureDescription gestureDescription) {
                    new Handler(Looper.getMainLooper()).post(() -> result.success(true));
                }

                @Override
                public void onCancelled(GestureDescription gestureDescription) {
                    new Handler(Looper.getMainLooper()).post(() -> result.success(false));
                }
            }, null);
        } catch (Exception e) {
            Log.e("GESTURE", "performDispatchGesture: " + e.getMessage());
            result.success(false);
        }
    }


    private String generateNodeId(AccessibilityNodeInfo node) {
        return node.getWindowId() + "_" + node.getClassName() + "_" + node.getText() + "_" + node.getContentDescription(); //UUID.randomUUID().toString();
    }

    private void storeNode(String uuid, AccessibilityNodeInfo node) {
        if (node == null) {
            return;
        }
        nodeMap.put(uuid, node);
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
