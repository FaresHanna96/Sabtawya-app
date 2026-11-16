import '../../data/models/child.dart';
import 'whatsapp.dart';

/// One phone number and the name to show for it: "أم مينا جورج – فصل 5 بنات".
class ContactEntry {
  const ContactEntry(this.label, this.number);

  final String label;

  /// Dialable, with a leading `+` for an international number.
  final String number;
}

/// [raw] as a dialable number: an Egyptian mobile becomes `+20…`, any other
/// number keeps its digits. Null when it is too short to be a number.
String? dialNumber(String? raw) {
  final mobile = WhatsApp.normalise(raw);
  if (mobile != null) return '+$mobile';
  final digits = (raw ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  final count = digits.replaceAll('+', '').length;
  return count >= 6 && count <= 15 ? digits : null;
}

/// What an incoming number is compared by: its last ten digits, so `0101…`,
/// `+20101…` and `0020101…` are the same number.
String numberKey(String number) {
  final digits = number.replaceAll(RegExp(r'[^0-9]'), '');
  return digits.length <= 10 ? digits : digits.substring(digits.length - 10);
}

/// The people to save: for each active child their mother, their father and
/// the child (as chosen), each under a name that says whose family it is.
/// A number two children share (siblings, one mother) becomes one entry named
/// after both.
List<ContactEntry> contactEntriesFor(
  List<Child> children,
  Map<String, String> classNames, {
  bool child = true,
  bool mother = true,
  bool father = true,
}) {
  final byKey = <String, ({String number, List<String> labels})>{};

  void add(String who, Child c, String? raw) {
    final number = dialNumber(raw);
    if (number == null) return;
    final cls = classNames[c.classId];
    final label = '$who ${c.fullName.trim()}${cls == null ? '' : ' – $cls'}';
    final key = numberKey(number);
    final known = byKey[key];
    if (known == null) {
      byKey[key] = (number: number, labels: [label]);
    } else if (!known.labels.contains(label)) {
      known.labels.add(label);
    }
  }

  for (final c in children) {
    if (!c.isActive) continue;
    if (mother) add('أم', c, c.motherMobile);
    if (father) add('أب', c, c.fatherMobile);
    if (child) add('المخدوم', c, c.mobile);
  }
  return [
    for (final e in byKey.values) ContactEntry(e.labels.join(' / '), e.number),
  ];
}

String _escape(String v) => v
    .replaceAll(r'\', r'\\')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,')
    .replaceAll(RegExp(r'\r?\n'), r'\n');

/// A vCard 3.0 file (UTF-8) with one card per entry. Phones offer to add
/// every card in it as a contact.
String buildVCards(List<ContactEntry> entries) {
  final out = StringBuffer();
  for (final e in entries) {
    final name = _escape(e.label);
    out
      ..write('BEGIN:VCARD\r\n')
      ..write('VERSION:3.0\r\n')
      ..write('FN;CHARSET=UTF-8:$name\r\n')
      ..write('N;CHARSET=UTF-8:$name;;;;\r\n')
      ..write('TEL;TYPE=CELL:${e.number}\r\n')
      ..write('END:VCARD\r\n');
  }
  return out.toString();
}
