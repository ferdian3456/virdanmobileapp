import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Pure list transforms for recent searches — kept separate from I/O so they
/// can be unit-tested without a storage backend.
abstract final class RecentSearches {
  static const max = 10;

  /// Returns a new list with [raw] (trimmed) moved/inserted at the front,
  /// case-insensitively de-duplicated, capped at [max]. Blank input is a no-op.
  static List<String> updated(List<String> current, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return List<String>.from(current);
    final lower = value.toLowerCase();
    final next = <String>[value];
    for (final item in current) {
      if (item.toLowerCase() == lower) continue;
      next.add(item);
      if (next.length >= max) break;
    }
    return next;
  }

  /// Returns a new list without [value] (exact match).
  static List<String> removeOne(List<String> current, String value) {
    return current.where((e) => e != value).toList(growable: false);
  }
}

/// Persists recent post-search queries on-device. Reuses flutter_secure_storage
/// (already a dependency) to avoid adding shared_preferences. Search history is
/// non-sensitive; encryption is a harmless bonus.
class RecentSearchStore {
  RecentSearchStore(this._storage);

  final FlutterSecureStorage _storage;
  static const _key = 'recent_post_searches';

  Future<List<String>> load() async {
    final raw = await _storage.read(key: _key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw) as List<dynamic>;
      return decoded.whereType<String>().toList(growable: false);
    } catch (_) {
      // Corrupt payload — reset rather than crash the search view.
      await _storage.delete(key: _key);
      return const [];
    }
  }

  Future<List<String>> add(String query) async {
    final next = RecentSearches.updated(await load(), query);
    await _persist(next);
    return next;
  }

  Future<List<String>> removeOne(String query) async {
    final next = RecentSearches.removeOne(await load(), query);
    await _persist(next);
    return next;
  }

  Future<void> clear() => _storage.delete(key: _key);

  Future<void> _persist(List<String> list) =>
      _storage.write(key: _key, value: jsonEncode(list));
}

final recentSearchStoreProvider = Provider<RecentSearchStore>((ref) {
  return RecentSearchStore(
    const FlutterSecureStorage(
      iOptions: IOSOptions(
        accessibility: KeychainAccessibility.first_unlock_this_device,
      ),
    ),
  );
});
