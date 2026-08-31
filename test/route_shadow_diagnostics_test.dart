import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/domain/platform.dart';
import 'package:foxyco/services/accessibility/route_shadow_diagnostics.dart';

void main() {
  test('route shadow matches without logging addresses', () {
    final messages = <String>[];
    final shadow = RouteShadowDiagnostics(log: messages.add, salt: 1);

    shadow.recordOffer(GigPlatform.uber, 'offer-a', const [
      'Unit 132 - 2901 Bayview Ave, Toronto, ON',
      '1067 Dundas St W, Mississauga, ON',
    ]);
    shadow.recordOffer(GigPlatform.uber, 'offer-b', const [
      '91 Townsgate Dr',
      '82 Patterson Ave',
    ]);
    shadow.observeAcceptedScreen(GigPlatform.uber, const [
      'Waiting for rider',
      '2901 Bayview Avenue, Toronto',
    ]);
    shadow.observeAcceptedScreen(GigPlatform.uber, const [
      'Waiting for rider',
      '2901 Bayview Avenue, Toronto',
    ]);

    expect(messages, hasLength(3));
    expect(messages.last, contains('pending=2'));
    expect(messages.last, contains('score=100 unique=true'));
    expect(messages.join(' '), isNot(contains('Bayview')));
    expect(messages.join(' '), isNot(contains('Dundas')));
  });
}
