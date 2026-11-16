import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:sabtawya/core/services/offline_store.dart';

HiveCipher _cipher() => HiveAesCipher(List<int>.generate(32, (i) => i + 1));

QueuedRequest _write(String label, {String? user}) => QueuedRequest(
      id: OfflineStore.nextId(),
      method: 'POST',
      url: 'https://example.supabase.co/rest/v1/$label',
      headers: const {'content-type': 'application/json'},
      bodyBase64: base64Encode(utf8.encode('{"full_name":"مينا سر الخبأ"}')),
      label: label,
      createdAt: DateTime.now(),
      user: user,
    );

/// Every byte of every file the boxes wrote.
String _diskText(Directory dir) => dir
    .listSync()
    .whereType<File>()
    .map((f) => latin1.decode(f.readAsBytesSync()))
    .join();

void main() {
  late Directory dir;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('store_enc');
    Hive.init(dir.path);
  });

  tearDown(() async {
    await Hive.close();
    dir.deleteSync(recursive: true);
  });

  test('with a key, waiting writes and kept reads are not readable on disk',
      () async {
    await OfflineStore.init(cipherProvider: () async => _cipher());
    expect(OfflineStore.isEncrypted, isTrue);

    await OfflineStore.enqueue(_write('children', user: 'user-a'));
    await OfflineStore.putCached('k', {
      'table': 'children',
      'url': 'https://example.supabase.co/rest/v1/children',
      'body': '[{"full_name":"اسم ظاهر"}]',
    });
    await Hive.close(); // flush to disk

    final onDisk = _diskText(dir);
    expect(onDisk, isNotEmpty);
    expect(onDisk.contains('children'), isFalse);
    expect(onDisk.contains('user-a'), isFalse);
    expect(onDisk.contains('full_name'), isFalse);
  });

  test('the same key reads the data back after a restart', () async {
    await OfflineStore.init(cipherProvider: () async => _cipher());
    await OfflineStore.enqueue(_write('children', user: 'user-a'));
    await Hive.close();

    await OfflineStore.init(cipherProvider: () async => _cipher());

    expect(OfflineStore.pendingCount(), 1);
    expect(OfflineStore.pendingWrites().single.user, 'user-a');
  });

  test('without a keystore the plain boxes are used and still work', () async {
    await OfflineStore.init(cipherProvider: () async => null);
    expect(OfflineStore.isEncrypted, isFalse);

    await OfflineStore.enqueue(_write('children'));
    expect(OfflineStore.pendingCount(), 1);
  });

  test('plain boxes from an older version move over, then are deleted',
      () async {
    // The app as it was: no key.
    await OfflineStore.init(cipherProvider: () async => null);
    await OfflineStore.enqueue(_write('children', user: 'user-a'));
    await OfflineStore.enqueue(_write('classes', user: 'user-a'));
    final refused = _write('events', user: 'user-a');
    await OfflineStore.enqueue(refused);
    await OfflineStore.markFailed(refused, '409 duplicate');
    await OfflineStore.putCached('k', {'table': 't', 'url': 'u', 'body': '[]'});
    await Hive.close();
    expect(_diskText(dir).contains('children'), isTrue);

    // The update: a key exists now.
    await OfflineStore.init(cipherProvider: () async => _cipher());

    expect(OfflineStore.pendingWrites().map((w) => w.label),
        ['children', 'classes']);
    expect(OfflineStore.failedWrites().single.error, '409 duplicate');
    expect(OfflineStore.getCached('k'), isNull); // reads are fetched again
    expect(await Hive.boxExists('write_queue_v2'), isFalse);
    expect(await Hive.boxExists('write_failed_v2'), isFalse);
    expect(await Hive.boxExists('http_cache_v1'), isFalse);

    await Hive.close();
    final onDisk = _diskText(dir);
    expect(onDisk.contains('children'), isFalse);
    expect(onDisk.contains('409 duplicate'), isFalse);
  });

  test('a lost key starts the boxes again instead of crashing', () async {
    await OfflineStore.init(cipherProvider: () async => _cipher());
    await OfflineStore.enqueue(_write('children'));
    await Hive.close();

    final other = HiveAesCipher(List<int>.generate(32, (i) => 99 - i));
    await OfflineStore.init(cipherProvider: () async => other);

    expect(OfflineStore.pendingCount(), 0);
    await OfflineStore.enqueue(_write('classes'));
    expect(OfflineStore.pendingCount(), 1);
  });
}
