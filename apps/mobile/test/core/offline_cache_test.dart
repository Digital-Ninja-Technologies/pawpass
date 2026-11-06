import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:pawpass/core/dates.dart';
import 'package:pawpass/core/offline_cache.dart';

class ClientException implements Exception {
  @override
  String toString() => 'ClientException: connection failed';
}

class _BrokenStore extends MemoryKeyValueStore {
  @override
  Future<void> write(String key, String value) async =>
      throw Exception('disk full');
}

final _t0 = DateTime.utc(2026, 11, 5, 8, 41);

void main() {
  late MemoryKeyValueStore store;
  late OfflineCache cache;
  var now = _t0;

  setUp(() {
    store = MemoryKeyValueStore();
    now = _t0;
    cache = OfflineCache(store, now: () => now);
  });

  Future<List<String>> read(Future<Object?> Function() load) => cache.fetch(
    key: 'u1/pets',
    load: load,
    parse: (j) => [for (final x in (j as List)) x as String],
  );

  test('a fresh read is returned and saved', () async {
    expect(await read(() async => ['Bingo', 'Mimi']), ['Bingo', 'Mimi']);
    expect(cache.offline, isFalse);
    expect(store.data.keys.single, 'pawpass.cache.u1/pets');
  });

  test(
    'with no connection the saved copy is returned, and says when it was saved',
    () async {
      await read(() async => ['Bingo']);
      final notified = <bool>[];
      cache.addListener(() => notified.add(cache.offline));
      now = _t0.add(const Duration(hours: 3));
      expect(await read(() async => throw const SocketException('no route')), [
        'Bingo',
      ]);
      expect(cache.offline, isTrue);
      expect(cache.staleSince!.toUtc(), _t0);
      expect(notified, [true]);
    },
  );

  test('the next good read clears the offline state', () async {
    await read(() async => ['Bingo']);
    await read(() async => throw TimeoutException('slow'));
    expect(cache.offline, isTrue);
    expect(await read(() async => ['Bingo', 'Mimi']), ['Bingo', 'Mimi']);
    expect(cache.offline, isFalse);
  });

  test(
    'with nothing saved the connection error is shown, not hidden',
    () async {
      await expectLater(
        read(() async => throw const SocketException('no route')),
        throwsA(isA<SocketException>()),
      );
      expect(cache.offline, isFalse);
    },
  );

  test('an answer from the server is never replaced by old data', () async {
    await read(() async => ['Bingo']);
    await expectLater(
      read(() async => throw StateError('row not found')),
      throwsA(isA<StateError>()),
    );
    expect(cache.offline, isFalse);
  });

  test('a damaged saved copy is ignored', () async {
    store.data['pawpass.cache.u1/pets'] = '{not json';
    await expectLater(
      read(() async => throw const SocketException('no route')),
      throwsA(isA<SocketException>()),
    );
  });

  test('a full disk does not break a read that worked', () async {
    final c = OfflineCache(_BrokenStore());
    final r = await c.fetch(
      key: 'k',
      load: () async => [1],
      parse: (j) => (j as List).length,
    );
    expect(r, 1);
  });

  test('each person has their own saved copy', () async {
    await cache.fetch(key: 'u1/pets', load: () async => ['A'], parse: (j) => j);
    await cache.fetch(key: 'u2/pets', load: () async => ['B'], parse: (j) => j);
    final got = await cache.fetch(
      key: 'u2/pets',
      load: () async => throw const SocketException('x'),
      parse: (j) => j,
    );
    expect(got, ['B']);
  });

  test('clearing forgets everything saved, and only our own keys', () async {
    await read(() async => ['Bingo']);
    store.data['something.else'] = 'keep';
    await read(() async => throw const SocketException('x'));
    expect(cache.offline, isTrue);
    await cache.clear();
    expect(store.data.keys, ['something.else']);
    expect(cache.offline, isFalse);
    await expectLater(
      read(() async => throw const SocketException('x')),
      throwsA(isA<SocketException>()),
    );
  });

  test('cachedRead without a cache is a plain read', () async {
    expect(
      await cachedRead(
        null,
        'k',
        () async => [1, 2],
        (j) => (j as List).length,
      ),
      2,
    );
  });

  test('what counts as a connection problem', () {
    expect(isNetworkError(const SocketException('x')), isTrue);
    expect(isNetworkError(const HttpException('x')), isTrue);
    expect(isNetworkError(TimeoutException('x')), isTrue);
    expect(isNetworkError(ClientException()), isTrue);
    expect(isNetworkError(StateError('x')), isFalse);
    expect(isNetworkError(Exception('x')), isFalse);
  });

  test('the saved-at wording', () {
    final saved = DateTime(2026, 11, 5, 9, 41);
    expect(savedAtLabel(saved, DateTime(2026, 11, 5, 20)), 'today at 9:41am');
    expect(
      savedAtLabel(DateTime(2026, 11, 3, 16, 5), DateTime(2026, 11, 5)),
      'on 3 Nov at 4:05pm',
    );
    expect(
      savedAtLabel(DateTime(2026, 11, 5, 0, 7), DateTime(2026, 11, 5)),
      'today at 12:07am',
    );
  });
}
