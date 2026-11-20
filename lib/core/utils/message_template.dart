import '../../data/models/child.dart';
import 'whatsapp.dart';

/// A message for the families: built into the app, or written by أمين الخدمة
/// (saved in `message_templates`). Its body may hold the placeholders below.
class MessageTemplate {
  const MessageTemplate({
    required this.title,
    required this.body,
    this.id,
    this.sortOrder = 0,
    this.eventOnly = false,
  });

  /// Null for a built-in template.
  final String? id;
  final String title;
  final String body;
  final int sortOrder;

  /// Offered only when messaging an event's children (it names the event or
  /// the amount still owed).
  final bool eventOnly;

  bool get isBuiltIn => id == null;

  factory MessageTemplate.fromMap(Map<String, dynamic> map) => MessageTemplate(
        id: '${map['id']}',
        title: '${map['title'] ?? ''}',
        body: '${map['body'] ?? ''}',
        sortOrder: (map['sort_order'] as num?)?.toInt() ?? 0,
      );
}

/// The child's first name (two or more: "مينا ومريم").
const kChildTag = '{الطفل}';

/// The servant sending it.
const kServantTag = '{الخادم}';

/// The child's class.
const kClassTag = '{الفصل}';

/// The event's title (event messages only).
const kEventTag = '{المناسبة}';

/// What is still owed for the event (event messages only).
const kRemainingTag = '{المتبقي}';

const kMessageTags = <String>[
  kChildTag,
  kServantTag,
  kClassTag,
  kEventTag,
  kRemainingTag,
];

const kEventReminderTitle = 'تذكير بالمناسبة';
const kPaymentReminderTitle = 'تذكير بالدفع';

/// The templates every servant has, before any the admin adds.
const kBuiltInTemplates = <MessageTemplate>[
  MessageTemplate(
    title: 'افتقدناكم',
    body: 'سلام ونعمة، معاك $kServantTag من خدمة السبت ($kClassTag). '
        'افتقدنا $kChildTag في الخدمة ونتمنى نشوفه السبت الجاي. '
        'ربنا يحافظ عليكم.',
  ),
  MessageTemplate(
    title: 'تذكير بالسبت',
    body: 'سلام ونعمة، معاك $kServantTag من خدمة السبت. '
        'بنفكّركم إن الخدمة بكرة إن شاء الله، ومستنيين $kChildTag معانا. '
        'ربنا يبارككم.',
  ),
  MessageTemplate(
    title: kEventReminderTitle,
    eventOnly: true,
    body: 'سلام ونعمة، معاك $kServantTag من خدمة السبت. '
        'بنفكّركم بـ $kEventTag، ومستنيين $kChildTag معانا. '
        'لو فيه أي سؤال كلّمونا. ربنا يبارككم.',
  ),
  MessageTemplate(
    title: kPaymentReminderTitle,
    eventOnly: true,
    body: 'سلام ونعمة، معاك $kServantTag من خدمة السبت. '
        'بالنسبة لـ $kEventTag، باقي على $kChildTag مبلغ $kRemainingTag. '
        'ممكن تسلّموه للخادم السبت الجاي. شكرًا ليكم.',
  ),
];

/// One WhatsApp chat to open: a family number and the children it is about
/// (brothers and sisters who share the number get one message naming both).
class FamilyMessage {
  const FamilyMessage({
    required this.number,
    required this.children,
    required this.text,
  });

  /// `wa.me` form (country code, digits only).
  final String number;
  final List<Child> children;
  final String text;

  /// Stable id for the "sent" tick: the number.
  String get key => number;

  Uri get link => WhatsApp.link(number, text);
}

/// Fills templates and groups the children into the chats to open.
class ParentMessages {
  const ParentMessages._();

  /// "مينا" / "مينا ومريم" / "مينا وجورج ومريم".
  static String firstNames(List<Child> children) {
    final names = [
      for (final c in children) c.fullName.trim().split(RegExp(r'\s+')).first,
    ];
    if (names.isEmpty) return '';
    if (names.length == 1) return names.first;
    return '${names.sublist(0, names.length - 1).join(' و')} و${names.last}';
  }

  /// "150 جنيه" (no decimals for a whole amount).
  static String money(double amount) {
    final whole = amount == amount.roundToDouble();
    return '${whole ? amount.toStringAsFixed(0) : amount.toStringAsFixed(2)} جنيه';
  }

  /// [body] with every placeholder replaced. A value that is not known here
  /// (an event tag outside an event) becomes empty rather than staying as a
  /// raw tag in the parent's chat.
  static String fill(
    String body, {
    required List<Child> children,
    required String servantName,
    String className = '',
    String eventTitle = '',
    double? remaining,
  }) {
    final servant =
        servantName.trim().isEmpty ? 'خادم الفصل' : servantName.trim();
    return body
        .replaceAll(kChildTag, firstNames(children))
        .replaceAll(kServantTag, servant)
        .replaceAll(kClassTag, className.trim())
        .replaceAll(kEventTag, eventTitle.trim())
        .replaceAll(kRemainingTag, remaining == null ? '' : money(remaining))
        .replaceAll(RegExp(r' {2,}'), ' ')
        .replaceAll(' ()', '')
        .trim();
  }

  /// The chats to open for [children] with [body]: one per WhatsApp number
  /// (the mother's, else the father's, else the child's own), in the order the
  /// children came. Children with no usable number are returned apart.
  static ({List<FamilyMessage> families, List<Child> noNumber}) build(
    List<Child> children, {
    required String body,
    required String servantName,
    Map<String, String> classNames = const <String, String>{},
    String eventTitle = '',
    Map<String, double> remainingByChild = const <String, double>{},
  }) {
    final groups = <String, List<Child>>{};
    final noNumber = <Child>[];
    for (final c in children) {
      final number = WhatsApp.numberFor(c);
      if (number == null) {
        noNumber.add(c);
      } else {
        (groups[number] ??= <Child>[]).add(c);
      }
    }

    final families = [
      for (final entry in groups.entries)
        FamilyMessage(
          number: entry.key,
          children: entry.value,
          text: fill(
            body,
            children: entry.value,
            servantName: servantName,
            className: classNames[entry.value.first.classId] ?? '',
            eventTitle: eventTitle,
            remaining: _sum(entry.value, remainingByChild),
          ),
        ),
    ];
    return (families: families, noNumber: noNumber);
  }

  static double? _sum(List<Child> children, Map<String, double> amounts) {
    if (amounts.isEmpty) return null;
    var total = 0.0;
    var any = false;
    for (final c in children) {
      final a = amounts[c.id];
      if (a != null) {
        total += a;
        any = true;
      }
    }
    return any ? total : null;
  }
}
