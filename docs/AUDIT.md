# FoxyCo — Pre-Flight Audit

Read before writing code. These are the things that sink apps like this. Ranked by how likely
each is to actually hurt you. The risks are mostly **platform-level (Android + gig ToS)**, so they
apply whether the app is Kotlin or Flutter — the mitigations that change for Flutter are flagged.

---

## 🔴 1. Google Play AccessibilityService policy (HIGHEST risk)

Play policy: an app using `AccessibilityService` must use it **for accessibility** OR prominently
disclose a non-accessibility use with user consent. Apps that use it purely to read/automate other
apps get **rejected or removed**. This is the #1 reason apps like FoxyCo die on the Play Store.
Using Flutter changes nothing here — `flutter_accessibility_service` requests the exact same
Android permission Google scrutinizes.

**Mitigations**
- In-app + Play listing: clearly disclose *why* FoxyCo needs accessibility (reads on-screen offer
  numbers to advise the driver), with an explicit consent screen before enabling.
- Fill the accessibility service metadata `description` with the real purpose.
- Have a **sideload / direct-APK distribution plan** as fallback (Maxymo-style). Many gig tools live
  off-Play for exactly this reason. Decide distribution before M4.
- Don't over-request. Only the packages you actually parse in the service's `packageNames`.

## 🔴 2. Gig-platform ToS — automation = driver deactivation

Uber/Hopp ToS forbid third-party automation. **Reading** offers is a grey area; **auto-accept/
auto-decline** (clicking their buttons for the driver) is a clear violation and can get the
**driver's account deactivated** — that's the driver's livelihood, not just our app.

**Mitigations**
- MVP is **read-and-advise only**. No clicking their UI. Ship that.
- Keep auto-accept 💤 deferred and, if ever built: opt-in, off by default, blunt warning screen
  ("this may get you deactivated"), never the default path.
- Never store/scrape platform credentials. FoxyCo never logs into anything.

## 🟠 3. Parser fragility

Uber/Hopp ship UI updates constantly. Text-based node selectors break silently → FoxyCo shows
wrong/no verdict. A wrong verdict that makes a driver decline a good offer is worse than no app.

**Mitigations**
- Each platform parser isolated in `parser/`, tagged with the app version it was tuned against.
- Debug flag dumps the raw accessibility node list → fast re-tuning.
- Fixture tests (`dart test`): capture real node dumps, assert parsed `Offer`. Add one per format change.
- **Fail safe:** if parse confidence is low, show nothing (or a "?") — never a confident wrong call.

## 🟠 4. Battery & performance

The accessibility service fires on every content change in the target apps; the overlay renders
continuously. Done naively this drains battery and gets FoxyCo blamed.

**Mitigations**
- Scope `packageNames` to Uber + Hopp only — events don't fire system-wide.
- Debounce `typeWindowContentChanged` (it machine-guns). Parse on a short debounce + dedupe.
- Only run the heavy watching while the driver is "on" (bubble long-press pause; auto-idle).
- No polling, no wakelocks beyond what the overlay/foreground task needs. Target <300 ms detect→verdict.
- **Flutter-specific:** the overlay runs a **second Flutter engine/isolate** (see ARCHITECTURE).
  That's extra baseline memory vs a native View overlay. Keep the overlay entrypoint's widget tree
  tiny (a pill is a Row + a dot), don't pull the whole app's providers into it, and close the
  overlay when idle rather than hiding it. Measure with Flutter DevTools before M5.

## 🟡 5. Privacy (this is a selling point — get it right)

Offer text can contain addresses / rider names. FoxyCo is "privacy-first," so it must actually be.

**Mitigations**
- 100% on-device. **No network permission in MVP at all** (proves it can't exfiltrate). Check the
  merged `AndroidManifest.xml` — Flutter plugins can silently add `INTERNET`; strip it if nothing
  needs it, or justify it.
- Store only what the tally needs (platform, payout, km, verdict, timestamp) — not addresses/names.
- No analytics, no crash SDK phoning home in MVP. Transparent permission rationale screens.
- Drift DB local; export/backup is later + encrypted.

## 🟡 6. Overlay correctness (from OVERLAY.md)

- Must never cover the platform's Accept or top-right X/decline. Clamp pill position to the safe zone.
- Overlay flag must let touches pass through — a stray overlay that eats the Accept tap is a driver
  losing money. Verify `flutter_overlay_window`'s pass-through flag on notched + gesture-nav +
  3-button-nav devices.
- Handle rotation, split-screen, multi-window, status-bar-hidden fullscreen.

## 🟢 7. Accessibility (a11y) of FoxyCo itself

- Verdict never by color alone — pair with word + icon (colorblind-safe).
- 48 dp touch targets. Semantics labels on pill/bubble. Readable in sunlight (contrast).

## 🟢 8. Distribution & naming

- **"FoxyCo"** — check Play Store + trademark collision before committing the listing (lots of "Foxy"
  apps). Package `com.foxyco.app` is a placeholder; lock it before first signed build (can't change
  after publish). Also grab `foxy.co` / `getfoxyco.app` if the brand sticks.
- Sign + keep the keystore backed up (losing it = can't update the app ever).

---

## M2 audit note (overlay landed) — 2026-07-10

Reviewing the overlay code against the risks above:

- **#5 privacy / offline (🟢 holding):** `INTERNET` deliberately omitted from `AndroidManifest.xml`;
  everything is on-device. `permission_handler` is modular and adds no permission unless configured —
  ⏳ still must confirm on the *merged* manifest at build time (checklist item stands).
- **#6 overlay correctness (🟡):** pill is `topCenter`-dropped and touch-through
  (`OverlayFlag.defaultFlag`) so it clears the platform's Accept/Decline — ⏳ needs the 3-device check.
  Bubble defaults bottom-right; `positionGravity: auto` snaps it to an edge after a drag.
- **cross-isolate robustness (🟢):** every inbound `shareData` map is `kind`-tagged
  (`offer`/`control`/`action`) and **fails safe** — non-maps and unknown kinds are ignored, bad enum
  values degrade to `Verdict.unknown`, never a crash or a confident wrong call. Covered by unit tests.
- **#4 battery (🟡, unmeasured):** overlay window stays alive between offers (bubble persists); only
  the pill content clears on the 12s timer. ⏳ profile idle drain when paused.
- **special-use FGS (🟡):** service uses `foregroundServiceType="specialUse"` — some OEMs scrutinize
  this; the `PROPERTY_SPECIAL_USE_FGS_SUBTYPE` explanation is set. Watch for Play review friction (#1).

## 🟢 9. Flutter/plugin maintenance risk (new)

- `flutter_overlay_window` and `flutter_accessibility_service` are community plugins, not Google
  first-party. A Flutter or Android SDK bump could break them before the maintainer patches.
- **Mitigations:** pin plugin versions in `pubspec.lock`; both are thin wrappers, so worst case we
  fork and maintain the small native shim ourselves; keep the accessibility/overlay code isolated in
  `services/` so a plugin swap doesn't ripple into domain/ui.

---

## M9 release-readiness sweep — 2026-07-20

Full pass against every risk above, ahead of the first Play submission.

- **#1 accessibility policy (🟡 ready, needs listing text):** `@xml/accessibilityservice`
  declares the real purpose in `android:description`, is scoped to the 3 gig packages
  only, READ-ONLY (`canPerformGestures` never requested), `isAccessibilityTool=true`.
  Onboarding has the explicit consent/grant screen. ⏳ Play Console: fill the
  AccessibilityService declaration form + prominent-disclosure video at submission.
- **#2 ToS / no automation (🟢):** read-and-advise only; no click/gesture APIs anywhere
  in the codebase; strictly-manual rule enforced (memory: never act inside gig apps).
- **#3 parser fail-safe (🟢):** low-confidence parses drop (`parse null (low conf)`),
  fixture tests per platform, parse-health streak surface in Settings.
- **#4 battery (🟢 code / ⏳ measure):** packageNames scoped, 300ms notification
  timeout, debounce in watcher, overlay content clears on timer. Home car hero:
  15 layers decode once at display width (`cacheWidth`), glow pulse is opacity-only.
- **#5 privacy (🟢):** merged release manifest re-checked 2026-07-20 — NO `INTERNET`
  permission. Only SYSTEM_ALERT_WINDOW, FOREGROUND_SERVICE(+SPECIAL_USE), WAKE_LOCK.
  No analytics/crash SDKs. Log stores platform/payout/km/verdict/timestamp only.
- **#6 overlay correctness (🟢 device-verified M8):** pill top-center touch-through,
  drop-to-dismiss zone, savedRestX edge restore.
- **#7 a11y of FoxyCo (🟢):** verdict = color + word + dot everywhere (legend pills,
  seg bar); reduced-motion honored on splash, car hero, greeting, counters.
- **#9 plugin risk (🟢):** both shims vendored in `third_party/` and locally patched
  (fork NPE, messenger ownership) — we already maintain them.
- **Release hygiene (this sweep):** all `debugPrint`s now `kDebugMode`-guarded
  (release builds log nothing); no commented-out code blocks in `lib/`;
  `flutter analyze` clean; 155 tests green.

### Blockers left for Play submission (not code)

1. ~~**Signing wiring**~~ ✅ 2026-07-20: gradle reads `android/key.properties`
   (gitignored) with debug fallback. ⏳ YOU still must generate the keystore:
   ```
   keytool -genkeypair -v -keystore ~/foxyco-upload.jks -alias upload \
     -keyalg RSA -keysize 2048 -validity 10000
   ```
   then write `android/key.properties` (storePassword/keyPassword/keyAlias=upload/
   storeFile) and BACK BOTH UP — losing them loses the Play listing.
2. ~~**Application ID**~~ ✅ locked `com.foxyco.app` 2026-07-20.
3. **Play Console papers:** accessibility declaration form, data-safety form
   (all "no data collected/shared" — true, offline), listing screenshots,
   privacy-policy URL (required even for offline apps).
4. ~~**R8/shrink**~~ ✅ 2026-07-20: `minifyEnabled` + `shrinkResources` on, keep
   rules for both vendored plugins (`proguard-rules.pro`); release build green.

### License audit — 2026-07-20 (all clear ✅)

| Component | License | OK |
|---|---|---|
| flutter_overlay_window (vendored) | MIT (Iheb Briki) | ✅ |
| flutter_accessibility_service (vendored) | MIT (Iheb Briki) | ✅ |
| flutter_riverpod, permission_handler, cupertino_icons | MIT | ✅ |
| go_router, shared_preferences, path_provider, flutter_lints | BSD-3 (Flutter Authors) | ✅ |
| Fraunces font | SIL OFL 1.1 (`fonts/OFL_Fraunces.txt`) | ✅ |
| Inter font | SIL OFL 1.1 (`fonts/OFL_Inter.txt`) | ✅ |
| Car renders, fox logo, all branding PNGs | generated for this project | ✅ |

No GPL/AGPL/commercial anywhere in the tree. OFL texts now committed beside the
fonts (OFL requires shipping the license with the font). Flutter's built-in
`LicenseRegistry` covers pub packages at runtime; nothing further owed.

---

## Go/no-go checklist before public release

- [ ] Accessibility use disclosed + consent screen shipped
- [ ] No auto-click of platform UI in the build
- [ ] No network permission (or documented + justified if added) — checked merged manifest
- [ ] Parser fails safe (no confident wrong verdict)
- [ ] Overlay can't cover Accept/decline on 3 test devices
- [ ] Battery + overlay-isolate memory profiled, watching idles when paused
- [ ] Distribution decided (Play with disclosure vs sideload)
- [ ] Plugin versions pinned in pubspec.lock
- [ ] Keystore backed up, package name final
