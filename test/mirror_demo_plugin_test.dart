import 'package:aqutter/aqutter.dart';
import 'package:aqutter_plugin_mirror_demo/aqutter_plugin_mirror_demo.dart';
import 'package:flutter_test/flutter_test.dart';

AqutterNativeMessage message(String type, [Map<String, dynamic> data = const {}]) =>
    AqutterNativeMessage(type, {'type': type, ...data});

void main() {
  test('id follows the naming rule', () {
    expect(MirrorDemoPlugin().id, 'mirror-demo');
  });

  test('tap counts, doubleTap resets, and the count event fires', () {
    final state = MirrorDemoState();
    final counts = <int>[];
    state.onCountChanged = counts.add;
    state
      ..apply(message('tap'))
      ..apply(message('tap'))
      ..apply(message('doubleTap'));
    expect(counts, [1, 2, 0]);
    expect(state.count, 0);
  });

  test('pan moves the circle and clamps to the canvas', () {
    final state = MirrorDemoState();
    state.apply(message('pan', {'phase': 'update', 'dx': 0.1, 'dy': -0.2}));
    expect(state.center.dx, closeTo(0.6, 1e-9));
    expect(state.center.dy, closeTo(0.3, 1e-9));
    state.apply(message('pan', {'phase': 'update', 'dx': 5.0, 'dy': -5.0}));
    expect(state.center.dx, 1.0);
    expect(state.center.dy, 0.0);
  });

  test('pinch scales relative to the radius at pinch start', () {
    final state = MirrorDemoState();
    state
      ..apply(message('pinch', {'phase': 'start', 'scale': 1}))
      ..apply(message('pinch', {'phase': 'update', 'scale': 2}));
    expect(state.radius, closeTo(0.36, 1e-9));
    state.apply(message('pinch', {'phase': 'update', 'scale': 100}));
    expect(state.radius, 0.45);
  });

  test('longPress cycles colors and the reset command restores everything', () {
    final state = MirrorDemoState();
    final first = state.color;
    state
      ..apply(message('longPress'))
      ..apply(message('tap'));
    expect(state.color, isNot(first));
    state.apply(message('command', {'name': 'reset'}));
    expect(state.color, first);
    expect(state.count, 0);
    expect(state.radius, 0.18);
  });

  test('state handler reports the current values', () async {
    final plugin = MirrorDemoPlugin();
    plugin.state.apply(message('tap'));
    expect((await plugin.handlers['state']!({}))['count'], 1);
  });
}
