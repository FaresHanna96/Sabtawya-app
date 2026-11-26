/// A tapped phone or browser notification, as the push carried it.
class PushTap {
  const PushTap({
    this.notificationId,
    this.kind,
    this.refId,
    this.title = '',
    this.body = '',
  });

  /// The bell entry the push announced.
  final String? notificationId;

  /// Only on the pushes with no bell entry of their own (a sign-up, a
  /// decision).
  final String? kind;
  final String? refId;
  final String title;
  final String body;

  /// Reads a message's data, or null when there is nothing to route by.
  static PushTap? fromData(
    Map<String, dynamic> data, {
    String? title,
    String? body,
  }) {
    String? text(String key) {
      final value = data[key];
      return value is String && value.isNotEmpty ? value : null;
    }

    final id = text('notification_id');
    final kind = text('kind');
    if (id == null && kind == null) return null;
    return PushTap(
      notificationId: id,
      kind: kind,
      refId: text('ref_id'),
      title: title ?? text('title') ?? '',
      body: body ?? text('body') ?? '',
    );
  }
}
