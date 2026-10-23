import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Keeps the French translation complete: every English string must exist in
/// French with the same placeholders, and nothing may be left empty.
void main() {
  Map<String, dynamic> load(String locale) =>
      jsonDecode(File('lib/l10n/app_$locale.arb').readAsStringSync()) as Map<String, dynamic>;

  Iterable<String> messageKeys(Map<String, dynamic> arb) => arb.keys.where((k) => !k.startsWith('@'));

  Set<String> placeholders(String message) =>
      RegExp(r'\{(\w+)[},]').allMatches(message).map((m) => m.group(1)!).toSet()..remove('count');

  final en = load('en');
  final fr = load('fr');

  test('French has every English string', () {
    final missing = messageKeys(en).where((k) => !fr.containsKey(k)).toList();
    expect(missing, isEmpty, reason: 'Missing in app_fr.arb');
  });

  test('French has no strings English lacks', () {
    final extra = messageKeys(fr).where((k) => !en.containsKey(k)).toList();
    expect(extra, isEmpty, reason: 'Only in app_fr.arb');
  });

  test('placeholders match and no string is empty', () {
    for (final key in messageKeys(en)) {
      final english = en[key] as String;
      final french = fr[key] as String;
      expect(french.trim(), isNotEmpty, reason: key);
      expect(placeholders(french), placeholders(english), reason: key);
    }
  });
}
