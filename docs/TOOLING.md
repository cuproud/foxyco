# FoxyCo — Tooling: what to install

Two buckets: (A) Claude Code helpers that make *me* better at building this, and (B) the actual
Flutter dev environment *you* need on the machine.

---

## A. Claude Code skills / MCP / plugins

### Already available (no install — I'll just use them)
- **`app-ui-design`** skill — cross-platform UI design system + accessibility (primary for FoxyCo).
- **`google-material-design`** skill — Material 3 language, which Flutter renders natively.
- **`dataviz`** skill — for later (analytics/heatmap charts, M-later).
- **`deep-research`** skill — used it for the overlay research; good for future platform-UI recon.
- **`verify` / `run` / `code-review` / `security-review`** skills — QA the app as we build.

> Note: the Android-native design skills from the old plan (`mobile-android-design`,
> `android-design-guidelines`) are less relevant now — Flutter draws its own widgets. `app-ui-design`
> + `google-material-design` cover the Material 3 look FoxyCo targets.

### Worth installing (you'd need to add these)
| Tool | Why | Priority |
|---|---|---|
| **Android MCP server** (`adb`-backed) | Drive a connected phone: install APK, tap, screenshot, read logcat, dump the accessibility node tree. **Biggest force-multiplier** for M2/M3 overlay + parser tuning. | HIGH |
| **Dart/Flutter LSP or analyzer MCP** | Faster analyze/compile-error feedback without shelling `flutter analyze` each time. | MED |
| **Figma MCP** (if you design in Figma) | Pull design tokens/specs straight into Flutter theme in M5. | LOW (M5) |

> If you don't want to hunt for an Android MCP: I can drive everything through `adb` in Bash
> directly (install, logcat, `uiautomator dump`, screenshots). An MCP just makes it cleaner.

### Not needed
Skip anything cloud/backend/web-framework — FoxyCo has no server. No DB-admin MCP, no deploy tooling.

---

## B. Flutter dev environment (on your machine)

Flutter is **already installed** on this machine:

```
flutter 3.44.4 · stable · Dart bundled
/home/vamsi/development/flutter/bin/flutter
```

So the SDK box is ticked. What's left is the Android side of the toolchain.

### Install checklist
- [x] **Flutter SDK** (3.44.4 stable — present)
- [ ] **JDK 17** (Android Gradle Plugin 8.x needs it — Flutter's Android build uses Gradle)
- [ ] **Android SDK Platform 35** + build-tools (there's an extracted `android-35` in /tmp — reuse)
- [ ] **Android SDK Platform-Tools** (`adb`, `fastboot`)
- [ ] **Android command-line tools** + accept licenses (`flutter doctor --android-licenses`)
- [ ] A **physical Android phone** with USB debugging on — *essential*: overlay + accessibility
      behave differently on real devices than the emulator; the whole point is real Uber/Hopp offers.
- [ ] **Uber and/or Hopp driver account** to test against real offers — the only way to tune the
      parser. Emulator can't get real offers.
- [ ] Optional: **scrcpy** — mirror the phone on screen while driving-testing; makes overlay
      debugging way easier.

### First: run flutter doctor
```bash
flutter doctor -v
```
Fix every ❌ it lists (usually: Android toolchain, licenses, a connected device) before M0.
This is the single most useful command — it tells you exactly what's missing.

### Verify the Android side works
```bash
adb devices                      # your phone shows up
flutter devices                  # Flutter sees the phone
adb logcat                       # you can read logs
adb shell uiautomator dump       # dumps the current screen's node tree — how we tune the parser
```

If `flutter devices` lists your phone and `uiautomator dump` prints a view tree, you're ready for M3.

---

## Packages we'll add (as their milestone arrives)

Don't add these until the milestone needs them (YAGNI — every dep is app size + a permission):

| Package | Milestone | Purpose |
|---|---|---|
| `flutter_riverpod` | M0 | state management + DI |
| `go_router` | M0 | navigation |
| `shared_preferences` | M1 | settings storage |
| `flutter_overlay_window` | M2 | draw pill/bubble over other apps |
| `permission_handler` | M2 | overlay + accessibility permission flows |
| `flutter_accessibility_service` | M3 | read offers off Uber/Hopp screens |
| `drift` + `sqlite3_flutter_libs` | M4 | offer log DB → tally + future analytics |
| `flutter_foreground_task` | M3 (if needed) | keep the watch loop alive |
| `fl_chart` | later | analytics charts |
| `google_mlkit_text_recognition` | later | expense receipt OCR |

---

## What I need from you to start M0

1. Confirm **FoxyCo** + package name (or leave `com.foxyco.app` placeholder).
2. Confirm **Uber + Hopp** first (already the base per DECISIONS #6).
3. Run `flutter doctor -v` and get an Android device to `flutter devices`.
4. (Nice-to-have) point me at an Android MCP if you want the cleaner loop; else I use `adb` via Bash.

Then I start M0 and we go milestone by milestone, each reviewed before the next.
