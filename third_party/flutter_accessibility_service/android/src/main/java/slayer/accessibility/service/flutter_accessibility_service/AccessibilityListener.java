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
    private static WindowManager mWindowManager;
    private static FlutterView mOverlayView;
    static private boolean isOverlayShown = false;
    private static final int CACHE_SIZE = 4 * 1024 * 1024; // 4Mib
    private static final int maxDepth = 20;
    private static LruCache<String, AccessibilityNodeInfo> nodeMap =
            new LruCache<>(CACHE_SIZE);
    private static final int DEFAULT_MAX_TREE_DEPTH = 15;
    private int maximumTreeDepth = DEFAULT_MAX_TREE_DEPTH;

    public static AccessibilityNodeInfo getNodeInfo(String id) {
        return nodeMap.get(id);
    }

    @RequiresApi(api = Build.VERSION_CODES.N)
    @Override
    public void onAccessibilityEvent(AccessibilityEvent accessibilityEvent) {
        try {
            final int eventType = accessibilityEvent.getEventType();
            AccessibilityNodeInfo parentNodeInfo = accessibilityEvent.getSource();
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
            if (parentNodeInfo.getText() != null) {
                data.put("capturedText", parentNodeInfo.getText().toString());
            }
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.JELLY_BEAN_MR2) {
                data.put("nodeId", parentNodeInfo.getViewIdResourceName());
            }
            getSubNodes(parentNodeInfo, subNodeActions, traversedNodes, 0);
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
            // BISECT: temporarily disabled to confirm baseline delivery works.
            // collectSamePackageWindows(subNodeActions, traversedNodes, packageName);
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
            String mapId = generateNodeId(node);
            AccessibilityWindowInfo windowInfo = null;
            HashMap<String, Object> nested = new HashMap<>();
            Rect rect = new Rect();
            node.getBoundsInScreen(rect);
            windowInfo = node.getWindow();
            nested.put("mapId", mapId);
            nested.put("nodeId", node.getViewIdResourceName());
            nested.put("capturedText", node.getText());
            nested.put("screenBounds", getBoundingPoints(rect));
            nested.put("isClickable", node.isClickable());
            nested.put("isScrollable", node.isScrollable());
            nested.put("isFocusable", node.isFocusable());
            nested.put("isCheckable", node.isCheckable());
            nested.put("isLongClickable", node.isLongClickable());
            nested.put("isEditable", node.isEditable());
            nested.put("parentActions", node.getActionList().stream().map(AccessibilityNodeInfo.AccessibilityAction::getId).collect(Collectors.toList()));
            if (windowInfo != null) {
                nested.put("isActive", node.getWindow().isActive());
                nested.put("isFocused", node.getWindow().isFocused());
                nested.put("windowType", node.getWindow().getType());
            }
            arr.add(nested);
            storeNode(mapId, node);
            for (int i = 0; i < node.getChildCount(); i++) {
                AccessibilityNodeInfo child = node.getChild(i);
                if (child == null)
                    continue;
                getSubNodes(child, arr, traversedNodes, currentDepth + 1);
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

    void storeToSharedPrefs(HashMap<String, Object> data) {
        SharedPreferences sharedPreferences = getSharedPreferences(SHARED_PREFS_TAG, MODE_PRIVATE);
        SharedPreferences.Editor editor = sharedPreferences.edit();
        Gson gson = new Gson();
        String json = gson.toJson(data);
        editor.putString(ACCESSIBILITY_NODE, json);
        editor.apply();
    }

}
