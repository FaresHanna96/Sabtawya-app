import '../../core/utils/app_failure.dart';
import '../models/event.dart';
import '../supabase/db.dart';

class EventRepository {
  const EventRepository();

  Future<List<Event>> listEvents() async {
    try {
      final data = await Db.client
          .from(Db.tEvents)
          .select()
          .order('event_date', ascending: false);
      return rows(data).map(Event.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Event> createEvent({
    required String title,
    required DateTime eventDate,
    required double cost,
    String? description,
    String? yearId,
  }) async {
    try {
      final userId = Db.userId;
      if (userId == null) throw AppFailure('لم يتم التحقق من الهوية');
      final data = await Db.client
          .from(Db.tEvents)
          .insert({
            'title': title.trim(),
            'event_date': eventDate.toIso8601String().split('T').first,
            'cost': cost,
            if (description != null && description.trim().isNotEmpty)
              'description': description.trim(),
            if (yearId != null) 'year_id': yearId,
            'created_by': userId,
          })
          .select()
          .single();
      return Event.fromMap(data);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> updateEvent(
    String id, {
    String? title,
    DateTime? eventDate,
    double? cost,
    String? description,
  }) async {
    try {
      final patch = <String, dynamic>{
        if (title != null) 'title': title.trim(),
        if (eventDate != null)
          'event_date': eventDate.toIso8601String().split('T').first,
        if (cost != null) 'cost': cost,
        if (description != null)
          'description': description.trim().isEmpty ? null : description.trim(),
      };
      await Db.client.from(Db.tEvents).update(patch).eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deleteEvent(String id) async {
    try {
      await Db.client.from(Db.tEvents).delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Balances for all (active) children in this event.
  /// RLS restricts a regular servant to only their assigned class children.
  Future<List<ChildEventBalance>> balances(String eventId) async {
    try {
      final data = await Db.client
          .from(Db.vChildEventBalances)
          .select()
          .eq('event_id', eventId)
          .order('child_name');
      return rows(data).map(ChildEventBalance.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Payment history for one child in one event, newest first.
  Future<List<EventPayment>> payments(String eventId, String childId) async {
    try {
      final data = await Db.client
          .from(Db.tEventPayments)
          .select()
          .eq('event_id', eventId)
          .eq('child_id', childId)
          .order('paid_at', ascending: false);
      return rows(data).map(EventPayment.fromMap).toList();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> addPayment(
    String eventId,
    String childId,
    double amount, {
    String? notes,
    String paymentMethod = 'cash',
  }) async {
    try {
      final userId = Db.userId;
      if (userId == null) throw AppFailure('لم يتم التحقق من الهوية');
      await Db.client.from(Db.tEventPayments).insert({
        'event_id': eventId,
        'child_id': childId,
        'amount': amount,
        'paid_by': userId,
        'paid_at': DateTime.now().toIso8601String(),
        'payment_method': paymentMethod,
        if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> deletePayment(String paymentId) async {
    try {
      await Db.client.from(Db.tEventPayments).delete().eq('id', paymentId);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }
}
