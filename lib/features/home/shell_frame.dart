import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/widgets/unsaved_changes_guard.dart';

/// Keeps the bottom bar (or the side menu) on screen across every page: the
/// pages live in a navigator of their own, with the menu outside it.
///
/// A page opened from anywhere inside [home] lands in that navigator, so
/// screens need nothing special. Dialogs still go to the app's navigator and
/// cover the menu; bottom sheets open above it.
class ShellFrame extends StatefulWidget {
  const ShellFrame({
    super.key,
    required this.navigatorKey,
    required this.home,
    required this.onSelect,
    this.bottomBar,
    this.sideMenu,
  });

  final GlobalKey<NavigatorState> navigatorKey;

  /// The first page: the tabs.
  final Widget home;

  /// A tab was chosen and the pages above [home] are closed.
  final ValueChanged<int> onSelect;

  /// Builds the bar under the pages; `select` is what a tap on it calls.
  /// Hidden while the keyboard is open.
  final Widget Function(ValueChanged<int> select)? bottomBar;

  /// Builds the menu beside the pages (wide screens).
  final Widget Function(ValueChanged<int> select)? sideMenu;

  @override
  State<ShellFrame> createState() => _ShellFrameState();
}

class _ShellFrameState extends State<ShellFrame> {
  late final _routes = _RouteStack(onPopped: _onPopped);
  final _heroes = MaterialApp.createMaterialHeroController();

  /// The tab asked for while a page with unsaved changes is still open.
  int? _pending;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    UnsavedChangesGuard.kept.addListener(_forgetPending);
  }

  @override
  void dispose() {
    UnsavedChangesGuard.kept.removeListener(_forgetPending);
    _heroes.dispose();
    super.dispose();
  }

  /// The person chose to keep editing: stay where they are.
  void _forgetPending() => _pending = null;

  void _select(int index) {
    _pending = index;
    unawaited(_close());
  }

  /// Closes the pages above the tabs one at a time, the way the back button
  /// does, so a page with unsaved changes still asks first.
  Future<void> _close() async {
    if (_closing) return;
    _closing = true;
    try {
      while (_pending != null && _routes.length > 1) {
        final top = _routes.top;
        await widget.navigatorKey.currentState?.maybePop();
        // Still there: it asked the person. [_onPopped] carries on if it goes.
        if (identical(_routes.top, top)) return;
      }
      final index = _pending;
      _pending = null;
      if (index != null && mounted) widget.onSelect(index);
    } finally {
      _closing = false;
    }
  }

  void _onPopped() {
    if (_pending == null || _closing) return;
    // Not during the pop itself: the navigator is locked then.
    scheduleMicrotask(() {
      if (mounted) unawaited(_close());
    });
  }

  @override
  Widget build(BuildContext context) {
    final keyboard = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bar = keyboard ? null : widget.bottomBar?.call(_select);
    final menu = widget.sideMenu?.call(_select);

    Widget pages = NavigatorPopHandler<Object?>(
      onPopWithResult: (_) => widget.navigatorKey.currentState?.maybePop(),
      child: HeroControllerScope(
        controller: _heroes,
        child: Navigator(
          key: widget.navigatorKey,
          observers: [_routes],
          pages: [
            MaterialPage<void>(
              key: const ValueKey('shell-home'),
              child: widget.home,
            ),
          ],
          onDidRemovePage: (_) {},
        ),
      ),
    );
    // The bar already clears the phone's bottom edge.
    if (bar != null) {
      pages = MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: pages,
      );
    }

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      // The same shape with and without the bar, so the pages keep their
      // state when the keyboard hides it.
      child: Row(
        children: [
          if (menu != null) ...[
            SafeArea(child: menu),
            const VerticalDivider(width: 1, thickness: 1),
          ],
          Expanded(
            key: const ValueKey('shell-pages'),
            child: Column(
              children: [
                Expanded(child: pages),
                if (bar != null) bar,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pages open in the shell's navigator, newest last.
class _RouteStack extends NavigatorObserver {
  _RouteStack({required this.onPopped});

  final VoidCallback onPopped;
  final _stack = <Route<dynamic>>[];

  int get length => _stack.length;
  Route<dynamic>? get top => _stack.lastOrNull;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.add(route);

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _stack.remove(route);
    onPopped();
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) =>
      _stack.remove(route);

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    final at = oldRoute == null ? -1 : _stack.indexOf(oldRoute);
    if (at >= 0 && newRoute != null) _stack[at] = newRoute;
  }
}
