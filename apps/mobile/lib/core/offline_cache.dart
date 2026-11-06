import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Somewhere small to keep text on the phone.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> remove(String key);
  Future<List<String>> keys();
}

class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> data = {};

  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> remove(String key) async => data.remove(key);
  @override
  Future<List<String>> keys() async => data.keys.toList();
}

/// The phone's own preferences store (a small private file; not shared with other apps).
class PrefsKeyValueStore implements KeyValueStore {
  Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  @override
  Future<String?> read(String key) async => (await _p).getString(key);
  @override
  Future<void> write(String key, String value) async {
    await (await _p).setString(key, value);
  }

  @override
  Future<void> remove(String key) async {
    await (await _p).remove(key);
  }

  @override
  Future<List<String>> keys() async => (await _p).getKeys().toList();
}

/// True when the trouble is the phone's connection, not an answer from our server. A server that answered
/// (a rule broken, a row not found) is never hidden behind old data.
bool isNetworkError(Object e) {
  if (e is SocketException || e is HttpException || e is TimeoutException) {
    return true;
  }
  final name = e.runtimeType.toString();
  return name == 'ClientException' ||
      name == 'AuthRetryableFetchException' ||
      name == 'HandshakeException' ||
      name == 'TlsException';
}

/// Keeps the last good answer to a few reads (profile, pets, the passport, reminders) so they still open with no
/// signal. Reads try the network first; only a connection failure falls back to what was saved, and then
/// [staleSince] says when it was saved so screens can say "you are offline". Writes are never cached or queued:
/// they fail with a clear message instead, so nothing is ever silently lost or sent twice.
class OfflineCache extends ChangeNotifier {
  OfflineCache(this._store, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  static const prefix = 'pawpass.cache.';

  final KeyValueStore _store;
  final DateTime Function() _now;

  /// When the data on screen was saved, if the latest read had to use saved data. Null when it was fresh.
  DateTime? staleSince;

  bool get offline => staleSince != null;

  /// Reads [key] from the network with [load] and keeps the answer. If there is no connection, returns the saved
  /// answer instead. If there is nothing saved, the original error is rethrown. [parse] turns the JSON into the
  /// type the app uses.
  Future<T> fetch<T>({
    required String key,
    required Future<Object?> Function() load,
    required T Function(Object? json) parse,
  }) async {
    final Object? fresh;
    try {
      fresh = await load();
    } catch (e) {
      if (!isNetworkError(e)) {
        rethrow;
      }
      final saved = await _saved(key);
      if (saved == null) {
        rethrow;
      }
      _setStale(saved.at);
      return parse(saved.data);
    }
    // Saving is best effort: a full disk must not break a read that worked.
    try {
      await _store.write(
        '$prefix$key',
        jsonEncode({'at': _now().toUtc().toIso8601String(), 'data': fresh}),
      );
    } catch (_) {}
    _setStale(null);
    return parse(fresh);
  }

  Future<({DateTime at, Object? data})?> _saved(String key) async {
    try {
      final raw = await _store.read('$prefix$key');
      if (raw == null) {
        return null;
      }
      final m = jsonDecode(raw) as Map<String, dynamic>;
      final at = DateTime.tryParse(m['at'] as String? ?? '');
      return at == null ? null : (at: at.toLocal(), data: m['data']);
    } catch (_) {
      return null;
    }
  }

  void _setStale(DateTime? at) {
    if (staleSince == at) {
      return;
    }
    staleSince = at;
    notifyListeners();
  }

  /// Forgets everything saved (on sign out, so the next person never sees it).
  Future<void> clear() async {
    for (final k in await _store.keys()) {
      if (k.startsWith(prefix)) {
        await _store.remove(k);
      }
    }
    _setStale(null);
  }
}

/// [OfflineCache.fetch] when there is a cache, a plain read when there is not.
Future<T> cachedRead<T>(
  OfflineCache? cache,
  String key,
  Future<Object?> Function() load,
  T Function(Object? json) parse,
) async {
  if (cache == null) {
    return parse(await load());
  }
  return cache.fetch(key: key, load: load, parse: parse);
}
