import 'dart:ui' show Color;

import 'app_theme.dart';

/// The accent colours a class can take.
const classPalette = <Color>[
  AppColors.navyLight,
  AppColors.olive,
  AppColors.coral,
  AppColors.gold,
  AppColors.sky,
  AppColors.maroon,
];

/// A class keeps its colour whatever else is listed (archived classes shown
/// or not): it comes from the class id, not from the row it sits on.
Color classAccent(String classId) =>
    classPalette[classColourIndex(classId, classPalette.length)];

/// A stable index in 0..[count) for [classId] (the same on every run).
int classColourIndex(String classId, int count) {
  var h = 0;
  for (final c in classId.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return h % count;
}
