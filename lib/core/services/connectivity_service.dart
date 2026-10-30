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

  bool _resolve(List<ConnectivityResult> r) =>
      r.isNotEmpty && r.any((x) => x != ConnectivityResult.none);

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
