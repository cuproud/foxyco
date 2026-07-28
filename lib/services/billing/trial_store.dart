import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fox_clock.dart';

/// How long the free trial runs once the driver taps "Start trial".
const trialDuration = Duration(days: 7);

/// How long a cached verdict is honoured with no successful server check
/// (MONETIZATION_v1.0 §3.5). Simultaneously the UX floor — a driver in a dead
/// zone keeps working for a week — and the piracy ceiling.
const offlineGrace = Duration(days: 7);

/// Where the driver sits on the trial timeline (MONETIZATION_v1.0 §3.1).
enum TrialPhase {
  /// Still resolving. The boot state — never lock or unlock the UI on it.
  unknown,

  /// Installed, never tapped "Start trial". A LOCKED state: the 7 days are
  /// opt-in so they can't be silently burned by someone who installed and
  /// forgot. Same surface as [expired].
  preTrial,

  /// Inside the 7 days.
  active,

  /// The 7 days are up.
  expired,
}

/// Trial timeline as last resolved. Immutable snapshot; [TrialStore] replaces it
/// wholesale.
@immutable
class TrialState {
  /// Start of the trial, stamped by Google's server clock (never the device's).
  /// Null in [TrialPhase.preTrial].
  final DateTime? startedAt;

  /// When we last read the trial doc from Firestore, on the local clock. Null
  /// means "never" — a fresh install, or Firebase has never been reachable.
  /// Drives the offline grace window and the day-5 warning banner.
  final DateTime? verifiedAt;

  /// Google account the trial belongs to, for the Settings row. Null while
  /// anonymous.
  final String? email;

  final TrialPhase phase;

  /// Whole days left in the trial, floor 0. Computed at resolve time against
  /// [FoxClock], not on demand, so widgets never touch the clock.
  final int daysLeft;

  const TrialState({
    required this.phase,
    this.startedAt,
    this.verifiedAt,
    this.email,
    this.daysLeft = 0,
  });

  static const initial = TrialState(phase: TrialPhase.unknown);

  /// Resolve a start date into a phase against [now] (which callers take from
  /// [FoxClock], never `DateTime.now()`).
  ///
  /// Pure so the trial arithmetic is testable without Firebase or prefs: no
  /// start date means PRE_TRIAL, which is LOCKED — entitlement is never granted
  /// by default (§3.1).
  factory TrialState.from({
    required DateTime? startedAt,
    required DateTime? verifiedAt,
    required String? email,
    required DateTime now,
  }) {
    if (startedAt == null) {
      return TrialState(
        phase: TrialPhase.preTrial,
        verifiedAt: verifiedAt,
        email: email,
      );
    }
    final left = trialDuration - now.difference(startedAt);
    return TrialState(
      phase: left > Duration.zero ? TrialPhase.active : TrialPhase.expired,
      startedAt: startedAt,
      verifiedAt: verifiedAt,
      email: email,
      // Ceil, so "1 day left" doesn't read as 0 for the last 23 hours.
      daysLeft: left > Duration.zero ? (left.inHours / 24).ceil() : 0,
    );
  }

  bool get isActive => phase == TrialPhase.active;

  /// Signed in with Google, so a trial doc exists (or is being created).
  bool get hasAccount => email != null;

  /// Age of the last successful server check, against [now]. Null when we have
  /// never reached the server.
  Duration? staleness(DateTime now) =>
      verifiedAt == null ? null : now.difference(verifiedAt!);
}

/// Result of tapping "Start trial", so the sheet can say something useful
/// instead of a bare failure.
enum TrialStartResult {
  /// Trial running. Either just created, or the account already had one that is
  /// still inside its 7 days.
  started,

  /// This Google account already used its trial and it has run out. Reinstalling
  /// or clearing app data lands here — which is the entire point of keeping the
  /// start date server-side (§3.3).
  alreadyExpired,

  /// The driver dismissed the Google sheet.
  cancelled,

  /// No network, Firebase not configured, sign-in misconfigured. Retryable.
  failed,
}

/// Owns the trial half of entitlement: identity (anonymous, then Google) and the
/// write-once Firestore trial record, cached locally with an offline grace
/// window (MONETIZATION_v1.0 §3.2–§3.5).
///
/// Firestore is the source of truth for the START DATE and nothing else. The
/// purchase half lives in `BillingStore`; `entitlementProvider` combines them.
/// The two are never mixed — a cleared app-data directory must not be able to
/// regrant a trial, and only Play can say whether the unlock was bought.
class TrialStore extends Notifier<TrialState> {
  static const _keyStartedAt = 'foxyco.trial.startedAt.v1';
  static const _keyVerifiedAt = 'foxyco.trial.verifiedAt.v1';
  static const _keyEmail = 'foxyco.trial.email.v1';

  /// True once a Google sign-in flow is in flight, so a double tap on the
  /// paywall button can't open two sheets.
  bool _busy = false;

  @override
  TrialState build() {
    // Cache first so the UI has a verdict on frame one, then reconcile with the
    // server in the background.
    _loadCache().then((_) => refresh(sampled: true));
    return TrialState.initial;
  }

  /// Odds of re-reading the trial doc on a launch that doesn't otherwise need to
  /// (§3.7 layer 2). Not every launch: cheap as Firestore reads are, the point
  /// is that a patch which strips the check re-locks the app days later, and
  /// randomness is what makes "it worked yesterday" no defence.
  static const _reverifyOneIn = 5;

  /// Firebase absent (no google-services.json, init failed) — every server path
  /// is a no-op and the cached verdict stands until the grace window lapses.
  bool get _firebaseUp => Firebase.apps.isNotEmpty;

  FirebaseAuth get _auth => FirebaseAuth.instance;

  Future<void> _loadCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final startedMs = prefs.getInt(_keyStartedAt);
      final verifiedMs = prefs.getInt(_keyVerifiedAt);
      state = await _resolve(
        startedAt: startedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(startedMs, isUtc: true),
        verifiedAt: verifiedMs == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(verifiedMs, isUtc: true),
        email: prefs.getString(_keyEmail),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo trial cache read skipped: $e');
    }
  }

  Future<void> _saveCache(TrialState next) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final started = next.startedAt;
      final verified = next.verifiedAt;
      if (started != null) {
        await prefs.setInt(_keyStartedAt, started.millisecondsSinceEpoch);
      }
      if (verified != null) {
        await prefs.setInt(_keyVerifiedAt, verified.millisecondsSinceEpoch);
      }
      if (next.email != null) await prefs.setString(_keyEmail, next.email!);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo trial cache write skipped: $e');
    }
  }

  /// [TrialState.from] against the rollback-proof clock.
  Future<TrialState> _resolve({
    required DateTime? startedAt,
    required DateTime? verifiedAt,
    required String? email,
  }) async => TrialState.from(
    startedAt: startedAt,
    verifiedAt: verifiedAt,
    email: email,
    now: await FoxClock.now(),
  );

  /// Make sure we have an identity, and re-read the trial doc if that identity
  /// is a Google one. Cheap: one Firestore read, and only when signed in — not
  /// on every launch (§3.3).
  ///
  /// Called at boot, on resume, and after a purchase attempt. Never throws.
  ///
  /// [sampled] asks for the anti-piracy sampling: skip the server round trip
  /// when the cache is still young and the dice say no. An explicit refresh (the
  /// driver tapped something, or a purchase just landed) is never sampled.
  Future<void> refresh({bool sampled = false}) async {
    if (!_firebaseUp) return;
    if (sampled && !await _dueForReverify()) return;
    try {
      // Anonymous first, silently — requiring sign-in at first launch kills
      // installs (§3.4). The UID survives into the Google account via
      // linkWithCredential when the driver actually starts a trial.
      var user = _auth.currentUser;
      user ??= (await _auth.signInAnonymously()).user;
      if (user == null) return;

      // Google's own view of "now", used to heal a poisoned clock high-water
      // mark. Free — the token refresh happens anyway.
      final token = await user.getIdTokenResult(true);
      final issued = token.issuedAtTime;
      if (issued != null) await FoxClock.syncFromServer(issued);

      if (user.isAnonymous) {
        // No Google account yet: PRE_TRIAL, and there is no doc to read.
        state = await _resolve(
          startedAt: null,
          verifiedAt: state.verifiedAt,
          email: null,
        );
        return;
      }
      await _readTrialDoc(user);
    } catch (e) {
      // Offline, permission-denied, Firebase misconfigured — keep the cached
      // verdict. entitlementProvider decides when the cache has gone stale
      // enough to lock (§3.5).
      if (kDebugMode) debugPrint('FoxyCo trial refresh skipped: $e');
    }
  }

  /// Whether this launch should hit the server: always if we have never
  /// verified or the cache has outlived the grace window, otherwise on a
  /// 1-in-[_reverifyOneIn] roll.
  Future<bool> _dueForReverify() async {
    final verifiedAt = state.verifiedAt;
    if (verifiedAt == null) return true;
    final now = await FoxClock.now();
    if (now.difference(verifiedAt) >= offlineGrace) return true;
    return Random().nextInt(_reverifyOneIn) == 0;
  }

  /// Read `trials/{uid}` and fold it into state. Server-only read: the offline
  /// cache is ours (SharedPreferences), so a Firestore cache hit would just
  /// duplicate it and could hand back an unresolved server timestamp.
  Future<void> _readTrialDoc(User user) async {
    final snap = await FirebaseFirestore.instance
        .collection('trials')
        .doc(user.uid)
        .get(const GetOptions(source: Source.server));
    final startedAt = _startedAtOf(snap);
    final next = await _resolve(
      startedAt: startedAt,
      // Only a read that actually resolved counts as a verification — a doc
      // whose serverTimestamp is still pending proves nothing about the clock.
      verifiedAt: startedAt == null && snap.exists
          ? state.verifiedAt
          : DateTime.now().toUtc(),
      email: user.email,
    );
    state = next;
    await _saveCache(next);
  }

  /// `startedAt` as a real date, or null if the doc is missing or the server
  /// timestamp has not resolved yet.
  static DateTime? _startedAtOf(DocumentSnapshot<Map<String, dynamic>> snap) {
    if (!snap.exists) return null;
    final raw = snap.data()?['startedAt'];
    return raw is Timestamp ? raw.toDate().toUtc() : null;
  }

  /// "Start 7-day trial": Google Sign-In, then the write-once trial doc.
  ///
  /// This is where a returning user is caught. They arrive with a FRESH
  /// anonymous UID (app data cleared, reinstall, new phone), so linking their
  /// Google credential throws `credential-already-in-use`; falling back to
  /// `signInWithCredential` returns their ORIGINAL UID, whose trial doc already
  /// exists and is probably expired (§3.4.1). Without that fallback the
  /// reinstall would silently regrant 7 days and Firebase would buy us nothing
  /// over a local flag.
  Future<TrialStartResult> startTrial() async {
    if (_busy) return TrialStartResult.failed;
    if (!_firebaseUp) return TrialStartResult.failed;
    _busy = true;
    try {
      // serverClientId is not passed: the Android plugin falls back to
      // R.string.default_web_client_id, which the google-services plugin
      // generates from google-services.json. One less thing to keep in sync.
      await GoogleSignIn.instance.initialize();
      final account = await GoogleSignIn.instance.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null) return TrialStartResult.failed;
      final cred = GoogleAuthProvider.credential(idToken: idToken);

      final anon = _auth.currentUser;
      if (anon == null) {
        await _auth.signInWithCredential(cred);
      } else {
        try {
          await anon.linkWithCredential(cred);
        } on FirebaseAuthException catch (e) {
          if (e.code == 'credential-already-in-use' ||
              e.code == 'email-already-in-use') {
            // Returning user. Sign in to the ORIGINAL account and abandon the
            // throwaway anonymous one (orphans are free; clean up from the
            // console if the list ever gets noisy).
            await _auth.signInWithCredential(cred);
          } else {
            rethrow;
          }
        }
      }

      // The UID may have changed underneath us in the fallback above, so read
      // it back rather than reusing `anon`.
      final user = _auth.currentUser;
      if (user == null) return TrialStartResult.failed;

      final doc = FirebaseFirestore.instance.collection('trials').doc(user.uid);
      var snap = await doc.get(const GetOptions(source: Source.server));
      if (!snap.exists) {
        // serverTimestamp, NOT DateTime.now(): the security rule requires
        // startedAt == request.time, so a client-chosen date is rejected. That
        // is the point — the client cannot pick its own trial start.
        await doc.set({'startedAt': FieldValue.serverTimestamp()});
        snap = await doc.get(const GetOptions(source: Source.server));
      }

      final next = await _resolve(
        startedAt: _startedAtOf(snap),
        verifiedAt: DateTime.now().toUtc(),
        email: user.email,
      );
      state = next;
      await _saveCache(next);

      return switch (next.phase) {
        TrialPhase.active => TrialStartResult.started,
        TrialPhase.expired => TrialStartResult.alreadyExpired,
        // Doc written but the timestamp hasn't resolved — treat as retryable
        // rather than claiming a trial that may not have been recorded.
        TrialPhase.preTrial || TrialPhase.unknown => TrialStartResult.failed,
      };
    } on GoogleSignInException catch (e) {
      if (kDebugMode) debugPrint('FoxyCo sign-in failed: ${e.code}');
      return e.code == GoogleSignInExceptionCode.canceled
          ? TrialStartResult.cancelled
          : TrialStartResult.failed;
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo start trial failed: $e');
      return TrialStartResult.failed;
    } finally {
      _busy = false;
    }
  }

  /// Settings → About → Delete my account (Play requires an in-app path once
  /// accounts are collected, §5.1).
  ///
  /// Deletes the AUTH user and deliberately leaves `trials/{uid}` behind: the
  /// rules forbid the client deleting it, and what remains is a random uid plus
  /// a timestamp, which identifies nobody. Known ceiling: signing up again mints
  /// a new uid, hence a new trial — a much slower reset than clearing app data
  /// used to be, accepted at launch scale.
  Future<bool> deleteAccount() async {
    if (!_firebaseUp) return false;
    try {
      await _auth.currentUser?.delete();
      await GoogleSignIn.instance.signOut();
      await _clearCache();
      state = TrialState.initial;
      await refresh(); // straight back to a fresh anonymous identity
      return true;
    } catch (e) {
      // Most often `requires-recent-login`. The caller surfaces a retry.
      if (kDebugMode) debugPrint('FoxyCo delete account failed: $e');
      return false;
    }
  }

  Future<void> _clearCache() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyStartedAt);
      await prefs.remove(_keyVerifiedAt);
      await prefs.remove(_keyEmail);
    } catch (e) {
      if (kDebugMode) debugPrint('FoxyCo trial cache clear skipped: $e');
    }
  }
}

final trialProvider = NotifierProvider<TrialStore, TrialState>(TrialStore.new);
