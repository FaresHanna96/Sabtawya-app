import 'package:url_launcher/url_launcher.dart';

import '../../data/models/child.dart';

/// Opens the phone's dialer on [number] (spaces around it are ignored).
Future<bool> callNumber(String number) =>
    launchUrl(Uri(scheme: 'tel', path: number.trim()));

/// The number to call for [child]: the child's own, else the mother's, else
/// the father's. Null when none of them has one. The same order as
/// `WhatsApp.numberFor`, so a call and a message reach the same person.
String? callNumberFor(Child? child) {
  if (child == null) return null;
  for (final n in [child.mobile, child.motherMobile, child.fatherMobile]) {
    final t = (n ?? '').trim();
    if (t.isNotEmpty) return t;
  }
  return null;
}
