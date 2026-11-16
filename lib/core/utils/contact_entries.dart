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

/// One child's contact: the child's name and class, with the father's, the
/// mother's and the child's own numbers, each under its own label.
class ContactCard {
  const ContactCard(this.name, this.phones);

  final String name;

  /// (label, number): "الأب", "الأم", "المخدوم".
  final List<({String label, String number})> phones;
}

/// One contact per active child ("مينا جورج – فصل 5 بنات") holding the numbers
/// chosen, father first, then mother, then the child. A child with none of
/// the chosen numbers has no contact; a number the child repeats is kept once.
List<ContactCard> contactCardsFor(
  List<Child> children,
  Map<String, String> classNames, {
  bool child = true,
  bool mother = true,
  bool father = true,
}) {
  final cards = <ContactCard>[];
  for (final c in children) {
    if (!c.isActive) continue;
    final phones = <({String label, String number})>[];
    final seen = <String>{};
    void add(String label, String? raw) {
      final number = dialNumber(raw);
      if (number == null || !seen.add(numberKey(number))) return;
      phones.add((label: label, number: number));
    }

    if (father) add('الأب', c.fatherMobile);
    if (mother) add('الأم', c.motherMobile);
    if (child) add('المخدوم', c.mobile);
    if (phones.isEmpty) continue;

    final cls = classNames[c.classId];
    cards.add(ContactCard(
      '${c.fullName.trim()}${cls == null ? '' : ' – $cls'}',
      phones,
    ));
  }
  return cards;
}

/// A vCard 3.0 file (UTF-8) with one card per contact, each number carrying
/// its own label (الأب / الأم / المخدوم). Phones offer to add every card in it
/// as a contact.
String buildVCards(List<ContactCard> cards) {
  const eol = '\r\n';
  final out = StringBuffer();
  for (final card in cards) {
    final name = _escape(card.name);
    out
      ..write('BEGIN:VCARD$eol')
      ..write('VERSION:3.0$eol')
      ..write('FN;CHARSET=UTF-8:$name$eol')
      ..write('N;CHARSET=UTF-8:$name;;;;$eol');
    for (var i = 0; i < card.phones.length; i++) {
      final phone = card.phones[i];
      // "itemN." groups a number with its own label (iPhone and Android read
      // the label from X-ABLabel).
      out
        ..write('item${i + 1}.TEL;TYPE=CELL:${phone.number}$eol')
        ..write('item${i + 1}.X-ABLabel;CHARSET=UTF-8:'
            '${_escape(phone.label)}$eol');
    }
    out.write('END:VCARD$eol');
  }
  return out.toString();
}
