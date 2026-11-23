import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Every IconButton in the app has a tooltip: it is what a screen reader
/// says for a button that shows only an icon, and what a long press shows.
void main() {
  test('every IconButton has a tooltip', () {
    final missing = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    // IconButton( and its .filled / .filledTonal / .outlined forms, not the
    // IconButton.styleFrom( helper.
    final start = RegExp(r'IconButton(\.(?!styleFrom)\w+)?\(');
    for (final file in files) {
      final src = file.readAsStringSync();
      for (final m in start.allMatches(src)) {
        // The call's own arguments: up to its matching parenthesis.
        var depth = 1;
        var i = m.end;
        while (depth > 0 && i < src.length) {
          final c = src[i];
          if (c == '(') depth++;
          if (c == ')') depth--;
          i++;
        }
        if (!src.substring(m.start, i).contains('tooltip')) {
          final line = '\n'.allMatches(src.substring(0, m.start)).length + 1;
          missing.add('${file.path}:$line');
        }
      }
    }
    expect(missing, isEmpty, reason: 'IconButton without a tooltip');
  });
}
