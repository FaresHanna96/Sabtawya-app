import 'package:flutter/material.dart';
import '../../core/utils/phone.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/whatsapp.dart';
import '../../core/widgets/round_action_button.dart';
import '../../core/widgets/whatsapp_icon.dart';
import '../../data/models/child.dart';

/// One person to reach: who they are to the child (الأم، الأب، المخدوم) and
/// their number as it is stored.
class ContactPerson {
  const ContactPerson(this.label, this.number);

  final String label;
  final String number;

  /// The child, the mother and the father, each with a number; someone with
  /// no number is left out.
  static List<ContactPerson> forChild(Child child) {
    String? clean(String? v) => (v ?? '').trim().isEmpty ? null : v!.trim();
    return [
      if (clean(child.mobile) != null)
        ContactPerson(AppStrings.callChild, clean(child.mobile)!),
      if (clean(child.motherMobile) != null)
        ContactPerson(AppStrings.callMother, clean(child.motherMobile)!),
      if (clean(child.fatherMobile) != null)
        ContactPerson(AppStrings.callFather, clean(child.fatherMobile)!),
    ];
  }
}

/// The quick contacts at the top of a child's page: one card with a row per
/// person, the name and number on one side and two round buttons, call and
/// WhatsApp, on the other. The rows keep the same size on every phone, so the
/// buttons are always big enough for a thumb. A number WhatsApp cannot reach
/// (a landline) gets the call button alone; a person with no number has no
/// row.
class ContactCards extends StatelessWidget {
  const ContactCards({
    super.key,
    required this.people,
    required this.childName,
    required this.servantName,
  });

  final List<ContactPerson> people;
  final String childName;

  /// Who is writing, named in the first line of the WhatsApp message.
  final String servantName;

  @override
  Widget build(BuildContext context) {
    if (people.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
        boxShadow: [
          BoxShadow(
            color: AppColors.navy.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          for (var i = 0; i < people.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                color: AppColors.navy.withValues(alpha: 0.07),
              ),
            _ContactRow(
              person: people[i],
              childName: childName,
              servantName: servantName,
            ),
          ],
        ],
      ),
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({
    required this.person,
    required this.childName,
    required this.servantName,
  });

  final ContactPerson person;
  final String childName;
  final String servantName;

  @override
  Widget build(BuildContext context) {
    final chat = WhatsApp.normalise(person.number);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  person.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.navy,
                  ),
                ),
                const SizedBox(height: 2),
                // A number reads left to right, whatever the page direction.
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    person.number,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.muted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (chat != null) ...[
            RoundActionButton(
              tooltip: AppStrings.whatsappTo(person.label),
              color: WhatsAppIcon.green,
              onTap: () => launchUrl(
                WhatsApp.link(
                  chat,
                  WhatsApp.greeting(
                    childName: childName,
                    servantName: servantName,
                  ),
                ),
                mode: LaunchMode.externalApplication,
              ),
              child: const WhatsAppIcon(size: 26),
            ),
            const SizedBox(width: 10),
          ],
          RoundActionButton(
            tooltip: '${AppStrings.call}: ${person.label}',
            color: AppColors.success,
            onTap: () =>
                callNumber(person.number.trim()),
            child: const Icon(Icons.call_rounded,
                size: 24, color: AppColors.success),
          ),
        ],
      ),
    );
  }
}
