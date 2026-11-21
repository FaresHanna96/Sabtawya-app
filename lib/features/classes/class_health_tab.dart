import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/widgets/app_widgets.dart';
import '../../core/widgets/async_section.dart';
import '../../data/models/class_health.dart';
import '../../data/repositories/report_repository.dart';
import '../../state/session_controller.dart';
import '../dashboard/class_health_section.dart';

/// The Classes tab's second page: متابعة الفصول (each class's health score),
/// moved off the home page so the home stays about today. أمين الخدمة and the general servant see every
/// class; a servant sees their own class(es) (the database decides).
class ClassHealthTab extends StatelessWidget {
  const ClassHealthTab({super.key, this.load, this.everyClass});

  /// The classes' health with their attendance joined in; defaults to the
  /// real reports for the current year. Tests give their own.
  final Future<List<ClassHealth>> Function()? load;

  /// Whether the title says "متابعة الفصول" (every class) or "متابعة فصلي";
  /// defaults to the signed-in role. Tests give their own.
  final bool? everyClass;

  static const _reports = ReportRepository();

  static Future<List<ClassHealth>> _loadReal(BuildContext context) async {
    final yearId = context.read<SessionController>().currentYear?.id;
    if (yearId == null) return const <ClassHealth>[];
    final (health, scores) = await (
      _reports.classHealth(yearId),
      _reports.classScores(yearId),
    ).wait;
    // The attendance % from the class scores is part of the health score.
    return ClassHealth.joinAttendance(health, {
      for (final s in scores) s.classId: s.percentage,
    });
  }

  @override
  Widget build(BuildContext context) {
    final everyClass = this.everyClass ??
        context.select<SessionController, bool>(
          (s) => s.isAdmin || s.isGeneralServant,
        );
    return AsyncSection<List<ClassHealth>>(
      load: load ?? () => _loadReal(context),
      builder: (context, classes, reload) {
        if (classes.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: const [
              SizedBox(height: 40),
              EmptyState(
                icon: Icons.monitor_heart_outlined,
                title: AppStrings.noClassHealth,
                body: AppStrings.noClassHealthBody,
              ),
            ],
          );
        }
        // A servant with one class gets its whole picture at once: a list
        // of one line would only be a tap in the way.
        if (!everyClass && classes.length == 1) {
          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
            child: SectionCard(
              title: AppStrings.myClassHealthTitle,
              icon: Icons.monitor_heart_outlined,
              accent: ClassHealthSection.colorOf(classes.single.level),
              child: ClassHealthDetail(health: classes.single),
            ),
          );
        }
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          child: ClassHealthSection(
            classes: classes,
            title: everyClass
                ? AppStrings.classHealthTitle
                : AppStrings.myClassHealthTitle,
            showChildren: true,
          ),
        );
      },
    );
  }
}
