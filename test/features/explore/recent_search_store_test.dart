import 'package:flutter_test/flutter_test.dart';
import 'package:virdanmobileapp/features/explore/data/recent_search_store.dart';

void main() {
  group('RecentSearches.updated', () {
    test('adds a new query to the front', () {
      final next = RecentSearches.updated(const [], 'coffee');
      expect(next, ['coffee']);
    });

    test('trims and ignores blanks', () {
      expect(RecentSearches.updated(const [], '   '), isEmpty);
      expect(RecentSearches.updated(const [], '  jakarta  '), ['jakarta']);
    });

    test('dedupes case-insensitively and moves the hit to the front', () {
      final next = RecentSearches.updated(const ['coffee', 'jakarta'], 'COFFEE');
      expect(next, ['COFFEE', 'jakarta']);
    });

    test('caps the list at 10, dropping the oldest', () {
      var list = <String>[];
      for (var i = 0; i < 12; i++) {
        list = RecentSearches.updated(list, 'q$i');
      }
      expect(list.length, 10);
      expect(list.first, 'q11');
      expect(list.contains('q0'), isFalse);
      expect(list.contains('q1'), isFalse);
    });

    test('removeAt drops one entry', () {
      final next = RecentSearches.removeOne(const ['a', 'b', 'c'], 'b');
      expect(next, ['a', 'c']);
    });
  });
}
