# سبتاوية · Sabtawya

Attendance, follow-up and servant-activity management for the Saturday primary
service (grades 3 to 6) of the Church of the Virgin Mary and St. Athanasius,
Nasr City. Arabic only, right to left. One Flutter codebase builds the website
and the Android app; the backend is Supabase.

- Website and APK downloads: <https://sabtawya.vercel.app>
- Code: <https://github.com/FaresHanna96/Sabtawya-app>

## What it does

| Area | Notes |
|---|---|
| Attendance (الحضور) | One sheet per class per Saturday: Sunday school, vespers, mass, confession. Points are computed by the database. Works offline. |
| Children (المخدومين) | Profiles, photos, parents, confession father, visits history, Excel import. |
| Classes (الفصول) | Eight classes (grades 3 to 6, boys and girls), each with servants and a patron saint. |
| Follow-up | Absence follow-up with call and visit log, committed children, birthdays, calendar. |
| Servant activities (نشاط الخدام) | Lesson preparation with photos and admin review, servant attendance, monthly report. |
| Competitions and events | Weekly competition marks; events with costs, payments and reservations. |
| Reports | Charts, year and monthly reports, Excel exports. |
| Notifications | In-app bell plus push (web and Android). Each entry opens the screen it is about. |
| Offline | Reads come from the last good copy, writes are queued and replayed in order (see below). |

### Roles

| Role | Can |
|---|---|
| `admin` | Everything: servants and sign-up requests, classes, years, locking a Saturday, reviews, backups. |
| `servant` | Their own classes only: children, attendance, preparation, events and competitions. |
| `general_servant` | Reads everything and records attendance anywhere; cannot add children or change classes. |

New servants sign up in the app and wait for an admin to accept them.

## How it is built

```
lib/
  app.dart, main.dart          app shell, providers, startup
  core/                        config, theme, strings (l10n), widgets, utils, services
    services/                  offline_http_client, offline_store, sync_service, push_service ...
  data/
    models/                    plain classes parsed from rows
    repositories/              all Supabase calls, one per area
    services/                  Excel import/export, photos, email
  features/<area>/             screens
  state/session_controller.dart  who is signed in, their role and classes
supabase/
  migrations/                  the whole database, in order (tables, RLS, functions, views, cron)
  functions/                   edge functions: send-email, push-admins, weekly-backup
web/                           index.html, service worker, download page (apk.html), stats page
test/                          unit and widget tests (run anywhere)
test_dev/                      database-rule tests against the DEV project (run on purpose)
```

Three ideas to know before changing anything:

1. **The database is the authority.** Row level security decides who sees which
   rows, triggers compute scores and guard role changes, and every view is
   `security_invoker`. The app never filters data for safety, it only presents it.
2. **Offline sits under the Supabase client.** `OfflineHttpClient` keeps the last
   answer of every read and queues writes that cannot be sent; `SyncService`
   replays them oldest first, as the person who made them. Queued writes and
   kept reads are encrypted on Android (key in the keystore). A server refusal
   sets a write aside (it shows in المزيد > المزامنة) instead of dropping it.
3. **Attendance saves only what changed.** A save sends the marks the servant
   touched, plus an "absent if still missing" row for untouched children, so two
   servants marking one class never undo each other.

## Run it

Needs Flutter (the scripts expect `D:\dev\flutter`) and a Supabase project.

```powershell
flutter pub get
flutter run -d chrome `
  --dart-define=SUPABASE_URL=https://<project>.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=<publishable key>
```

Without the two `--dart-define` values the app shows "إعداد غير مكتمل". The
publishable key is safe to ship; every table is protected by row level security.

## Two Supabase projects

| | Project | Used by |
|---|---|---|
| Production | `fxclufgfkvfrhdleyndf` | the live site and APK. The repo's `supabase/` folder is linked to it. |
| Dev | `atusdmohomycgqmhoovh` (sabtawya-dev) | testing. Made-up children, three test accounts. |

The dev credentials, publishable key and database password live in the
git-ignored `backups/` folder. **Never `supabase link` the repo to dev.** To
push migrations or functions to dev, copy `supabase/` to a scratch folder
(leaving out `20261104003_real_children.sql`, which is real children's data, and
`20261103_test_birthdays.sql`), link that copy to dev and push from there.

Migrations are applied with `npx supabase db push --remote`. Look at the target
line it prints before confirming: it says which project it is about to change.

## Tests

```powershell
flutter analyze
flutter test              # unit and widget tests, no network
flutter test test_dev     # database rules against the DEV project (needs backups/)
```

`test_dev` signs in as the dev admin, servant and general servant and checks row
security, the profile guard, locked Saturdays, the attendance save requests,
visit-history deletion and the Excel import function. Each test restores what it
changed.

## Release

1. Raise the version in **both** `pubspec.yaml` (`version: x.y.z+n`) and
   `lib/core/config/app_version.dart` (a test checks they match).
2. Update the facts on `web/apk.html` (version, size in MB, date).
3. `flutter analyze` and `flutter test` clean.
4. Database changes first: migrations and edge functions to dev, test, then
   production (`supabase db push`, `supabase functions deploy <name>`).
5. `.\build_apk.ps1` builds `sabtawya.apk` (arm64) and `sabtawya-armv7.apk`.
6. `.\build_web.ps1` builds the site, copies both APKs next to it, writes
   `version.json` (with each APK's SHA-256) and deploys to Vercel project
   `sabtawya`. It refuses to deploy without both APKs.
   `build_web.ps1` also runs `send_update_push.ps1`: a push and a bell entry to every active user
   ("install version x.y.z"). Skip it for a release with `-NoPush`; a repeat for the same version
   is skipped by the script itself.
   Two kinds of update notice: `app_update` (this release push) and `app_update_reminder` (a weekly Friday
   5 PM Cairo reminder for four weeks after each release, `notify_update_reminder`).
7. Check `https://sabtawya.vercel.app/version.json` and compare the SHA-256 of the
   downloaded APKs with the local files.

Android phones check `version.json` and offer the update inside the app; the
download is verified against the published SHA-256 before it is installed.
For the dev site: `.\build_dev.ps1 [-Deploy] [-Apk]`.

## Backups

`weekly-backup` runs from `pg_cron` every Friday: the data as CSV files, then the
children's photos, each as an AES-256 encrypted zip emailed to `BACKUP_TO`. It
needs these function secrets: `BACKUP_PASSWORD` (12+ characters, kept somewhere
you will find it, since a backup nobody can open is useless), `BACKUP_TO`,
`GMAIL_USER`, `GMAIL_PASS`. Without a password it sends nothing. Open the zips
with 7-Zip or WinRAR. A test run that sends no mail:
`POST /functions/v1/weekly-backup` with header `x-backup-secret` and body
`{"dryRun":true}` (or `{"part":"photos","dryRun":true}`).

## Monthly report email

`monthly-report` runs from `pg_cron` on the 1st of each month (Cairo 9 AM) and
emails the previous month's attendance report, an Excel file with the same
columns as the app's monthly export, to every active admin (one mail each). It
uses the same secrets as the backup (`GMAIL_USER`, `GMAIL_PASS`) and the same
`x-backup-secret` header. Nothing is sent for a month with no attendance taken.
Try it without sending: `POST /functions/v1/monthly-report` with the header and
body `{"dryRun":true,"month":"2026-10"}`. Deploy with
`supabase functions deploy monthly-report`. The Excel builder is plain
TypeScript; its tests run without Deno:
`node --test supabase/functions/monthly-report/monthly_test.ts`.

Errors the app does not handle go to Firebase Crashlytics on Android and to the
`app_errors` table on the web; admins read them on the stats page.
