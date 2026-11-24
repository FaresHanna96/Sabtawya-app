# Apply UI prototype to the Flutter app (phased) — saved for next week

## Context
`docs/prototype/sabtawya-ui-prototype.html` (served locally via launch entry `ui-prototype`, port 8095) proposes UI improvements for 8 screens plus shared components. Goal: apply them to the real Flutter app (`lib/`), one phase at a time, verified on the dev backend (sabtawya-dev, `build_dev.ps1`, fake data) before anything touches prod. Weekly Pro usage was 44% when planned, so work is split to keep each phase cheap. Nothing here is committed; per CLAUDE.md the user reviews before each push, and every feature gets tests.

Prototype fix already applied (uncommitted): follow-up chips (`#fu`) now call `chipOne`. Also uncommitted: `ui-prototype` entry in `.claude/launch.json`.

## Phase 1 (next week): shared components + Attendance + Absence follow-up
Est. 10–20% of weekly usage (guess). Read files in ranges, not whole.

### 1a. Shared components (prototype "اقتراحات 2–5")
- Existing: `lib/core/widgets/app_widgets.dart` (SectionCard, StatusBadge, PercentageBar...), `skeleton.dart`, `motion.dart`, `lib/core/utils/haptics.dart`, `lib/core/theme/app_theme.dart`, `class_colors.dart`.
- Add/extend (reuse, don't duplicate): date cube (day number over month; tint by type: birthday gold, activity olive, trip sky), progress ring, "saved ✓" confirmation with light haptic.
- Readability: darken small grey text (check `test/core/theme/contrast_test.dart`), min 44px tap targets.
- Replace spinners with `skeleton.dart` on the lists touched in this phase.

### 1b. Attendance — `lib/features/attendance/attendance_screen.dart` (2494 lines)
- Sticky top summary bar: "حاضر X من Y" + save progress.
- Single «الكل حاضر» button with undo from the bottom snackbar (reuse `attendance_draft.dart` so undo restores the previous draft).
- Four practice buttons at 44px with light haptic on tap (`haptics.dart`).
- Respect existing `attendance_swipe.dart`, `break_sheet.dart`, offline draft behaviour.
- Strings go in `lib/core/l10n/app_strings.dart` (Egyptian wording, per `docs/wording-changes.md`).

### 1c. Absence follow-up — `lib/features/children/absence_followup_screen.dart` (432 lines)
- Progress strip "اتفتقد X من Y" that fills; «تم الافتقاد» moves the card to the bottom with ✓; call + WhatsApp stay on the card (reuse `follow_up_call.dart`, `core/utils/whatsapp.dart`).
- Filter chips: reuse `class_filter_chips.dart`.

### Tests (mandatory)
Extend `test/attendance_*_test.dart` (draft/undo, all-present), add widget tests for date cube/ring/progress strip, extend `contrast_test.dart`. Run `flutter test` + `flutter analyze`.

### Verify
`build_dev.ps1` → local web against sabtawya-dev; click through Attendance (tap, all-present, undo, save) and Absence follow-up in the browser pane; compare with prototype at http://localhost:8095. No prod deploy/APK release unless told (release rules in memory: forced + push + Friday reminder).

## Later phases (decide after reading weekly usage)
2. Home «محتاج متابعة» strip + next-Saturday lesson card (`dashboard/admin_dashboard_screen.dart`, `servant_dashboard_screen.dart`, `missing_info_section.dart`).
3. Children list: swipe-to-call/WhatsApp, quick chips (غايب, عيد ميلاده, بيانات ناقصة), class-colour avatar, last-attendance line (`children_screen.dart`, `child_tile.dart`, `child_filters.dart`).
4. Child profile header with level (نبتة) bar and fixed call/WhatsApp/افتقاد buttons (`child_profile_screen.dart`, 1490 lines).
5. Reports summary-first card + podium (`reports_screen.dart`, no existing tests).
6. Calendar date-cube cards + unpaid badge (`calendar_screen.dart`, no existing tests).
7. Settings grouped sections (`settings_screen.dart`, no existing tests).

## Open items for next week
- Confirm scope (Phase 1 only vs more) and verify path (dev Supabase + local web recommended).
- Re-read prototype section HTML for exact spacing/colours when implementing each screen.
