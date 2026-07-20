package flutter.overlay.window.flutter_overlay_window;

import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.Service;
import android.content.Context;
import android.content.Intent;
import android.content.res.Configuration;
import android.content.res.Resources;
import android.graphics.Color;
import android.graphics.PixelFormat;
import android.graphics.drawable.GradientDrawable;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.app.PendingIntent;
import android.graphics.Point;
import android.os.Build;
import android.os.Handler;
import android.os.IBinder;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.Display;
import android.view.Gravity;
import android.view.MotionEvent;
import android.view.View;
import android.view.WindowManager;

import androidx.annotation.Nullable;
import androidx.annotation.RequiresApi;
import androidx.core.app.NotificationCompat;

import java.util.HashMap;
import java.util.Map;
import java.util.Timer;
import java.util.TimerTask;

import io.flutter.embedding.android.FlutterTextureView;
import io.flutter.embedding.android.FlutterView;
import io.flutter.FlutterInjector;
import io.flutter.embedding.engine.FlutterEngine;
import io.flutter.embedding.engine.FlutterEngineCache;
import io.flutter.embedding.engine.FlutterEngineGroup;
import io.flutter.embedding.engine.dart.DartExecutor;
import io.flutter.plugin.common.BasicMessageChannel;
import io.flutter.plugin.common.JSONMessageCodec;
import io.flutter.plugin.common.MethodChannel;

public class OverlayService extends Service implements View.OnTouchListener {
    private final int DEFAULT_NAV_BAR_HEIGHT_DP = 48;
    private final int DEFAULT_STATUS_BAR_HEIGHT_DP = 25;

    private Integer mStatusBarHeight = -1;
    private Integer mNavigationBarHeight = -1;
    private Resources mResources;

    public static final String INTENT_EXTRA_IS_CLOSE_WINDOW = "IsCloseWindow";

    private static OverlayService instance;
    public static boolean isRunning = false;
    private WindowManager windowManager = null;
    /** FoxyCo patch: true when the window is attached through the accessibility
     *  service's WindowManager as TYPE_ACCESSIBILITY_OVERLAY (immune to Uber's
     *  FLAG_HIDE_NON_SYSTEM_OVERLAY_WINDOWS on Accept cards). */
    private boolean useAccessibilityOverlay = false;

    /** Reflection lookup so this plugin needs no gradle dependency on the
     *  accessibility plugin. Returns null when the service isn't connected. */
    private static WindowManager a11yWindowManager() {
        try {
            Class<?> c = Class.forName(
                    "slayer.accessibility.service.flutter_accessibility_service.AccessibilityListener");
            return (WindowManager) c.getMethod("getA11yWindowManager").invoke(null);
        } catch (Throwable t) {
            return null;
        }
    }
    private FlutterView flutterView;
    private MethodChannel flutterChannel;
    private BasicMessageChannel<Object> overlayMessageChannel;
    private int clickableFlag = WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE | WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE |
            WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN;

    private Handler mAnimationHandler = new Handler();
    private float lastX, lastY;
    private int lastYPosition;
    private boolean dragging;
    private static final float MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER = 0.8f;
    private Point szWindow = new Point();
    private Timer mTrayAnimationTimer;
    private TrayAnimationTimerTask mTrayTimerTask;

    @Nullable
    @Override
    public IBinder onBind(Intent intent) {
        return null;
    }

    @RequiresApi(api = Build.VERSION_CODES.M)
    @Override
    public void onDestroy() {
        Log.d("OverLay", "Destroying the overlay window service");
        // FoxyCo patch: dismiss-zone view is a second window — drop it too or
        // it leaks (service can die mid-drag: drop-to-close calls stopSelf).
        hideDismissZone();
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            flutterView = null;
        }
        isRunning = false;
        NotificationManager notificationManager = (NotificationManager) getApplicationContext().getSystemService(Context.NOTIFICATION_SERVICE);
        notificationManager.cancel(OverlayConstants.NOTIFICATION_ID);
        instance = null;
    }

    /// FoxyCo patch (device 2026-07-19): swiping FoxyCo out of Recents kills
    /// the activity but this foreground service (and the whole process, with
    /// the in-memory "watching" state) survives — reopening the app showed a
    /// stale "online" session. A swipe-away means "close the app": tell the
    /// main isolate we stopped (if it's still around), then tear down.
    @Override
    public void onTaskRemoved(Intent rootIntent) {
        sendActionToApp("stopWatching");
        stopSelf();
        super.onTaskRemoved(rootIntent);
    }

    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    @Override
    public int onStartCommand(Intent intent, int flags, int startId) {
        mResources = getApplicationContext().getResources();
        int startX = intent.getIntExtra("startX", OverlayConstants.DEFAULT_XY);
        int startY = intent.getIntExtra("startY", OverlayConstants.DEFAULT_XY);
        boolean isCloseWindow = intent.getBooleanExtra(INTENT_EXTRA_IS_CLOSE_WINDOW, false);
        if (isCloseWindow) {
            if (windowManager != null) {
                windowManager.removeView(flutterView);
                windowManager = null;
                flutterView.detachFromFlutterEngine();
                stopSelf();
            }
            isRunning = false;
            return START_STICKY;
        }
        if (windowManager != null) {
            windowManager.removeView(flutterView);
            windowManager = null;
            flutterView.detachFromFlutterEngine();
            stopSelf();
        }
        isRunning = true;
        Log.d("onStartCommand", "Service started");
        FlutterEngine engine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);
        engine.getLifecycleChannel().appIsResumed();
        // FoxyCo patch: TextureView defaults to OPAQUE — the window's transparent
        // area then composites as a dark box/gradient behind the bubble and pill
        // (bug screenshots 2026-07-17). setOpaque(false) makes the surface truly
        // translucent so only our widgets paint.
        FlutterTextureView textureView = new FlutterTextureView(getApplicationContext());
        textureView.setOpaque(false);
        flutterView = new FlutterView(getApplicationContext(), textureView);
        flutterView.attachToFlutterEngine(FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG));
        flutterView.setFitsSystemWindows(true);
        flutterView.setFocusable(true);
        flutterView.setFocusableInTouchMode(true);
        flutterView.setBackgroundColor(Color.TRANSPARENT);
        flutterChannel.setMethodCallHandler((call, result) -> {
            if (call.method.equals("updateFlag")) {
                String flag = call.argument("flag").toString();
                updateOverlayFlag(result, flag);
            } else if (call.method.equals("updateOverlayPosition")) {
                int x = call.<Integer>argument("x");
                int y = call.<Integer>argument("y");
                moveOverlay(x, y, result);
            } else if (call.method.equals("resizeOverlay")) {
                int width = call.argument("width");
                int height = call.argument("height");
                boolean enableDrag = call.argument("enableDrag");
                // FoxyCo patch (device 2026-07-19): pill window inherited the
                // bubble's edge-hugging X, so the verdict pill showed pinned
                // left/right instead of centered. Optional flag: center the
                // window horizontally for this size, remembering the bubble's X
                // to restore on the next non-centered resize (shrink-to-bubble).
                Boolean center = call.argument("centerX");
                resizeOverlay(width, height, enableDrag, center != null && center, result);
            } else if (call.method.equals("bringToFront")) {
                // FoxyCo (HANDOFF bug: tap bubble → foreground app). Called on the
                // OVERLAY method channel directly from the overlay isolate's bubble
                // tap — the same path resizeOverlay uses, which is proven to reach
                // here. The old approach intercepted the messenger channel, which
                // never executed. We hold SYSTEM_ALERT_WINDOW and have a visible
                // overlay, so startActivity is an allowed background launch.
                bringHostAppToFront();
                result.success(true);
            }
        });
        overlayMessageChannel.setMessageHandler((message, reply) -> {
            // Forward overlay→main messages. Foregrounding the host app on a bubble
            // tap is handled on the OVERLAY METHOD channel ('bringToFront' above),
            // not here — this messenger path loops back to the overlay isolate and
            // never reliably reached native code.
            WindowSetup.messenger.send(message);
        });
        // FoxyCo patch (device 2026-07-19): Uber's fullscreen Accept card sets
        // FLAG_HIDE_NON_SYSTEM_OVERLAY_WINDOWS — a TYPE_APPLICATION_OVERLAY
        // bubble/pill goes invisible for exactly the card's lifetime (the one
        // moment FoxyCo exists for). TYPE_ACCESSIBILITY_OVERLAY is exempt, but
        // only the accessibility service's WindowManager may add one, so borrow
        // it (same process) via reflection; fall back to the normal path when
        // the service isn't connected.
        WindowManager a11yWm = a11yWindowManager();
        useAccessibilityOverlay = a11yWm != null;
        windowManager = useAccessibilityOverlay ? a11yWm : (WindowManager) getSystemService(WINDOW_SERVICE);

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.HONEYCOMB) {
            windowManager.getDefaultDisplay().getSize(szWindow);
        } else {
            DisplayMetrics displaymetrics = new DisplayMetrics();
            windowManager.getDefaultDisplay().getMetrics(displaymetrics);
            int w = displaymetrics.widthPixels;
            int h = displaymetrics.heightPixels;
            szWindow.set(w, h);
        }
        int dx = startX == OverlayConstants.DEFAULT_XY ? 0 : startX;
        int dy = startY == OverlayConstants.DEFAULT_XY ? -statusBarHeightPx() : startY;
        WindowManager.LayoutParams params = new WindowManager.LayoutParams(
                WindowSetup.width == -1999 ? -1 : WindowSetup.width,
                WindowSetup.height != -1999 ? WindowSetup.height : screenHeight(),
                0,
                -statusBarHeightPx(),
                useAccessibilityOverlay
                        ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                        : (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY : WindowManager.LayoutParams.TYPE_PHONE),
                WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN
                        | WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR
                        | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED,
                PixelFormat.TRANSLUCENT
        );
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
            params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
        }
        params.gravity = WindowSetup.gravity;
        flutterView.setOnTouchListener(this);
        windowManager.addView(flutterView, params);
        moveOverlay(dx, dy, null);
        return START_STICKY;
    }


    @RequiresApi(api = Build.VERSION_CODES.JELLY_BEAN_MR1)
    private int screenHeight() {
        Display display = windowManager.getDefaultDisplay();
        DisplayMetrics dm = new DisplayMetrics();
        display.getRealMetrics(dm);
        return inPortrait() ?
                dm.heightPixels + statusBarHeightPx() + navigationBarHeightPx()
                :
                dm.heightPixels + statusBarHeightPx();
    }

    private int statusBarHeightPx() {
        if (mStatusBarHeight == -1) {
            int statusBarHeightId = mResources.getIdentifier("status_bar_height", "dimen", "android");

            if (statusBarHeightId > 0) {
                mStatusBarHeight = mResources.getDimensionPixelSize(statusBarHeightId);
            } else {
                mStatusBarHeight = dpToPx(DEFAULT_STATUS_BAR_HEIGHT_DP);
            }
        }

        return mStatusBarHeight;
    }

    int navigationBarHeightPx() {
        if (mNavigationBarHeight == -1) {
            int navBarHeightId = mResources.getIdentifier("navigation_bar_height", "dimen", "android");

            if (navBarHeightId > 0) {
                mNavigationBarHeight = mResources.getDimensionPixelSize(navBarHeightId);
            } else {
                mNavigationBarHeight = dpToPx(DEFAULT_NAV_BAR_HEIGHT_DP);
            }
        }

        return mNavigationBarHeight;
    }


    private void updateOverlayFlag(MethodChannel.Result result, String flag) {
        if (windowManager != null) {
            WindowSetup.setFlag(flag);
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.flags = WindowSetup.flag | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS |
                    WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN |
                    WindowManager.LayoutParams.FLAG_LAYOUT_INSET_DECOR | WindowManager.LayoutParams.FLAG_HARDWARE_ACCELERATED;
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S && WindowSetup.flag == clickableFlag) {
                params.alpha = MAXIMUM_OPACITY_ALLOWED_FOR_S_AND_HIGHER;
            } else {
                params.alpha = 1;
            }
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    private void resizeOverlay(int width, int height, boolean enableDrag, boolean centerX, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.width = (width == -1999 || width == -1) ? -1 : dpToPx(width);
            params.height = (height != 1999 || height != -1) ? dpToPx(height) : height;
            // FoxyCo patch: pill centering (see method-channel comment). params.x
            // is offset from the gravity edge, so centered = (screen - window)/2.
            // Save/restore the bubble's X around the centered stretch so the
            // bubble snaps back to the edge the driver left it on.
            if (centerX) {
                if (savedRestX == Integer.MIN_VALUE) savedRestX = params.x;
                int w = params.width == -1 ? szWindow.x : params.width;
                params.x = Math.max(0, (szWindow.x - w) / 2);
            } else if (savedRestX != Integer.MIN_VALUE) {
                params.x = savedRestX;
                savedRestX = Integer.MIN_VALUE;
            }
            WindowSetup.enableDrag = enableDrag;
            windowManager.updateViewLayout(flutterView, params);
            result.success(true);
        } else {
            result.success(false);
        }
    }

    /// FoxyCo: bubble X remembered while the pill holds a centered window.
    /// MIN_VALUE == nothing saved.
    private int savedRestX = Integer.MIN_VALUE;

    private void moveOverlay(int x, int y, MethodChannel.Result result) {
        if (windowManager != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            params.x = (x == -1999 || x == -1) ? -1 : dpToPx(x);
            params.y = dpToPx(y);
            windowManager.updateViewLayout(flutterView, params);
            if (result != null)
                result.success(true);
        } else {
            if (result != null)
                result.success(false);
        }
    }


    public static Map<String, Double> getCurrentPosition() {
        if (instance != null && instance.flutterView != null) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
            Map<String, Double> position = new HashMap<>();
            position.put("x", instance.pxToDp(params.x));
            position.put("y", instance.pxToDp(params.y));
            return position;
        }
        return null;
    }

    public static boolean moveOverlay(int x, int y) {
        if (instance != null && instance.flutterView != null) {
            if (instance.windowManager != null) {
                WindowManager.LayoutParams params = (WindowManager.LayoutParams) instance.flutterView.getLayoutParams();
                params.x = (x == -1999 || x == -1) ? -1 : instance.dpToPx(x);
                params.y = instance.dpToPx(y);
                instance.windowManager.updateViewLayout(instance.flutterView, params);
                return true;
            } else {
                return false;
            }
        } else {
            return false;
        }
    }


    @Override
    public void onCreate() {
        // Get the cached FlutterEngine
        FlutterEngine flutterEngine = FlutterEngineCache.getInstance().get(OverlayConstants.CACHED_TAG);

        if (flutterEngine == null) {
            // Handle the error if engine is not found
            Log.e("OverlayService", "Flutter engine not found, hence creating new flutter engine");
            FlutterEngineGroup engineGroup = new FlutterEngineGroup(this);
            DartExecutor.DartEntrypoint entryPoint = new DartExecutor.DartEntrypoint(
                FlutterInjector.instance().flutterLoader().findAppBundlePath(),
                "overlayMain"
            );  // "overlayMain" is custom entry point

            flutterEngine = engineGroup.createAndRunEngine(this, entryPoint);

            // Cache the created FlutterEngine for future use
            FlutterEngineCache.getInstance().put(OverlayConstants.CACHED_TAG, flutterEngine);
        }

        // Create the MethodChannel with the properly initialized FlutterEngine
        if (flutterEngine != null) {
            flutterChannel = new MethodChannel(flutterEngine.getDartExecutor(), OverlayConstants.OVERLAY_TAG);
            overlayMessageChannel = new BasicMessageChannel(flutterEngine.getDartExecutor(), OverlayConstants.MESSENGER_TAG, JSONMessageCodec.INSTANCE);
        }

        createNotificationChannel();
        Intent notificationIntent = new Intent(this, FlutterOverlayWindowPlugin.class);
        int pendingFlags;
        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.S) {
            pendingFlags = PendingIntent.FLAG_IMMUTABLE;
        } else {
            pendingFlags = PendingIntent.FLAG_UPDATE_CURRENT;
        }
        PendingIntent pendingIntent = PendingIntent.getActivity(this,
                0, notificationIntent, pendingFlags);
        final int notifyIcon = getDrawableResourceId("mipmap", "launcher");
        Notification notification = new NotificationCompat.Builder(this, OverlayConstants.CHANNEL_ID)
                .setContentTitle(WindowSetup.overlayTitle)
                .setContentText(WindowSetup.overlayContent)
                .setSmallIcon(notifyIcon == 0 ? R.drawable.notification_icon : notifyIcon)
                .setContentIntent(pendingIntent)
                .setVisibility(WindowSetup.notificationVisibility)
                .build();
        startForeground(OverlayConstants.NOTIFICATION_ID, notification);
        instance = this;
    }

    private void createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            NotificationChannel serviceChannel = new NotificationChannel(
                    OverlayConstants.CHANNEL_ID,
                    "Foreground Service Channel",
                    NotificationManager.IMPORTANCE_DEFAULT
            );
            NotificationManager manager = getSystemService(NotificationManager.class);
            assert manager != null;
            manager.createNotificationChannel(serviceChannel);
        }
    }

    private int getDrawableResourceId(String resType, String name) {
        return getApplicationContext().getResources().getIdentifier(String.format("ic_%s", name), resType, getApplicationContext().getPackageName());
    }

    private int dpToPx(int dp) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP,
                Float.parseFloat(dp + ""), mResources.getDisplayMetrics());
    }

    /// FoxyCo patch: visible drop-to-dismiss zone (device 2026-07-19 — the
    /// drag-to-close gesture existed but nothing on screen ever hinted at it).
    /// While the bubble is dragged, a red-tinted gradient strip with an ✕
    /// target fades in over the nav-bar area; the ✕ swells + saturates while
    /// the finger is inside the dismiss band. Removed the moment the drag
    /// ends. Same window type as the overlay itself and NOT_TOUCHABLE, so it
    /// can never eat a touch.
    private View dismissZoneView;
    private TextView dismissIcon;
    private boolean dismissHot = false;

    /// The one predicate for "finger is in the close zone" — the visual (hot
    /// state) and the actual dismiss on ACTION_UP must never disagree.
    private boolean inDismissZone(float rawY) {
        return rawY >= szWindow.y - navigationBarHeightPx();
    }

    private void showDismissZone() {
        if (dismissZoneView != null || windowManager == null) return;
        Context ctx = getApplicationContext();

        LinearLayout zone = new LinearLayout(ctx);
        zone.setOrientation(LinearLayout.VERTICAL);
        zone.setGravity(Gravity.CENTER_HORIZONTAL | Gravity.BOTTOM);
        // Soft red wash rising from the bottom edge — reads "danger, drop
        // here to close" without covering the map.
        GradientDrawable bg = new GradientDrawable(
                GradientDrawable.Orientation.BOTTOM_TOP,
                new int[]{0x66E5352B, 0x00E5352B});
        zone.setBackground(bg);

        dismissIcon = new TextView(ctx);
        dismissIcon.setText("✕");
        dismissIcon.setTextSize(TypedValue.COMPLEX_UNIT_DIP, 22);
        dismissIcon.setTextColor(Color.WHITE);
        dismissIcon.setGravity(Gravity.CENTER);
        int d = dpToPx(48);
        GradientDrawable circle = new GradientDrawable();
        circle.setShape(GradientDrawable.OVAL);
        circle.setColor(0x88141C17);
        circle.setStroke(dpToPx(2), 0xFFFFFFFF);
        dismissIcon.setBackground(circle);
        LinearLayout.LayoutParams ip = new LinearLayout.LayoutParams(d, d);
        ip.bottomMargin = navigationBarHeightPx() + dpToPx(12);
        zone.addView(dismissIcon, ip);

        WindowManager.LayoutParams lp = new WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                dpToPx(140) + navigationBarHeightPx(),
                useAccessibilityOverlay
                        ? WindowManager.LayoutParams.TYPE_ACCESSIBILITY_OVERLAY
                        : (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O
                                ? WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
                                : WindowManager.LayoutParams.TYPE_PHONE),
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE
                        | WindowManager.LayoutParams.FLAG_NOT_TOUCHABLE
                        | WindowManager.LayoutParams.FLAG_LAYOUT_NO_LIMITS
                        | WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN,
                PixelFormat.TRANSLUCENT);
        lp.gravity = Gravity.BOTTOM;

        zone.setAlpha(0f);
        zone.animate().alpha(1f).setDuration(150).start();
        try {
            windowManager.addView(zone, lp);
            dismissZoneView = zone;
        } catch (Exception e) {
            Log.e("OverlayService", "showDismissZone failed", e);
        }
    }

    private void updateDismissZone(float rawY) {
        if (dismissIcon == null) return;
        boolean hot = inDismissZone(rawY);
        if (hot == dismissHot) return;
        dismissHot = hot;
        GradientDrawable circle = (GradientDrawable) dismissIcon.getBackground();
        circle.setColor(hot ? 0xFFE5352B : 0x88141C17);
        dismissIcon.animate().scaleX(hot ? 1.3f : 1f).scaleY(hot ? 1.3f : 1f)
                .setDuration(120).start();
    }

    private void hideDismissZone() {
        if (dismissZoneView == null) return;
        View v = dismissZoneView;
        dismissZoneView = null;
        dismissIcon = null;
        dismissHot = false;
        if (windowManager != null) {
            try {
                windowManager.removeView(v);
            } catch (Exception e) {
                Log.e("OverlayService", "hideDismissZone failed", e);
            }
        }
    }

    private double pxToDp(int px) {
        return (double) px / mResources.getDisplayMetrics().density;
    }

    private boolean inPortrait() {
        return mResources.getConfiguration().orientation == Configuration.ORIENTATION_PORTRAIT;
    }

    @Override
    public boolean onTouch(View view, MotionEvent event) {
        if (windowManager != null && WindowSetup.enableDrag) {
            WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();
            switch (event.getAction()) {
                case MotionEvent.ACTION_DOWN:
                    dragging = false;
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    break;
                case MotionEvent.ACTION_MOVE:
                    float dx = event.getRawX() - lastX;
                    float dy = event.getRawY() - lastY;
                    if (!dragging && dx * dx + dy * dy < 25) {
                        return false;
                    }
                    lastX = event.getRawX();
                    lastY = event.getRawY();
                    boolean invertX = WindowSetup.gravity == (Gravity.TOP | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.CENTER | Gravity.RIGHT)
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    boolean invertY = WindowSetup.gravity == (Gravity.BOTTOM | Gravity.LEFT)
                            || WindowSetup.gravity == Gravity.BOTTOM
                            || WindowSetup.gravity == (Gravity.BOTTOM | Gravity.RIGHT);
                    int xx = params.x + ((int) dx * (invertX ? -1 : 1));
                    int yy = params.y + ((int) dy * (invertY ? -1 : 1));
                    // FoxyCo patch (HANDOFF bug 8): clamp X so the WHOLE window
                    // stays on-screen. With FLAG_LAYOUT_NO_LIMITS the plugin lets
                    // the window drag clean off either edge and get stuck ~5%
                    // visible with no way back ("OVERFLOWED BY 24", bug1 (7)).
                    // params.x is measured from the anchored (LEFT/RIGHT) edge,
                    // so 0 = flush to that edge and (screenWidth - windowWidth) =
                    // flush to the opposite edge; clamp between them.
                    int viewW = flutterView.getWidth();
                    int maxX = Math.max(0, szWindow.x - viewW);
                    if (xx < 0) xx = 0;
                    if (xx > maxX) xx = maxX;
                    // FoxyCo patch (HANDOFF bug 2): clamp Y the same way so the
                    // bubble/pill can never be dragged off the top or buried under
                    // the nav bar and "vanish" on its own. Gravity is vertical
                    // CENTER, so params.y is measured from screen centre: the
                    // window stays fully visible while |y| <= (screenH - viewH)/2.
                    // Being merely NEAR the nav bar now just parks the bubble at
                    // the bottom edge — it keeps watching. Only a deliberate drag
                    // into the nav-bar strip (handled on ACTION_UP) dismisses.
                    int viewH = flutterView.getHeight();
                    int maxY = Math.max(0, (szWindow.y - viewH) / 2);
                    if (yy < -maxY) yy = -maxY;
                    if (yy > maxY) yy = maxY;
                    params.x = xx;
                    params.y = yy;
                    if (windowManager != null) {
                        windowManager.updateViewLayout(flutterView, params);
                    }
                    dragging = true;
                    // FoxyCo patch: surface the dismiss zone the moment a real
                    // drag starts (not on a tap) and keep its ✕ hot-state in
                    // sync with the finger. Discoverability for drop-to-close.
                    showDismissZone();
                    updateDismissZone(event.getRawY());
                    break;
                case MotionEvent.ACTION_UP:
                case MotionEvent.ACTION_CANCEL:
                    // FoxyCo patch: drag over → drop zone leaves with it.
                    hideDismissZone();
                    // FoxyCo patch: "drop to dismiss". If the user releases the
                    // drag inside the bottom nav-bar zone, close the overlay
                    // instead of snapping it to an edge. Fixes the bubble getting
                    // stuck under the nav bar (the plugin never clamps Y).
                    // event.getRawY() is absolute screen Y; szWindow.y is screen
                    // height. Only when the user actually dragged (not a tap).
                    // FoxyCo patch (HANDOFF bug 2): the old 72dp band fired when
                    // the bubble was merely CLOSE to the nav bar, so parking it low
                    // killed the session. The Y-clamp above now keeps the bubble
                    // on-screen, so dismissing must be a deliberate shove of the
                    // FINGER into the nav-bar strip itself (~nav bar height). Tune
                    // on device if it feels too eager / too hard to hit.
                    if (dragging && inDismissZone(event.getRawY())) {
                        // HANDOFF req 10: tell the main isolate we STOPPED, so the
                        // dashboard flips out of "Watching" instead of desyncing.
                        // Send before tearing down — the messenger routes to the
                        // app's overlayListener → OverlayAction.stopWatching.
                        sendActionToApp("stopWatching");
                        stopSelf(); // onDestroy() removes the view + cleans up
                        return false;
                    }
                    lastYPosition = params.y;
                    if (!WindowSetup.positionGravity.equals("none")) {
                        if (windowManager == null) return false;
                        windowManager.updateViewLayout(flutterView, params);
                        mTrayTimerTask = new TrayAnimationTimerTask();
                        mTrayAnimationTimer = new Timer();
                        mTrayAnimationTimer.schedule(mTrayTimerTask, 0, 25);
                    }
                    return false;
                default:
                    return false;
            }
            return false;
        }
        return false;
    }

    private class TrayAnimationTimerTask extends TimerTask {
        int mDestX;
        int mDestY;
        WindowManager.LayoutParams params = (WindowManager.LayoutParams) flutterView.getLayoutParams();

        public TrayAnimationTimerTask() {
            super();
            mDestY = lastYPosition;
            switch (WindowSetup.positionGravity) {
                case "auto":
                    mDestX = (params.x + (flutterView.getWidth() / 2)) <= szWindow.x / 2 ? 0 : szWindow.x - flutterView.getWidth();
                    return;
                case "left":
                    mDestX = 0;
                    return;
                case "right":
                    mDestX = szWindow.x - flutterView.getWidth();
                    return;
                default:
                    mDestX = params.x;
                    mDestY = params.y;
                    break;
            }
        }

        @Override
        public void run() {
            mAnimationHandler.post(() -> {
                params.x = (2 * (params.x - mDestX)) / 3 + mDestX;
                params.y = (2 * (params.y - mDestY)) / 3 + mDestY;
                if (windowManager != null) {
                    windowManager.updateViewLayout(flutterView, params);
                }
                if (Math.abs(params.x - mDestX) < 2 && Math.abs(params.y - mDestY) < 2) {
                    TrayAnimationTimerTask.this.cancel();
                    mTrayAnimationTimer.cancel();
                }
            });
        }
    }

    /// FoxyCo helpers (HANDOFF reqs 9, 10) ------------------------------------

    /// True if the overlay→app message is FoxyCo's tap action. The wire format
    /// is the OverlayAction map {kind: 'action', action: 'openApp'} (see
    /// domain/overlay_action.dart). Defensive: any shape mismatch → false.
    private boolean isOpenAppAction(Object message) {
        if (!(message instanceof Map)) return false;
        Map<?, ?> map = (Map<?, ?>) message;
        return "action".equals(map.get("kind")) && "openApp".equals(map.get("action"));
    }

    /// Bring FoxyCo's own launcher activity to the foreground. From a background
    /// service the app can't foreground itself Dart-side, so we do it natively
    /// with the launch intent (NEW_TASK + brought-to-front so we reuse the
    /// existing task rather than spawning a duplicate).
    private void bringHostAppToFront() {
        Context ctx = getApplicationContext();
        // FoxyCo holds SYSTEM_ALERT_WINDOW, which exempts it from Android's
        // background-activity-launch block, so startActivity from here is allowed.
        // The failure mode was launchIntent == null (multi-user / work-profile
        // package query), which silently no-op'd. Try the normal launcher intent
        // first, then fall back to an EXPLICIT MainActivity component so a null
        // launch intent can't swallow the tap.
        Intent launch = ctx.getPackageManager()
                .getLaunchIntentForPackage(ctx.getPackageName());
        if (launch == null) {
            // applicationId (com.foxyco.app) differs from the class package
            // (com.foxyco.foxyco) — target the activity explicitly by both.
            launch = new Intent(Intent.ACTION_MAIN);
            launch.addCategory(Intent.CATEGORY_LAUNCHER);
            launch.setClassName(ctx.getPackageName(), "com.foxyco.foxyco.MainActivity");
        }
        launch.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                | Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
                | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        Log.d("FoxyCoNative", "bringHostAppToFront: pkg=" + ctx.getPackageName()
                + " intent=" + launch);
        try {
            ctx.startActivity(launch);
            Log.d("FoxyCoNative", "bringHostAppToFront: startActivity called");
        } catch (Exception e) {
            Log.e("FoxyCoNative", "bringHostAppToFront failed", e);
        }
    }

    /// Push an OverlayAction back to the main isolate's overlayListener. Builds
    /// the same {kind:'action', action:<name>} map the Dart side decodes, so a
    /// native-originated action (e.g. drop-to-dismiss → stopWatching) is
    /// indistinguishable from a bubble-gesture action.
    private void sendActionToApp(String action) {
        try {
            Map<String, Object> msg = new HashMap<>();
            msg.put("kind", "action");
            msg.put("action", action);
            if (WindowSetup.messenger != null) {
                WindowSetup.messenger.send(msg);
            }
        } catch (Exception e) {
            Log.e("OverlayService", "sendActionToApp failed", e);
        }
    }

}