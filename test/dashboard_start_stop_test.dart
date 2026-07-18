import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foxyco/ui/home/dashboard_controller.dart';
import 'package:foxyco/ui/home/dashboard_state.dart';

void main() {
  test('boots stopped, never watching', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('startMonitoring → watching; stopMonitoring → stopped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.watching);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('pause layers on top of running; stop from paused works', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final c = container.read(dashboardProvider.notifier);
    c.startMonitoring();
    c.togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.paused);
    c.stopMonitoring();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });

  test('togglePause is a no-op while stopped', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(dashboardProvider.notifier).togglePause();
    expect(container.read(dashboardProvider).status, WatchStatus.stopped);
  });
}
