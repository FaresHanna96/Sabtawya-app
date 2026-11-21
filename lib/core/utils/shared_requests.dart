/// Lets callers asking for the same thing at the same moment share one
/// request. Only a request still running is shared; once it finishes, the
/// next call starts a new one, so nothing is ever served from an old answer.
class SharedRequests<T> {
  final _running = <String, Future<T>>{};

  /// The running request for [key], or a new one from [fetch].
  Future<T> run(String key, Future<T> Function() fetch) =>
      _running[key] ??= fetch().whenComplete(() {
        // A block body on purpose: `remove` returns this very future, and
        // whenComplete would wait for it, so the request would never finish.
        _running.remove(key);
      });

  /// How many requests are running; for tests.
  int get runningCount => _running.length;
}
