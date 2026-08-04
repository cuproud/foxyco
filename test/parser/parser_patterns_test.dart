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
}
