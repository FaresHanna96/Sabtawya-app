import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/ui.dart';
import '../../core/utils/whatsapp.dart';
import '../../data/models/child.dart';
import 'asked_log.dart';
import 'missing_info.dart';

/// Opens WhatsApp with the ready message asking a child's family for what
/// their record is missing (only those fields are named). A family asked in
/// the last week is asked about first, so the same people are not written to
/// twice. Returns true when WhatsApp was opened.
Future<bool> askFamilyOnWhatsApp(
  BuildContext context,
  Child child, {
  required String servantName,
  AskedLog? log,
  DateTime? now,
  Future<bool> Function(Uri uri)? launch,
}) async {
  final number = WhatsApp.numberFor(child);
  final missing = MissingInfo.of(child);
  if (number == null || missing.isEmpty) return false;

  final asks = log ?? AskedLog.instance;
  final today = now ?? DateTime.now();
  final before = await asks.when(child.id);
  if (!context.mounted) return false;
  if (AskedLog.isRecent(before, today)) {
    final again = await Ui.confirm(
      context,
      title: AppStrings.askedAlready(AskedLog.daysAgo(before, today)!),
      message: AppStrings.askAgainQuestion,
      confirmLabel: AppStrings.askAgain,
    );
    if (!again) return false;
  }

  final uri = WhatsApp.link(
    number,
    WhatsApp.missingInfoMessage(
      childName: child.fullName,
      servantName: servantName,
      missing: [for (final f in missing) f.label],
    ),
  );
  final opened = await (launch ??
      (u) => launchUrl(u, mode: LaunchMode.externalApplication))(uri);
  if (opened) await asks.mark(child.id, at: today);
  return opened;
}
