import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_controller.dart';
import '../utils/app_failure.dart';
import 'app_widgets.dart';

/// Owns a future and renders loading, error, and success states.
///
/// Every data-driven screen in the app uses this so retry and pull-to-refresh
/// behave identically everywhere. The builder receives a `reload` callback to
/// re-run [load] after a mutation.
class AsyncSection<T> extends StatefulWidget {
  const AsyncSection({
    super.key,
    required this.load,
    required this.builder,
    this.enableRefresh = true,
    this.loadingMessage,
    this.loading,
  });

  final Future<T> Function() load;
  final Widget Function(
      BuildContext context, T data, Future<void> Function() reload) builder;
  final bool enableRefresh;
  final String? loadingMessage;

  /// Shown instead of the logo loader on the first load. List screens pass a
  /// `SkeletonList` so the rows' shape is on screen before the rows are.
  final Widget? loading;

  @override
  State<AsyncSection<T>> createState() => AsyncSectionState<T>();
}

class AsyncSectionState<T> extends State<AsyncSection<T>> {
  late Future<T> _future;
  T? _last;
  bool _hasLast = false;
  int? _version;

  @override
  void initState() {
    super.initState();
    _future = widget.load();
  }

  Future<void> reload() async {
    final next = widget.load();
    setState(() {
      _future = next;
    });
    // The failure is swallowed here because the FutureBuilder below already
    // renders it; rethrowing would also break RefreshIndicator's animation.
    await next.then<void>((_) {}, onError: (Object _) {});
  }

  @override
  Widget build(BuildContext context) {
    // Reload whenever something anywhere in the app changed data.
    int? version;
    try {
      version = context.watch<SessionController>().dataVersion;
    } catch (_) {
      version = null; // no provider above, e.g. in widget tests
    }
    if (_version != null && version != null && version != _version) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) reload();
      });
    }
    _version = version;

    return FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        // The loader, an error and the content cross-fade instead of
        // popping in. Content keeps one key, so a background reload swaps
        // the data in place without fading the screen again.
        final Widget child;
        final String state;
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Keep the old content on screen while a background reload runs.
          if (_hasLast) {
            child = _content(context, _last as T);
            state = 'content';
          } else {
            child = widget.loading ??
                LoadingView(message: widget.loadingMessage);
            state = 'loading';
          }
        } else if (snapshot.hasError) {
          child = ErrorView(
            message: AppFailure.from(snapshot.error!).message,
            onRetry: reload,
          );
          state = 'error';
        } else {
          _last = snapshot.data as T;
          _hasLast = true;
          child = _content(context, _last as T);
          state = 'content';
        }
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOutCubic,
          switchOutCurve: Curves.easeInCubic,
          child: KeyedSubtree(key: ValueKey(state), child: child),
        );
      },
    );
  }

  Widget _content(BuildContext context, T data) {
    final content = widget.builder(context, data, reload);
    if (!widget.enableRefresh) return content;
    return RefreshIndicator(onRefresh: reload, child: content);
  }
}
