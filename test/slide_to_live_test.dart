import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';
import 'package:foxyco/ui/home/slide_to_live.dart';

class _Harness extends StatefulWidget {
  const _Harness({super.key, required this.initial});
  final WatchStatus initial;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  late WatchStatus status = widget.initial;
  int starts = 0, stops = 0, fixes = 0;

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      body: Center(
        child: SizedBox(
          width: 320,
          child: SlideToLive(
            status: status,
            onStart: () => setState(() {
              starts++;
              status = WatchStatus.watching;
            }),
            onStop: () => setState(() {
              stops++;
              status = WatchStatus.stopped;
            }),
            onFix: () => fixes++,
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('full drag right commits start', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    final thumb = find.byKey(const ValueKey('slide-thumb'));
    expect(thumb, findsOneWidget);
    await tester.drag(thumb, const Offset(320, 0));
    // Commit fires onStart synchronously; status → watching (a perpetual
    // pulse), so a bounded pump is used rather than pumpAndSettle.
    await tester.pump();
    expect(key.currentState!.starts, 1);
  });

  testWidgets('short drag springs back, no start', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    await tester.drag(
      find.byKey(const ValueKey('slide-thumb')),
      const Offset(40, 0),
    );
    await tester.pumpAndSettle();
    expect(key.currentState!.starts, 0);
  });

  testWidgets('watching shows live bar; drag back stops', (tester) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.watching));
    // Live bar pulses forever; a couple of bounded pumps stand in for settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    final stopThumb = find.byKey(const ValueKey('slide-stop-thumb'));
    expect(stopThumb, findsOneWidget);
    await tester.drag(stopThumb, const Offset(-320, 0));
    await tester.pump();
    expect(key.currentState!.stops, 1);
  });

  testWidgets('semantic button path works without sliding (a11y)', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.stopped));
    await tester.pump();
    final semantics = tester.getSemantics(
      find.byKey(const ValueKey('slide-to-live-semantics')),
    );
    expect(semantics.label, contains('Go live'));
    // Tap-activation path (SemanticsAction.tap wired to onStart).
    tester.semantics.performAction(
      find.semantics.byLabel('Go live'),
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(key.currentState!.starts, 1);
  });

  testWidgets('blocked state routes to onFix via semantics tap', (
    tester,
  ) async {
    final key = GlobalKey<_HarnessState>();
    await tester.pumpWidget(_Harness(key: key, initial: WatchStatus.blocked));
    await tester.pump();
    tester.semantics.performAction(
      find.semantics.byLabel('Grant access'),
      SemanticsAction.tap,
    );
    await tester.pump();
    expect(key.currentState!.fixes, 1);
  });
}
