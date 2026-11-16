import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';

/// A WhatsApp button for a birthday: opens a chat with a ready greeting (the
/// servant can edit it in WhatsApp). It writes to the person's own number; for
/// a child with none it writes to the mother, then the father, and the
/// greeting is then about the child. With no number that WhatsApp can reach it
/// shows nothing.
class BirthdayWhatsAppButton extends StatelessWidget {
  const BirthdayWhatsAppButton({
    super.key,
    required this.name,
    required this.servantName,
    this.ownMobile,
    this.child,
    this.girl = false,
    this.compact = false,
  });

  final String name;

  /// Who is writing (the signed-in servant), named in the greeting.
  final String servantName;
  final String? ownMobile;

  /// The child record, for a parent's number when the child has none.
  final Child? child;
  final bool girl;

  /// The smaller button of the home page's rows.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final target = WhatsApp.birthdayTarget(ownMobile: ownMobile, child: child);
    if (target == null) return const SizedBox.shrink();
    return IconButton(
      tooltip: AppStrings.whatsappBirthday,
      icon: WhatsAppIcon(size: compact ? 18 : 20),
      padding: compact ? EdgeInsets.zero : null,
      constraints:
          compact ? const BoxConstraints(minWidth: 32, minHeight: 32) : null,
      onPressed: () => launchUrl(
        WhatsApp.link(
          target.number,
          WhatsApp.birthdayMessage(
            name: name,
            servantName: servantName,
            toThePerson: target.toThePerson,
            girl: girl,
          ),
        ),
        mode: LaunchMode.externalApplication,
      ),
    );
  }
}
