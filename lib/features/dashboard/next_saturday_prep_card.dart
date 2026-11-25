import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/app_date_utils.dart';
import '../../data/models/lesson.dart';
import '../../data/repositories/lesson_repository.dart';
import '../../data/repositories/servant_activity_repository.dart';
import '../../state/session_controller.dart';
import '../lessons/lesson_widgets.dart';

/// One class on the card: its name and whether its prep was sent.
typedef PrepClass = ({String id, String name});

/// «السبت الجاي» in one card: the date once, the lesson to prepare (folded
/// behind a tap when there is one), and how many classes have sent their prep
/// (a bar, with the classes behind a tap). It replaces two cards that each
/// began with the same date.
class NextSaturdayCard extends StatefulWidget {
  const NextSaturdayCard({
    super.key,
    required this.dateLabel,
    this.lesson,
    this.hasLesson = false,
    this.lessonCount = 0,
    this.lessonOpen = true,
    this.classes = const [],
    this.prepared = const {},
  });

  /// "السبت، 28 نوفمبر 2026 • هاتور - الأسبوع 3".
  final String dateLabel;

  /// The lesson lines, or the no-lesson / holiday message; null while the
  /// programme is not loaded.
  final Widget? lesson;

  /// There is a lesson to read: it folds behind «عرض الدرس». Without one the
  /// short message shows as it is.
  final bool hasLesson;

  /// How many grades have a lesson. Several fold behind «درس الأسبوع ده»; a
  /// single one (a servant's own grade) shows directly, with nothing to open.
  final int lessonCount;

  /// Start with the lesson open (the default); false folds it.
  final bool lessonOpen;

  /// The classes whose prep is tracked (admin only; empty hides that part).
  final List<PrepClass> classes;
  final Set<String> prepared;

  @override
  State<NextSaturdayCard> createState() => _NextSaturdayCardState();
}

class _NextSaturdayCardState extends State<NextSaturdayCard> {
  late bool _lessonOpen = widget.lessonOpen;

  @override
  Widget build(BuildContext context) {
    final lesson = widget.lesson;
    if (lesson == null && widget.classes.isEmpty) {
      return const SizedBox.shrink();
    }
    // Several grades fold; the chevron sits on the card's own header, so
    // there is one header, not a second «درس الأسبوع ده» row under it.
    final foldable = lesson != null && widget.hasLesson && widget.lessonCount > 1;
    final header = Row(
      children: [
        Container(
          padding: const EdgeInsets.all(7),
          decoration: BoxDecoration(
            color: AppColors.olive.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.menu_book_rounded,
              size: 18, color: AppColors.oliveText),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                AppStrings.nextSaturdayCard,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              Text(
                widget.dateLabel,
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            ],
          ),
        ),
        if (foldable) _Chevron(open: _lessonOpen),
      ],
    );
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.navy.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          foldable
              ? Semantics(
                  button: true,
                  label: _lessonOpen
                      ? AppStrings.hideLesson
                      : AppStrings.showLesson,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => setState(() => _lessonOpen = !_lessonOpen),
                    child: header,
                  ),
                )
              : header,
          if (widget.classes.isNotEmpty) ...[
            const SizedBox(height: 8),
            PrepProgress(classes: widget.classes, prepared: widget.prepared),
          ],
          if (lesson != null) ...[
            const SizedBox(height: 8),
            if (foldable)
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                child: _lessonOpen
                    ? lesson
                    : const SizedBox(width: double.infinity),
              )
            else
              lesson,
          ],
        ],
      ),
    );
  }
}

/// «تحضير الفصول 3 من 8» as one small chip (amber while some are missing,
/// green when every class sent). The classes show under it as a pill each —
/// at once for up to [openByDefaultUpTo] classes, otherwise on a tap of the
/// chip: green with a tick once that class's servant sent the lesson prep,
/// amber «لسه» until then.
class PrepProgress extends StatefulWidget {
  const PrepProgress({super.key, required this.classes, required this.prepared});

  final List<PrepClass> classes;
  final Set<String> prepared;

  /// Up to this many classes the pills show at once; more open on a tap, so a
  /// home with eight pending classes is one small chip, not three rows.
  static const openByDefaultUpTo = 3;

  /// How many of [classes] have sent their prep.
  int get doneCount => classes.where((c) => prepared.contains(c.id)).length;

  @override
  State<PrepProgress> createState() => _PrepProgressState();
}

class _PrepProgressState extends State<PrepProgress> {
  late bool _open = widget.classes.length <= PrepProgress.openByDefaultUpTo;

  @override
  Widget build(BuildContext context) {
    final classes = widget.classes;
    if (classes.isEmpty) return const SizedBox.shrink();
    final done = widget.doneCount;
    final foldable = classes.length > PrepProgress.openByDefaultUpTo;
    final color = done == classes.length ? AppColors.success : AppColors.gold;
    final ink = AppColors.readable(color);
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done == classes.length
                ? Icons.fact_check_rounded
                : Icons.pending_actions_rounded,
            size: 16,
            color: ink,
          ),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              AppStrings.prepProgressTitle,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontSize: 12.5, fontWeight: FontWeight.w700, color: ink),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            AppStrings.prepDoneOf(done, classes.length),
            style: TextStyle(
                fontSize: 12.5, fontWeight: FontWeight.w900, color: ink),
          ),
          if (foldable) ...[
            const SizedBox(width: 2),
            Icon(
              _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
              size: 18,
              color: ink,
            ),
          ],
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: foldable
              ? Semantics(
                  button: true,
                  label:
                      _open ? AppStrings.hideClasses : AppStrings.showClasses,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => setState(() => _open = !_open),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 44),
                      child: Center(child: chip),
                    ),
                  ),
                )
              : chip,
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final c in classes)
                        _pill(c, widget.prepared.contains(c.id)),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }

  Widget _pill(PrepClass c, bool done) {
    final color = done ? AppColors.success : AppColors.gold;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.schedule_rounded,
            size: 14,
            color: AppColors.readable(color),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              done ? c.name : '${c.name} · ${AppStrings.prepNotYet}',
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.readable(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The small round chevron that says a header folds.
class _Chevron extends StatelessWidget {
  const _Chevron({required this.open});

  final bool open;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: AppColors.navy.withValues(alpha: 0.07),
        shape: BoxShape.circle,
      ),
      child: Icon(
        open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
        size: 20,
        color: AppColors.navyLight,
      ),
    );
  }
}

/// Loads the programme (and, for an admin, who has sent a prep) and draws
/// [NextSaturdayCard]; loads again when [reloadToken] changes. Quiet while
/// loading or when nothing can be shown.
class NextSaturdaySection extends StatefulWidget {
  const NextSaturdaySection({
    super.key,
    this.reloadToken = 0,
    this.showPrep = false,
    this.lessonOpen = true,
  });

  final int reloadToken;

  /// Track each class's prep (the admin home).
  final bool showPrep;
  final bool lessonOpen;

  @override
  State<NextSaturdaySection> createState() => _NextSaturdaySectionState();
}

class _NextSaturdaySectionState extends State<NextSaturdaySection> {
  late final DateTime _date = upcomingSaturday();
  late Future<LessonProgramme> _programme =
      const LessonRepository().programme();
  Future<Set<String>>? _prepared;

  Future<Set<String>> _loadPrepared() =>
      const ServantActivityRepository().classIdsWithPrep(_date);

  @override
  void didUpdateWidget(NextSaturdaySection old) {
    super.didUpdateWidget(old);
    if (old.reloadToken != widget.reloadToken) {
      _programme = const LessonRepository().programme();
      if (widget.showPrep) _prepared = _loadPrepared();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionController>();
    final grades = gradesFor(session);
    final firstDay = firstSessionDay(session);
    final classes = widget.showPrep
        ? [
            for (final c in session.myClasses)
              (id: c.classId, name: c.className),
          ]
        : const <PrepClass>[];
    if (widget.showPrep) _prepared ??= _loadPrepared();

    return FutureBuilder<LessonProgramme>(
      future: _programme,
      builder: (context, lessonSnap) {
        return FutureBuilder<Set<String>>(
          future: _prepared,
          builder: (context, prepSnap) {
            final programme = lessonSnap.data;
            final ready = programme != null &&
                !programme.isEmpty &&
                firstDay != null;
            final prepared = prepSnap.data;
            final showPrep = widget.showPrep && prepared != null;
            if (!ready && !showPrep) return const SizedBox.shrink();

            Widget? lesson;
            var hasLesson = false;
            var lessonCount = 0;
            var label = AppDateUtils.formatDayDate(_date);
            if (ready) {
              label = dateLine(_date, firstDay, programme);
              lessonCount = grades
                  .where((g) =>
                      programme.lessonOn(_date, g, firstDay: firstDay) != null)
                  .length;
              hasLesson = lessonCount > 0;
              lesson = LessonBlock(
                date: _date,
                firstDay: firstDay,
                grades: grades,
                programme: programme,
                showDate: false,
              );
            }
            return NextSaturdayCard(
              dateLabel: label,
              lesson: lesson,
              hasLesson: hasLesson,
              lessonCount: lessonCount,
              lessonOpen: widget.lessonOpen,
              classes: showPrep ? classes : const [],
              prepared: prepared ?? const {},
            );
          },
        );
      },
    );
  }
}
