import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/utils/shared_requests.dart';

void main() {
  test('callers at the same moment share one request', () async {
    final shared = SharedRequests<int>();
    var calls = 0;
    final gate = Completer<int>();
    Future<int> fetch() {
      calls++;
      return gate.future;
    }

    final a = shared.run('k', fetch);
    final b = shared.run('k', fetch);
    expect(calls, 1);
    gate.complete(7);
    expect(await a, 7);
    expect(await b, 7);
  });

  test('a finished request is not reused, and finishes at all', () async {
    final shared = SharedRequests<int>();
    var calls = 0;
    Future<int> fetch() async => ++calls;

    // Would time out if the request waited on itself.
    expect(await shared.run('k', fetch).timeout(const Duration(seconds: 1)), 1);
    expect(shared.runningCount, 0);
    expect(await shared.run('k', fetch), 2);
  });

  test('different keys do not share', () async {
    final shared = SharedRequests<String>();
    final a = shared.run('a', () async => 'A');
    final b = shared.run('b', () async => 'B');
    expect(await a, 'A');
    expect(await b, 'B');
  });

  test('a failure reaches every caller and is not kept', () async {
    final shared = SharedRequests<int>();
    final gate = Completer<int>();
    final a = shared.run('k', () => gate.future);
    final b = shared.run('k', () => gate.future);
    gate.completeError(StateError('offline'));
    await expectLater(a, throwsStateError);
    await expectLater(b, throwsStateError);
    expect(shared.runningCount, 0);
    expect(await shared.run('k', () async => 3), 3);
  });
}
