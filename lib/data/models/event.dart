import 'parsers.dart';

class Event {
  const Event({
    required this.id,
    required this.title,
    required this.eventDate,
    required this.cost,
    required this.createdBy,
    required this.createdAt,
    this.description,
    this.yearId,
  });

  final String id;
  final String title;
  final String? description;
  final DateTime eventDate;
  final double cost;
  final String? yearId;
  final String createdBy;
  final DateTime createdAt;

  factory Event.fromMap(Map<String, dynamic> map) => Event(
        id: asText(map['id']),
        title: asText(map['title']),
        description: asTextOrNull(map['description']),
        eventDate: asDate(map['event_date']),
        cost: asDouble(map['cost']),
        yearId: asTextOrNull(map['year_id']),
        createdBy: asText(map['created_by']),
        createdAt: asDate(map['created_at']),
      );

  Event copyWith({
    String? title,
    String? description,
    DateTime? eventDate,
    double? cost,
    String? yearId,
  }) =>
      Event(
        id: id,
        title: title ?? this.title,
        description: description ?? this.description,
        eventDate: eventDate ?? this.eventDate,
        cost: cost ?? this.cost,
        yearId: yearId ?? this.yearId,
        createdBy: createdBy,
        createdAt: createdAt,
      );
}

class EventPayment {
  const EventPayment({
    required this.id,
    required this.eventId,
    required this.childId,
    required this.amount,
    required this.paidBy,
    required this.paidAt,
    this.notes,
    this.paymentMethod = 'cash',
  });

  final String id;
  final String eventId;
  final String childId;
  final double amount;
  final String paidBy;
  final DateTime paidAt;
  final String? notes;
  final String paymentMethod;

  bool get isTayo => paymentMethod == 'tayo';

  factory EventPayment.fromMap(Map<String, dynamic> map) => EventPayment(
        id: asText(map['id']),
        eventId: asText(map['event_id']),
        childId: asText(map['child_id']),
        amount: asDouble(map['amount']),
        paidBy: asText(map['paid_by']),
        paidAt: asDate(map['paid_at']),
        notes: asTextOrNull(map['notes']),
        paymentMethod: asTextOrNull(map['payment_method']) ?? 'cash',
      );
}

class ChildEventBalance {
  const ChildEventBalance({
    required this.eventId,
    required this.childId,
    required this.childName,
    required this.classId,
    required this.cost,
    required this.totalPaid,
    required this.remaining,
    this.reserved = false,
  });

  final String eventId;
  final String childId;
  final String childName;
  final String classId;
  final double cost;
  final double totalPaid;
  final double remaining;

  /// Booked a place without paying yet ("حجز بدون دفع").
  final bool reserved;

  factory ChildEventBalance.fromMap(Map<String, dynamic> map) =>
      ChildEventBalance(
        eventId: asText(map['event_id']),
        childId: asText(map['child_id']),
        childName: asText(map['child_name']),
        classId: asText(map['class_id']),
        cost: asDouble(map['cost']),
        totalPaid: asDouble(map['total_paid']),
        remaining: asDouble(map['remaining']),
        reserved: map['reserved'] == true,
      );
}
