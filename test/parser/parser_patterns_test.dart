import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/parser/offer_parser.dart';

void main() {
  test('Lyft Arrive must be an exact action node', () {
    expect(
      ParserPatterns.looksLikeAcceptedTrip(GigPlatform.lyft, const ['Arrive']),
      isTrue,
    );
    expect(
      ParserPatterns.looksLikeAcceptedTrip(GigPlatform.lyft, const [
        'You will arrive in 5 minutes',
      ]),
      isFalse,
    );
  });

  test('strong Lyft and Uber trip controls count as accepted', () {
    expect(
      ParserPatterns.looksLikeAcceptedTrip(GigPlatform.lyft, const [
        'Slide to pick up',
      ]),
      isTrue,
    );
    expect(
      ParserPatterns.looksLikeAcceptedTrip(GigPlatform.uber, const [
        'Start UberX',
      ]),
      isTrue,
    );
  });

  test('real Hopp pickup, trip and completion states count as accepted', () {
    for (final state in const [
      'You have arrived',
      'Arrived',
      'Wait here',
      '01:59 Waiting',
      'Start Trip',
      'End Trip',
      'Confirm Price',
      'Rate passenger',
    ]) {
      expect(
        ParserPatterns.looksLikeAcceptedTrip(GigPlatform.hopp, [state]),
        isTrue,
        reason: state,
      );
    }
  });

  test('generic Hopp waiting and confirm copy stays unconfirmed', () {
    for (final state in const [
      'Waiting for offers',
      'Confirm',
      'Price estimate',
      'You will arrive in 5 minutes',
    ]) {
      expect(
        ParserPatterns.looksLikeAcceptedTrip(GigPlatform.hopp, [state]),
        isFalse,
        reason: state,
      );
    }
  });
}
