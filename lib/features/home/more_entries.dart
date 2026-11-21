import 'package:flutter/material.dart';

import '../../core/l10n/app_strings.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/arabic_sort.dart';
import '../activity_log/activity_log_screen.dart';
import '../announcements/announcements_screen.dart';
import '../attendance/attendance_history_screen.dart';
import '../attendance/attendance_years_screen.dart';
import '../calendar/calendar_screen.dart';
import '../children/absence_followup_screen.dart';
import '../children/birthday_screen.dart';
import '../children/committed_children_screen.dart';
import '../children/missing_info_screen.dart';
import '../competitions/competitions_screen.dart';
import '../events/events_screen.dart';
import '../excel/export_screen.dart';
import '../excel/import_children_screen.dart';
import '../lessons/lesson_schedule_screen.dart';
import '../messages/message_templates_screen.dart';
import '../reports/reports_screen.dart';
import '../servants/servant_assignments_screen.dart';
import '../servants/servant_directory_screen.dart';
import '../servant_activities/preps_inbox_screen.dart';
import '../servants/servants_screen.dart';
import '../settings/settings_screen.dart';
import '../sync/sync_screen.dart';

/// Who is looking at المزيد. Hiding an entry is a convenience; the database
/// policies are what actually stop a write.
enum MoreRole { admin, generalServant, servant }

/// The cards the rows are grouped into, in page order.
enum MoreGroup { followUp, reports, service, admin, app }

/// The numbers an entry can carry as a badge.
enum MoreCount {
  absence,
  missingInfo,
  birthdays,
  invites,
  pendingPreps,
  failedSync,
}

/// One place المزيد leads to.
class MoreEntry {
  const MoreEntry({
    required this.id,
    required this.icon,
    required this.title,
    required this.color,
    required this.group,
    this.open,
    this.keywords = const [],
    this.roles = const {
      MoreRole.admin,
      MoreRole.generalServant,
      MoreRole.servant,
    },
    this.count,
  });

  final String id;
  final IconData icon;
  final String title;
  final Color color;
  final MoreGroup group;

  /// Builds the screen; only called when the entry is tapped. Null for an
  /// action المزيد runs itself (the update check).
  final Widget Function()? open;

  /// Other words that find it in the search box ("غياب", "اكسل").
  final List<String> keywords;
  final Set<MoreRole> roles;
  final MoreCount? count;
}

const _noGeneral = {MoreRole.admin, MoreRole.servant};
const _adminOnly = {MoreRole.admin};

/// Everything المزيد can show, and how each role sees it.
class MoreCatalog {
  const MoreCatalog._();

  static const updatesId = 'updates';

  static final List<MoreEntry> all = [
    // ── المتابعة
    MoreEntry(
      id: 'absence',
      icon: Icons.support_agent_rounded,
      title: AppStrings.absenceFollowUp,
      color: AppColors.coral,
      group: MoreGroup.followUp,
      open: () => const AbsenceFollowUpScreen(),
      keywords: const ['غياب', 'غايبين', 'افتقاد'],
      count: MoreCount.absence,
    ),
    MoreEntry(
      id: 'missingInfo',
      icon: Icons.rule_rounded,
      title: AppStrings.missingInfoTitle,
      color: AppColors.gold,
      group: MoreGroup.followUp,
      open: () => const MissingInfoScreen(),
      keywords: const ['ناقص', 'بيانات', 'اكمال'],
      count: MoreCount.missingInfo,
    ),
    MoreEntry(
      id: 'birthdays',
      icon: Icons.cake_outlined,
      title: AppStrings.birthdaysTitle,
      color: AppColors.warning,
      group: MoreGroup.followUp,
      open: () => const BirthdayScreen(),
      keywords: const ['عيد ميلاد', 'ميلاد'],
      count: MoreCount.birthdays,
    ),
    // ── التقارير والإكسل
    MoreEntry(
      id: 'reports',
      icon: Icons.insert_chart_outlined,
      title: AppStrings.reportsTitle,
      color: AppColors.sky,
      group: MoreGroup.reports,
      open: () => const ReportsScreen(),
      keywords: const ['تقارير', 'تقرير', 'احصائيات', 'نسبة الحضور'],
    ),
    // A list of children, so it sits with the reports: «المتابعة» would
    // otherwise be one row under its title, its other three being in the grid.
    MoreEntry(
      id: 'committed',
      icon: Icons.local_fire_department_rounded,
      title: AppStrings.committedStreak,
      color: AppColors.success,
      group: MoreGroup.reports,
      open: () => const CommittedChildrenScreen(),
      keywords: const ['مواظبة', 'حضور متتالي'],
    ),
    MoreEntry(
      id: 'attendanceHistory',
      icon: Icons.history,
      title: AppStrings.attendanceHistory,
      color: AppColors.navyLight,
      group: MoreGroup.reports,
      open: () => const AttendanceHistoryScreen(),
      keywords: const ['حضور', 'سبوت'],
    ),
    MoreEntry(
      id: 'export',
      icon: Icons.ios_share,
      title: AppStrings.excelReportsTitle,
      color: AppColors.navyLight,
      group: MoreGroup.reports,
      open: () => const ExportScreen(),
      keywords: const ['اكسل', 'excel', 'تصدير'],
      roles: _noGeneral,
    ),
    MoreEntry(
      id: 'import',
      icon: Icons.upload_file,
      title: AppStrings.importChildren,
      color: AppColors.navyLight,
      group: MoreGroup.reports,
      open: () => const ImportChildrenScreen(),
      keywords: const ['اكسل', 'excel', 'استيراد', 'رفع'],
      roles: _noGeneral,
    ),
    // ── الخدمة
    MoreEntry(
      id: 'lessonSchedule',
      icon: Icons.menu_book_outlined,
      title: AppStrings.lessonSchedule,
      color: AppColors.olive,
      group: MoreGroup.service,
      open: () => const LessonScheduleScreen(),
      keywords: const ['دروس', 'درس', 'منهج'],
    ),
    MoreEntry(
      id: 'calendar',
      icon: Icons.calendar_month_outlined,
      title: AppStrings.calendarTitle,
      color: AppColors.gold,
      group: MoreGroup.service,
      open: () => const CalendarScreen(),
      keywords: const ['تقويم', 'مواعيد', 'اجازات'],
    ),
    MoreEntry(
      id: 'events',
      icon: Icons.event_outlined,
      title: AppStrings.events,
      color: AppColors.olive,
      group: MoreGroup.service,
      open: () => const EventsScreen(),
      keywords: const ['رحلة', 'حفلة', 'نشاط', 'اشتراك'],
    ),
    // A servant of a class has no competitions.
    MoreEntry(
      id: 'competitions',
      icon: Icons.emoji_events_outlined,
      title: AppStrings.competitions,
      color: AppColors.gold,
      group: MoreGroup.service,
      open: () => const CompetitionsScreen(),
      keywords: const ['مسابقة', 'نقاط'],
      roles: const {MoreRole.admin, MoreRole.generalServant},
    ),
    // An admin has the full servants list under الإدارة instead.
    MoreEntry(
      id: 'servantDirectory',
      icon: Icons.contact_phone_rounded,
      title: AppStrings.servantDirectory,
      color: AppColors.olive,
      group: MoreGroup.service,
      open: () => const ServantDirectoryScreen(),
      keywords: const ['خدام', 'ارقام', 'تليفون', 'موبايل'],
      roles: const {MoreRole.generalServant, MoreRole.servant},
    ),
    // ── الإدارة
    MoreEntry(
      id: 'servants',
      icon: Icons.volunteer_activism_outlined,
      title: AppStrings.servantsTitle,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const ServantsScreen(),
      keywords: const ['خدام', 'دعوات', 'دعوة'],
      roles: _adminOnly,
      count: MoreCount.invites,
    ),
    // Every servant's lesson prep, the ones waiting for review first.
    MoreEntry(
      id: 'preps',
      icon: Icons.fact_check_rounded,
      title: AppStrings.prepsInboxTitle,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const PrepsInboxScreen(),
      keywords: const ['تحضير', 'تحضيرات', 'مراجعة', 'دروس'],
      roles: _adminOnly,
      count: MoreCount.pendingPreps,
    ),
    MoreEntry(
      id: 'assignments',
      icon: Icons.link,
      title: AppStrings.assignmentsTitle,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const ServantAssignmentsScreen(),
      keywords: const ['تعيين', 'فصول'],
      roles: _adminOnly,
    ),
    MoreEntry(
      id: 'announcements',
      icon: Icons.campaign_outlined,
      title: AppStrings.announcementsTitle,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const AnnouncementsScreen(),
      keywords: const ['اعلان', 'اعلانات'],
      roles: _adminOnly,
    ),
    MoreEntry(
      id: 'messageTemplates',
      icon: Icons.chat_outlined,
      title: AppStrings.messageTemplates,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const MessageTemplatesScreen(),
      keywords: const ['رسائل', 'رسالة', 'واتساب'],
      roles: _adminOnly,
    ),
    MoreEntry(
      id: 'attendanceYears',
      icon: Icons.date_range_rounded,
      title: AppStrings.attendanceYears,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const AttendanceYearsScreen(),
      keywords: const ['سنة', 'سنين'],
      roles: _adminOnly,
    ),
    MoreEntry(
      id: 'activityLog',
      icon: Icons.manage_history_rounded,
      title: AppStrings.activityLogTitle,
      color: AppColors.maroon,
      group: MoreGroup.admin,
      open: () => const ActivityLogScreen(),
      keywords: const ['تعديلات', 'سجل', 'مين عدل'],
      roles: _adminOnly,
    ),
    // ── التطبيق
    MoreEntry(
      id: 'sync',
      icon: Icons.sync_rounded,
      title: AppStrings.syncTitle,
      color: AppColors.sky,
      group: MoreGroup.app,
      open: () => const SyncScreen(),
      keywords: const ['مزامنة', 'اوفلاين', 'انترنت'],
      count: MoreCount.failedSync,
    ),
    // An action, not a screen: المزيد runs the check where it is.
    const MoreEntry(
      id: MoreCatalog.updatesId,
      icon: Icons.system_update_rounded,
      title: AppStrings.checkForUpdates,
      color: AppColors.olive,
      group: MoreGroup.app,
      keywords: ['تحديث', 'اصدار', 'نسخة جديدة'],
    ),
    MoreEntry(
      id: 'settings',
      icon: Icons.settings_outlined,
      title: AppStrings.settingsTitle,
      color: AppColors.muted,
      group: MoreGroup.app,
      open: () => const SettingsScreen(),
      keywords: const ['اعدادات', 'كلمة السر', 'خروج', 'بياناتي'],
    ),
  ];

  /// The six each role reaches for most, shown as the grid at the top.
  static const _top = <MoreRole, List<String>>{
    MoreRole.admin: [
      'absence',
      'reports',
      'missingInfo',
      'birthdays',
      'servants',
      'preps',
    ],
    MoreRole.generalServant: [
      'absence',
      'reports',
      'missingInfo',
      'birthdays',
      'competitions',
      'calendar',
    ],
    MoreRole.servant: [
      'absence',
      'missingInfo',
      'birthdays',
      'reports',
      'lessonSchedule',
      'events',
    ],
  };

  static List<MoreEntry> entriesFor(MoreRole role) => [
        for (final e in all)
          if (e.roles.contains(role)) e
      ];

  static List<MoreEntry> topFor(MoreRole role) {
    final mine = {for (final e in entriesFor(role)) e.id: e};
    return [
      for (final id in _top[role]!)
        if (mine[id] != null) mine[id]!
    ];
  }

  /// The rest, by group in page order; an entry already in the grid is not
  /// repeated and a group left empty is dropped.
  static List<(MoreGroup, List<MoreEntry>)> groupsFor(MoreRole role) {
    final top = {for (final e in topFor(role)) e.id};
    return [
      for (final g in MoreGroup.values)
        if (entriesFor(role)
                .where((e) => e.group == g && !top.contains(e.id))
                .toList()
            case final rows when rows.isNotEmpty)
          (g, rows),
    ];
  }

  /// Entries whose title or keywords hold every word of [query]. Letter
  /// variants match each other (أ/ا, ة/ه, ى/ي), so spelling does not matter.
  static List<MoreEntry> search(List<MoreEntry> entries, String query) {
    final words =
        ArabicSort.key(query).split(' ').where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return entries;
    return [
      for (final e in entries)
        if (_matches(e, words)) e,
    ];
  }

  static bool _matches(MoreEntry e, List<String> words) {
    final text = ArabicSort.key([e.title, ...e.keywords].join(' '));
    return words.every(text.contains);
  }

  static String groupTitle(MoreGroup g) => switch (g) {
        MoreGroup.followUp => AppStrings.moreFollowUp,
        MoreGroup.reports => AppStrings.moreReportsExcel,
        MoreGroup.service => AppStrings.moreService,
        MoreGroup.admin => AppStrings.moreAdmin,
        MoreGroup.app => AppStrings.moreApp,
      };

  static (IconData, Color) groupLook(MoreGroup g) => switch (g) {
        MoreGroup.followUp => (Icons.support_agent_rounded, AppColors.coral),
        MoreGroup.reports => (Icons.insights_rounded, AppColors.sky),
        MoreGroup.service => (Icons.church_rounded, AppColors.olive),
        MoreGroup.admin => (
            Icons.admin_panel_settings_rounded,
            AppColors.maroon,
          ),
        MoreGroup.app => (Icons.tune_rounded, AppColors.muted),
      };
}
