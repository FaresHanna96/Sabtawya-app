import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/app_theme.dart';
import '../../data/models/child.dart';
import '../../state/session_controller.dart';
import 'contact_cards.dart';

/// Call or WhatsApp the child, the mother or the father straight from a list,
/// without opening the profile first: the same rows as the top of the
/// profile, in a bottom sheet.
Future<void> showChildContactSheet(BuildContext context, Child child) {
  final servantName = context.read<SessionController>().displayName;
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              child.fullName,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.navy,
              ),
            ),
            const SizedBox(height: 12),
            ContactCards(
              people: ContactPerson.forChild(child),
              childName: child.fullName,
              servantName: servantName,
            ),
          ],
        ),
      ),
    ),
  );
}
