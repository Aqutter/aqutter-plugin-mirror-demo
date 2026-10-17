import 'dart:math' as math;

import 'package:aqutter/aqutter.dart';
import 'package:flutter/material.dart';

/// native view 鏡像範例：一個純 Flutter 的互動畫面（圓、計數、色票），墊在 WebView 之下，
/// 以 `AqutterNative` 鏡像到網頁的 `<aqutter-native session="mirror-demo">`。
///
/// 輸入有兩種接法（網頁 `<aqutter-native input="…">`）：
///   - `gestures`（預設）：網頁判斷好 tap／pan／pinch 再傳來，由 [MirrorDemoState.apply] 套用。
///   - `pointers`：網頁只轉送原始指標事件，由畫面上的 `GestureDetector` 判斷（連點、長按、縮放都是 Flutter 的標準行為）。
///
/// 網頁端的手勢回到這裡改變畫面：
///   - `pan`：拖動圓　`pinch`：縮放圓　`tap`：計數 +1　`doubleTap`：歸零
///   - `longPress`：換色　`command` `reset`：回到初始狀態
///
/// 鏡像的對象換成 `google_maps_flutter` 的 `GoogleMap` 也是同一套寫法，見 README。
class MirrorDemoPlugin extends AqutterPlugin {
  MirrorDemoPlugin({this.fps = 60, this.adaptive = AqutterNativeAdaptive.resolution});

  /// 鏡像的目標幀率。
  final int fps;

  /// 擷取跟不上時的策略；範例預設「降解析度、停下來補定格幀」。
  final AqutterNativeAdaptive adaptive;

  final MirrorDemoState state = MirrorDemoState();

  @override
  String get id => 'mirror-demo';

  @override
  Map<String, AqutterPluginHandler> get handlers => {
        // 網頁也能用一般 plugin 方法讀目前狀態（鏡像是另一條通道，互不影響）
        'state': (payload) async => state.toJson(),
      };

  @override
  void attach(AqutterPluginContext context) {
    state.onCountChanged = (count) => context.emit('count', {'count': count});
  }

  @override
  Widget? buildUnderlay(BuildContext context) {
    return Positioned.fill(
      child: AqutterNative(
        sessionId: 'mirror-demo',
        fps: fps,
        adaptive: adaptive,
        matchViewportAspect: true,
        injectPointers: true, // 網頁 input="pointers" 時，由下面的 GestureDetector 自己判斷手勢
        onMessage: state.apply,
        child: _DemoCanvas(state: state),
      ),
    );
  }

  @override
  void dispose() {
    state.dispose();
  }
}

/// 畫面狀態；網頁手勢經 [apply] 改它，[_DemoCanvas] 監聽並重繪。
class MirrorDemoState extends ChangeNotifier {
  static const List<Color> palette = [Color(0xFF3F51B5), Color(0xFFE91E63), Color(0xFF009688), Color(0xFFFF9800)];

  /// 圓心位置與大小，皆為 0..1 的正規化值（相對畫面）。
  Offset center = const Offset(0.5, 0.5);
  double radius = 0.18;
  int count = 0;
  int colorIndex = 0;

  double _radiusAtPinchStart = 0.18;

  void Function(int count)? onCountChanged;

  Color get color => palette[colorIndex % palette.length];

  void apply(AqutterNativeMessage message) {
    switch (message.type) {
      case 'pan':
        if (message.data['phase'] == 'update') {
          center = Offset(
            (center.dx + (message.number('dx') ?? 0)).clamp(0.0, 1.0),
            (center.dy + (message.number('dy') ?? 0)).clamp(0.0, 1.0),
          );
        }
      case 'pinch':
        final phase = message.data['phase'];
        if (phase == 'start') {
          _radiusAtPinchStart = radius;
        }
        else if (phase == 'update') {
          radius = (_radiusAtPinchStart * (message.number('scale') ?? 1)).clamp(0.05, 0.45);
        }
      case 'tap':
        count += 1;
        onCountChanged?.call(count);
      case 'doubleTap':
        count = 0;
        onCountChanged?.call(count);
      case 'longPress':
        colorIndex += 1;
      case 'command':
        if (message.data['name'] == 'reset') {
          center = const Offset(0.5, 0.5);
          radius = 0.18;
          count = 0;
          colorIndex = 0;
          onCountChanged?.call(count);
        }
      default:
        return;
    }
    notifyListeners();
  }

  Map<String, Object> toJson() => {
        'x': center.dx,
        'y': center.dy,
        'radius': radius,
        'count': count,
      };
}

class _DemoCanvas extends StatelessWidget {
  const _DemoCanvas({required this.state});

  final MirrorDemoState state;

  static AqutterNativeMessage _message(String type, [Map<String, dynamic> data = const {}]) => AqutterNativeMessage(type, data);

  @override
  Widget build(BuildContext context) {
    final canvas = ListenableBuilder(
      listenable: state,
      builder: (context, _) => CustomPaint(
        painter: _DemoPainter(state),
        child: const SizedBox.expand(),
      ),
    );
    // 原始指標事件模式下由 Flutter 判斷手勢；語意手勢模式沒有指標事件進來，這層不會觸發。
    return LayoutBuilder(
      builder: (context, constraints) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => state.apply(_message('tap')),
        onDoubleTap: () => state.apply(_message('doubleTap')),
        onLongPress: () => state.apply(_message('longPress')),
        onScaleStart: (details) {
          if (details.pointerCount >= 2) {
            state.apply(_message('pinch', {'phase': 'start'}));
          }
        },
        onScaleUpdate: (details) {
          if (details.pointerCount >= 2) {
            state.apply(_message('pinch', {'phase': 'update', 'scale': details.scale}));
          }
          else {
            state.apply(_message('pan', {
              'phase': 'update',
              'dx': constraints.maxWidth > 0 ? details.focalPointDelta.dx / constraints.maxWidth : 0,
              'dy': constraints.maxHeight > 0 ? details.focalPointDelta.dy / constraints.maxHeight : 0,
            }));
          }
        },
        child: canvas,
      ),
    );
  }
}

class _DemoPainter extends CustomPainter {
  _DemoPainter(this.state) : super(repaint: state);

  final MirrorDemoState state;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF14141C));
    final grid = Paint()
      ..color = const Color(0x22FFFFFF)
      ..strokeWidth = 1;
    for (var i = 1; i < 10; i++) {
      canvas.drawLine(Offset(size.width * i / 10, 0), Offset(size.width * i / 10, size.height), grid);
      canvas.drawLine(Offset(0, size.height * i / 10), Offset(size.width, size.height * i / 10), grid);
    }
    final center = Offset(state.center.dx * size.width, state.center.dy * size.height);
    final radius = state.radius * math.min(size.width, size.height);
    canvas.drawCircle(center, radius, Paint()..color = state.color);
    final text = TextPainter(
      text: TextSpan(
        text: '${state.count}',
        style: TextStyle(color: Colors.white, fontSize: radius, fontWeight: FontWeight.bold),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, center - Offset(text.width / 2, text.height / 2));
  }

  @override
  bool shouldRepaint(_DemoPainter oldDelegate) => true;
}
