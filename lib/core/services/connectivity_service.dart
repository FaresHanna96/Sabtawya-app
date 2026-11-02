import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';

class ConnectivityService extends ChangeNotifier {
  ConnectivityService._();
  static final ConnectivityService instance = ConnectivityService._();

  bool _isOnline = true;
  bool get isOnline => _isOnline;

  StreamSubscription<List<ConnectivityResult>>? _sub;

  Future<void> init() async {
    final result = await Connectivity().checkConnectivity();
    _isOnline = _resolve(result);
    _sub = Connectivity().onConnectivityChanged.listen(_onChanged);
  }

  void _onChanged(List<ConnectivityResult> results) {
    final online = _resolve(results);
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  /// A request that really reached (or failed to reach) the server is a better
  /// signal than the platform flag, which is unreliable on the web.
  void markOnline() => _set(true);
  void markOffline() => _set(false);

  void _set(bool online) {
    if (online == _isOnline) return;
    _isOnline = online;
    notifyListeners();
  }

  bool _resolve(List<ConnectivityResult> r) =>
      r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
