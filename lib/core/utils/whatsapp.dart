import '../../data/models/child.dart';

/// WhatsApp links for the follow-up lists: which number to use, the number in
/// the international form WhatsApp wants, and the first line of the message
/// (the servant can edit it in WhatsApp before sending).
class WhatsApp {
  const WhatsApp._();

  /// [raw] as WhatsApp's `wa.me` expects it: country code and number, digits
  /// only. Egyptian numbers as people write them (`010...`, `+2010...`,
  /// `002010...`, `10...` with the 0 lost in Excel) all become `2010...`.
  /// Null when it cannot be a mobile number.
  static String? normalise(String? raw) {
    if (raw == null) return null;
    final latin = _arabicDigitsToLatin(raw.trim());
    final plus = latin.startsWith('+');
    var digits = latin.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return null;

    if (plus) {
      // already international
    } else if (digits.startsWith('00')) {
      digits = digits.substring(2);
    } else if (digits.startsWith('0')) {
      digits = '20${digits.substring(1)}';
    } else if (digits.length == 10 && digits.startsWith('1')) {
      digits = '20$digits';
    }

    // An Egyptian number is 20 + a 10-digit mobile starting with 1; anything
    // else international is taken as it is, within the length WhatsApp allows.
    if (digits.startsWith('20')) {
      final rest = digits.substring(2);
      if (rest.length != 10 || !rest.startsWith('1')) return null;
      return digits;
    }
    if (digits.length < 8 || digits.length > 15) return null;
    return digits;
  }

  /// The number to write to: the mother's, else the father's, else the
  /// child's own. Null when none of them is a usable mobile number.
  static String? numberFor(Child? child) {
    if (child == null) return null;
    for (final n in [child.motherMobile, child.fatherMobile, child.mobile]) {
      final normal = normalise(n);
      if (normal != null) return normal;
    }
    return null;
  }

  /// `https://wa.me/<number>?text=<message>`; with no message, just the chat.
  static Uri link(String number, [String message = '']) => Uri.https(
        'wa.me',
        '/$number',
        message.isEmpty ? null : <String, String>{'text': message},
      );

  /// A first line for a chat opened from a child's page.
  static String greeting({
    required String childName,
    required String servantName,
  }) {
    final who = servantName.trim().isEmpty ? 'خادم الفصل' : servantName.trim();
    return 'سلام ونعمة، معاك $who من خدمة السبت بخصوص ${childName.trim()}.';
  }

  /// The ready message for a child who has been absent [absent] Saturdays.
  static String absenceMessage({
    required String childName,
    required String servantName,
    required int absent,
  }) {
    final when = absent <= 1
        ? 'السبت اللي فات'
        : absent == 2
            ? 'آخر سبتين'
            : 'آخر $absent سبوت';
    final who = servantName.trim().isEmpty ? 'خادم الفصل' : servantName.trim();
    return 'سلام ونعمة، معاك $who من خدمة السبت. '
        'افتقدنا ${childName.trim()} $when ونتمنى نطمّن عليه ونشوفه قريب. '
        'ربنا يحافظ عليكم.';
  }

  static String _arabicDigitsToLatin(String s) {
    const arabic = '٠١٢٣٤٥٦٧٨٩';
    const persian = '۰۱۲۳۴۵۶۷۸۹';
    final out = StringBuffer();
    for (final rune in s.runes) {
      final c = String.fromCharCode(rune);
      final a = arabic.indexOf(c);
      final p = persian.indexOf(c);
      out.write(a >= 0 ? '$a' : (p >= 0 ? '$p' : c));
    }
    return out.toString();
  }
}
