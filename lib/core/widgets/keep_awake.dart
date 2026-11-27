import 'package:flutter/widgets.dart';

import '../services/web_pwa_stub.dart'
    if (dart.library.js_interop) '../services/web_pwa_web.dart';

/// Keeps the website's screen on while [child] is the page being looked at:
/// taking attendance, the phone otherwise sleeps between two children. A tab
/// in the background lets the screen sleep as usual.
class KeepAwake extends StatefulWidget {
  const KeepAwake({super.key, required this.child, this.apply});

  final Widget child;

  /// Replaces the browser, for tests.
  final void Function(bool on)? apply;

  @override
  State<KeepAwake> createState() => _KeepAwakeState();
}

class _KeepAwakeState extends State<KeepAwake> {
  /// How many pages want the screen on (the tab and a pushed one can both).
  static int _wanting = 0;
  bool _mine = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _set(TickerMode.valuesOf(context).enabled);
  }

  void _set(bool on) {
    if (on == _mine) return;
    _mine = on;
    final before = _wanting;
    _wanting += on ? 1 : -1;
    if (before == 0 || _wanting == 0) {
      (widget.apply ?? setScreenAwake)(_wanting > 0);
    }
  }

  @override
  void dispose() {
    _set(false);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
