import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:foxyco/ui/settings/about_content.dart';

void main() {
  test('displayed version matches pubspec build metadata', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^+\s]+)\+(\d+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull);
    expect(aboutVersion, '${match!.group(1)} (build ${match.group(2)})');
  });

  test('FAQ describes the one-time unlock and current Firebase data use', () {
    final copy = aboutSections
        .expand(
          (section) => [section.blurb, ...section.entries.map((e) => e.answer)],
        )
        .join(' ');

    expect(copy, contains('One Google Play purchase unlocks FoxyCo for life'));
    expect(copy, contains('There is no monthly or annual renewal'));
    expect(copy, contains('one server-stamped trial start time'));
    expect(copy, contains('Raw screen text is used briefly in memory'));
    expect(copy, contains('Firebase never receives offer text'));
    expect(copy, isNot(contains('There is no account, no server')));
  });
}
