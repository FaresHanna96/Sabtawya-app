import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabtawya/core/theme/app_theme.dart';

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  double lum(Color c) {
    double ch(double v) =>
        v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
    return 0.2126 * ch(c.r) + 0.7152 * ch(c.g) + 0.0722 * ch(c.b);
  }

  final (la, lb) = (lum(a), lum(b));
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}

/// [c] at [alpha] over white, as the tinted chips paint it.
Color _overWhite(Color c, double alpha) =>
    Color.alphaBlend(c.withValues(alpha: alpha), Colors.white);

void main() {
  const cream = Color(0xFFFFF8EC);
  final pairs = {
    AppColors.gold: AppColors.goldText,
    AppColors.coral: AppColors.coralText,
    AppColors.sky: AppColors.skyText,
    AppColors.olive: AppColors.oliveText,
    AppColors.warning: AppColors.warningText,
  };

  group('text shades read at AA (4.5:1)', () {
    for (final MapEntry(key: brand, value: text) in pairs.entries) {
      test('$text', () {
        expect(_contrast(text, Colors.white), greaterThanOrEqualTo(4.5));
        expect(_contrast(text, AppColors.surface), greaterThanOrEqualTo(4.5));
        expect(_contrast(text, cream), greaterThanOrEqualTo(4.5));
        // On its own light chip (the tints the app uses, 8–20%).
        for (final a in [0.08, 0.10, 0.12, 0.14, 0.20]) {
          expect(_contrast(text, _overWhite(brand, a)),
              greaterThanOrEqualTo(4.5),
              reason: 'on a $a tint');
        }
      });
    }
  });

  test('the brand colours themselves were too light for text', () {
    for (final brand in pairs.keys) {
      expect(_contrast(brand, Colors.white), lessThan(4.5));
    }
  });

  group('AppColors.readable', () {
    test('swaps the light brand colours for their text shade', () {
      pairs.forEach((brand, text) {
        expect(AppColors.readable(brand), text);
      });
    });

    test('leaves colours that already read well', () {
      for (final c in [
        AppColors.navy,
        AppColors.maroon,
        AppColors.success,
        AppColors.danger,
        AppColors.muted,
        Colors.white,
      ]) {
        expect(AppColors.readable(c), c);
        if (c != Colors.white) {
          expect(_contrast(c, Colors.white), greaterThanOrEqualTo(4.5));
        }
      }
    });
  });
}
