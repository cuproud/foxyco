import 'dart:math';

import '../../domain/platform.dart';

/// Diagnostic-only route matching. Location text stays in memory; logs receive
/// only per-process fingerprints, counts, and similarity scores.
class RouteShadowDiagnostics {
  RouteShadowDiagnostics({required this.log, int? salt})
    : _salt = salt ?? Random.secure().nextInt(1 << 31);

  final void Function(String message) log;
  final int _salt;
  final Map<GigPlatform, List<_ShadowOffer>> _offers = {};
  final Map<GigPlatform, String> _lastObservation = {};

  void recordOffer(GigPlatform platform, String offerKey, List<String> texts) {
    final routes = _routes(texts);
    final pending = _offers.putIfAbsent(platform, () => []);
    final offer = _ShadowOffer(_id(offerKey), routes);
    pending.insert(0, offer);
    if (pending.length > 8) pending.removeRange(8, pending.length);
    log(
      '${platform.label} offer=${offer.id} candidates=${routes.length} '
      'ids=${routes.map((route) => _id(route.join(' '))).join(',')}',
    );
  }

  void observeAcceptedScreen(GigPlatform platform, List<String> texts) {
    final routes = _routes(texts);
    final pending = _offers[platform] ?? const <_ShadowOffer>[];
    final signature =
        '${routes.map((route) => _id(route.join(' '))).join(',')}|'
        '${pending.map((offer) => offer.id).join(',')}';
    if (_lastObservation[platform] == signature) return;
    _lastObservation[platform] = signature;
    final scores = [
      for (final offer in pending)
        (offer: offer, score: _score(offer.routes, routes)),
    ]..sort((a, b) => b.score.compareTo(a.score));
    final best = scores.isEmpty ? null : scores.first;
    final next = scores.length < 2 ? null : scores[1];
    final unique =
        best != null &&
        best.score >= 0.7 &&
        (next == null || best.score - next.score >= 0.2);
    log(
      '${platform.label} accepted-screen candidates=${routes.length} '
      'pending=${pending.length} best=${best?.offer.id ?? '-'} '
      'score=${((best?.score ?? 0) * 100).round()} unique=$unique',
    );
  }

  String _id(String value) => ((_salt.toString() + value).hashCode & 0x7fffffff)
      .toRadixString(16)
      .padLeft(8, '0');

  static double _score(List<Set<String>> offer, List<Set<String>> screen) {
    var best = 0.0;
    for (final left in offer) {
      for (final right in screen) {
        final shared = left.intersection(right).length;
        if (shared == 0) continue;
        best = max(best, shared / min(left.length, right.length));
      }
    }
    return best;
  }

  static final _routeShape = RegExp(
    r'\b\d{1,6}\s+[a-z]|\b(?:st(?:reet)?|rd|road|ave(?:nue)?|dr(?:ive)?|'
    r'blvd|boulevard|lane|ln|court|ct|way|trail|trl|cres(?:cent)?|circuit|'
    r'pkwy|parkway|hwy|highway)\b|\s&\s|'
    r'\b[abceghjklmnprstvxy]\d[abceghjklmnprstvwxyz]\s?\d[abceghjklmnprstvwxyz]\d\b',
    caseSensitive: false,
  );
  static final _ignored = RegExp(
    r'\$|\b(?:min|mins|km|mile|away|trip|accept|match|decline|dismiss|'
    r'picking up|waiting|start|complete|dropping off|navigate|arrived|'
    r'passenger|rider|bonus|rate|uber|lyft|hopp)\b',
    caseSensitive: false,
  );
  static const _common = {
    'toronto',
    'ontario',
    'canada',
    'on',
    'ca',
    'the',
    'at',
    'unit',
  };
  static const _aliases = {
    'avenue': 'ave',
    'street': 'st',
    'road': 'rd',
    'drive': 'dr',
    'boulevard': 'blvd',
    'lane': 'ln',
    'court': 'ct',
    'trail': 'trl',
    'crescent': 'cres',
    'parkway': 'pkwy',
    'highway': 'hwy',
  };

  static List<Set<String>> _routes(List<String> texts) => [
    for (final text in texts)
      if (_routeShape.hasMatch(text) && !_ignored.hasMatch(text))
        {
          for (final token
              in text
                  .toLowerCase()
                  .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
                  .split(' '))
            if (token.length > 1 && !_common.contains(token))
              _aliases[token] ?? token,
        },
  ].where((tokens) => tokens.isNotEmpty).toList();
}

class _ShadowOffer {
  const _ShadowOffer(this.id, this.routes);

  final String id;
  final List<Set<String>> routes;
}
