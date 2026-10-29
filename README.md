# Visitor Desk – Visitor Management App

Flutter (Android) app for front-desk and security staff at a real estate organisation. Staff can register visitors, look them up, generate and scan QR passes, and record check-in / check-out. All data lives on a REST API; nothing is stored or faked locally.

> **Build status.** The source was written in an environment with no Flutter SDK and no access to `pub.dev` / the Android SDK downloads, so the code was never compiled there: `flutter analyze`, the automated tests and the APK build were **not run** when it was written. Run the commands under [Verify](#verify) yourself and fix anything they report before submitting. See [Known limitations](#known-limitations).

## Contents

- [Setup](#setup)
- [Mock API (MockAPI.io)](#mock-api-mockapiio)
- [Run, test, build](#run-test-build)
- [Features](#features)
- [Architecture](#architecture)
- [State management (BLoC)](#state-management-bloc)
- [Business rules](#business-rules)
- [Dependencies](#dependencies)
- [Known limitations](#known-limitations)

## Setup

### Environment used

Fill these in after you build (assignment requirement). Run `flutter --version` and paste the first lines:

| Item | Value |
|---|---|
| Flutter | _e.g. 3.35.x (stable)_ |
| Dart | _e.g. 3.9.x_ |
| Android device / emulator tested | _model, Android version_ |

Requirements: Flutter **3.35 or newer** on the stable channel (the code uses `CardThemeData` and `DropdownButtonFormField.initialValue`), Dart 3.5+, Android SDK, a JDK compatible with your Flutter version. Run `flutter doctor` and fix anything red first.

```bash
# 1. Generate android/ and apply the camera/internet permissions + minSdk 23
bash scripts/bootstrap_android.sh

# 2. Create the mock API (next section), then run with its URL
flutter run --dart-define=API_BASE_URL=https://<project-id>.mockapi.io/api/v1
```

`scripts/bootstrap_android.sh` generates `android/` if it is missing (via `flutter create` in a temp folder, so `lib/`, `test/` and `pubspec.yaml` are untouched) and is **safe to re-run** on an existing `android/` folder: it only adds manifest entries that are missing. Re-run it after pulling updates, because newer versions add the permission needed to save the QR pass to the gallery. It then:

- adds `INTERNET` and `CAMERA` permissions (and `uses-feature camera required="false"`) to `AndroidManifest.xml`;
- sets the launcher label to "Visitor Desk";
- sets `minSdk = 23` (needed by `mobile_scanner`) in `android/app/build.gradle(.kts)`.

If you prefer to do this by hand, those are the only three changes.

Without `API_BASE_URL` the app opens a "API not configured" screen instead of pretending to work.

## Mock API (MockAPI.io)

**This needs a one-time manual step: I could not create an account or a project for you, so there is no live endpoint yet.** No URL in this repo points to a working server.

1. Sign up at [mockapi.io](https://mockapi.io) and create a project. Note the project's base URL, e.g. `https://64abc123.mockapi.io/api/v1` (the `/api/v1` part depends on the project settings; copy it exactly as shown).
2. Add **two** resources (MockAPI adds `id` automatically and generates it on the server). A person and each of their visits are stored separately so a returning visitor gets a new visit instead of overwriting the old one.

   **`visitors`** (identity)

   | Field | Type |
   |---|---|
   | `name` | String |
   | `mobile` | String |
   | `email` | String (nullable values are fine) |
   | `visitor_type` | String – `Customer` / `Vendor` / `Other` |
   | `created_at` | String (ISO-8601 with offset, e.g. `2026-10-26T10:00:00+05:30`) – when the person was first registered |

   **`visits`** (one record per visit session)

   | Field | Type |
   |---|---|
   | `visitor_id` | String – the `id` of the visitor |
   | `project` | String – `Project A` / `Project B` / `Project C` |
   | `purpose` | String |
   | `status` | String – `Registered` / `Checked In` / `Checked Out` |
   | `created_at` | String (ISO-8601 with offset) – when this visit was started |
   | `check_in_time` | String (nullable) |
   | `check_out_time` | String (nullable) |

   Use the **String** type for `mobile` and `visitor_id` so leading zeros are preserved. The app also tolerates numeric ids/mobiles in responses. Relationships/nested routes in MockAPI are **not** needed; the app joins the two lists itself.

   **Already have data from the older single-visit version?** Add the `visits` resource, then run `API_BASE_URL=... bash scripts/migrate_to_visits.sh` (add `--dry-run` first to preview). It creates one visit per existing visitor from the old fields and can be run twice safely.
3. (Optional) Add sample data: `API_BASE_URL=https://<id>.mockapi.io/api/v1 bash scripts/seed_api.sh`. It posts the four people in `api/seed_visitors.json` (one of them already has a finished earlier visit) with timestamps relative to now, so the dashboard shows non-zero figures.
4. Pass the base URL via `--dart-define=API_BASE_URL=...` on every `flutter run` / `flutter build`.

Endpoints used (all relative to the base URL):

| Method | Path | Used for |
|---|---|---|
| GET | `/visitors` | list, dashboard, refresh (together with `/visits`, joined by `visitor_id`) |
| GET | `/visitors/{id}` | QR lookup; re-read before every check-in/out and before starting a visit |
| POST | `/visitors` | register a new person (server returns the id used in the QR) |
| PATCH | `/visitors/{id}` | edit identity details |
| DELETE | `/visitors/{id}` | delete (their visits are deleted first) |
| GET | `/visits` and `/visits?visitor_id={id}` | all visits / one person's visits (the app re-checks `visitor_id` exactly, because mock APIs filter by substring) |
| POST | `/visits` | first visit at registration; a **new** visit for a returning visitor |
| PATCH | `/visits/{id}` | edit project/purpose of an unfinished visit; check-in; check-out |
| DELETE | `/visits/{id}` | only when the visitor is deleted |

Records persist on MockAPI's servers, so they survive app restarts. MockAPI's free tier has request and record limits, and the project must stay alive for evaluation. Check the plan you choose.

`created_at` is generated by the app at registration time (MockAPI does not do this for custom fields).

## Run, test, build

### Verify

```bash
flutter pub get
dart format .
flutter analyze
flutter test
```

### CI (GitHub Actions)

`.github/workflows/build.yml` runs bootstrap, format, `flutter analyze`, `flutter test` and a debug APK build on every push, and uploads the APK as a build artifact. Push the repo to GitHub, add a repository secret named `API_BASE_URL` (your MockAPI base URL), and open the **Actions** tab. This is the quickest way to find out whether the project compiles if you do not have Flutter set up locally. The workflow has not been run yet.

### Debug APK

```bash
flutter build apk --debug --dart-define=API_BASE_URL=https://<project-id>.mockapi.io/api/v1
# → build/app/outputs/flutter-apk/app-debug.apk
```

For a release-size build use `--release` (it is signed with the debug key unless you configure signing, which is fine for assignment evaluation).

### Tests included

| File | Covers |
|---|---|
| `test/visitor_model_test.dart` | JSON parsing/serialising (incl. the brief's sample), malformed data, status rules, QR id validation, timestamp helpers |
| `test/validators_test.dart` | name/purpose required, 10-digit mobile, optional-but-validated email |
| `test/dashboard_stats_test.dart` | local-day counting for today's metrics, recent activity |
| `test/visitors_cubit_test.dart` | load/failure, search, register/edit/delete, check-in/out rules, duplicate-tap prevention, stale-data protection, API-failure handling, QR lookup (uses an in-memory fake repository) |
| `test/widget_test.dart` | dashboard from data, error + retry, status-filter chips, project filter menu, details share/save buttons, form validation messages |
| `test/custom_widgets_test.dart` | `CustomButton` (tap, disabled, loading, variants) and `CustomTextField` (label, validation, disabled) |
| `test/qr_pass_image_test.dart` | the shareable QR pass image is a valid PNG, differs per visitor, survives very long names |
| `test/qr_image_scan_service_test.dart` | QR payload parsing, image decoding outcomes (found / no code / not a pass / unreadable) via a fake decoder |
| `test/visitor_search_test.dart` | name/mobile/ID matching, status and project filters, chip counts, filters surviving refresh and status changes |
| `test/repeat_visit_test.dart` | first visit, returning visitor after check-out, visits on different days keep their timestamps, no duplicate active visits (double taps, other device, repeated scans), finished visits never reopened, editing, delete, API failure, dashboard counts per visit and day |
| `test/api_visitor_repository_test.dart` | the real REST repository against an in-memory server: URLs and bodies, visitor/visit join, substring-filter safety, rollback of a failed registration, PATCH only touches visits, delete cascade, malformed and 404 responses |
| `test/status_transitions_test.dart` | every status × check-in/check-out combination at the domain and cubit level; QR and manual paths share one flow |

## Features

- **Dashboard** – Total Visitors Today, Currently Checked In, Checked Out Today (all computed from the fetched records using the device's local date), *Register visitor* and *Scan QR* buttons, recent activity derived from real records, pull-to-refresh.
- **Visitors** – search by name (partial, case-insensitive), mobile number (partial, from the first digit) or visitor ID (exact match); status filter chips (All / Registered / Checked In / Checked Out) and a project filter menu, with counts that follow the search; edit/delete with confirmation; pull-to-refresh; skeleton loading, empty, no-match (with "Clear filters") and error states. Search runs locally on the loaded records, so no extra API requests (and no debounce) are needed. No server-side filter endpoint is assumed. A query made only of digits, spaces, dashes, "+" and brackets is also matched against mobile numbers; a query containing letters (e.g. an ID such as `VIS-7`) is matched against names and IDs only.
- **Share / download the QR pass** – on the details screen, *Share* opens the Android share sheet and *Save* stores the image in the photo gallery. The image is a pass with the visitor's name, the QR code (payload = the server-generated visitor ID), the ID in plain text and the project, so a visitor who loses it can be sent a fresh copy and the front desk can still find them by ID.
- **Register / Edit** – one shared form: required name and purpose, exactly 10-digit mobile, optional validated email, type and project dropdowns, scrollable and keyboard-safe, Save disabled while a request runs.
- **Details** – all fields, status, check-in / check-out timestamps when present, QR code built from the server-returned id, visit history, and only the action valid for the current status (Check in, Check out, or Start new visit).
- **QR scanner** – camera preview, permission-denied explanation with retry, malformed-QR and unknown-visitor errors, one lookup per scan, camera released while processing, in the background, and on exit.
- **Upload QR image** – button on the scanner (also available when the camera is unavailable or denied): pick an image from the gallery, decode it with `mobile_scanner`'s `analyzeImage`, extract the visitor ID, look the visitor up through the API and open their details. Handled: cancelled picker (silently returns to scanning), image with no QR code, QR that is not a visitor pass, unreadable image, unknown visitor, network/API errors. The camera and the upload share one processing path guarded by the same in-flight flag.
- **Manual check-in / check-out** – search or filter in the Visitors tab, open a visitor, use the Check in / Check out button. This is the same `VisitorsCubit.checkIn/checkOut` (and the same server re-read + status rules) used after a QR scan.
- **Form safety** – leaving the register/edit form with unsaved input asks for confirmation.
- **Bottom navigation** – Dashboard, Visitors, Scan. Scan opens the camera as its own screen so the camera is only held while visible.

## Look and feel ("liquid glass")

The UI approximates iOS's Liquid Glass with plain Flutter, no extra packages: a soft colored backdrop (`GlassBackground`), frosted translucent panels with real background blur and a bright rim (`GlassContainer`), a floating capsule tab bar and action bar, capsule buttons, large corners, and iOS-style slide / swipe-back page transitions. Everything lives in `lib/core/widgets/glass.dart` and `lib/app/theme/app_theme.dart`.

- **Style switch:** the assignment asks for Material Design and says the focus is functionality rather than advanced UI effects. For a submission that follows that literally, build with `--dart-define=GLASS_UI=false`: the same app with a plain Material 3 theme, flat background, standard `NavigationBar` and default page transitions. `GLASS_UI` defaults to `true`. One flag (`lib/core/config/ui_style.dart`) controls everything; no screen code changes.
- Heavy blur (`BackdropFilter`) is only used on a few surfaces (tab bar, action bar, stat tiles, scanner overlays). List cards use a translucent fill without blur so long lists stay smooth.
- True Liquid Glass refraction/lensing is not reproducible in Flutter; this is a blur-and-translucency approximation. Blur strength, alpha values and the backdrop blobs are constants in `glass.dart` if you want to tune them.
- Not yet checked visually on a device. Text contrast was kept high (dark ink on near-white glass), but review it on your screen.

## Architecture

```
lib/
  main.dart
  app/                     app shell, bottom nav, theme, navigation helpers
  core/
    config/api_config.dart       base URL (--dart-define), timeouts
    error/app_exception.dart     one error type, staff-readable messages
    network/dio_client.dart
    utils/                       validators, date/time helpers
    widgets/                     LoadingView, EmptyState, ErrorView, stat card, snackbar helper
  features/
    visitors/
      domain/                    Visitor (person) + Visit (one session), VisitorStatus (workflow rules), VisitorDraft, QR id parser
      data/                      VisitorRepository (+ Dio implementation)
      presentation/              VisitorsCubit/State, pages, VisitorCard, StatusChip
    dashboard/
      domain/                    DashboardStats (pure function of the visitor list)
      presentation/
    qr_scanner/presentation/
```

- Widgets never touch Dio; they call the cubit, which calls the repository.
- `VisitorRepository` is a small interface so tests can use an in-memory fake. That is the only abstraction added for testability.
- Navigation is plain `Navigator` with typed helpers in `app/router.dart`. With five screens and no deep links, a routing package would add more than it saves.

## State management (BLoC)

I used **`flutter_bloc` with a single `VisitorsCubit`**.

- One cubit owns the visitor list. The dashboard, list and details screens all read from it, so after a check-in all three update immediately and cannot disagree. Dashboard numbers are derived from that list by `DashboardStats.fromVisitors`, so there is no second copy of the data to keep in sync.
- A Cubit (methods, not events) is enough here: every action is a direct user command, so separate event classes would only add indirection.
- Operations return an `ActionResult` (success / failure message / ignored) that the UI turns into a snackbar. The cubit state holds only what the UI needs to *render*: load status, the list, the search query, `isSaving`, and `busyIds` (visitors with a request in flight).
- Duplicate-request protection lives in the cubit, not in widgets: `isSaving` blocks double registration/edit, and `busyIds` is set synchronously before the first `await`, so repeated taps or repeated scanner callbacks cannot start a second request.

## Business rules

Registered → Checked In → Checked Out, defined once on `VisitorStatus` (`checkInBlockedReason` / `checkOutBlockedReason`) and used by both the UI and the cubit.

- New visitors are created with a first visit that is Registered with no check times.
- Check-in only from Registered; check-out only from Checked In. Invalid actions are not shown, and are also rejected in the cubit with a specific message ("already checked in", "has not checked in yet", "visit already completed").
- Before every check-in/out the visitor is **re-fetched from the server**, so a stale list (or another device) cannot cause a double check-in. The PATCH goes out only if the fresh status allows it.
- The local list is updated from the **server's response**, never optimistically, so a failed request is never shown as a success.
- Timestamps are written as ISO-8601 with the device's UTC offset (e.g. `2026-10-26T10:30:00+05:30`), parsed back to local time, and "today" always means the device's local calendar day.

## Dependencies

| Package | Why |
|---|---|
| `flutter_bloc` | Cubit state management |
| `equatable` | Value equality for models/state |
| `dio` | REST client with timeouts and typed errors |
| `qr_flutter` | QR generation |
| `mobile_scanner` | Camera QR scanning and image QR decoding (`>=6.0.2 <8.0.0`) |
| `image_picker` | Gallery picker for "Upload QR image" (uses the Android photo picker; no extra permission) |
| `share_plus` | Share sheet for the QR pass (`>=10.1.0 <11.0.0`, the API used is `Share.shareXFiles`) |
| `path_provider` | Temporary folder for the generated pass image |
| `gal` | Saves the pass image to the photo gallery (needs `WRITE_EXTERNAL_STORAGE` on Android 9 and below only, added by the bootstrap script) |
| `flutter_lints` (dev) | Lints |

Exact resolved versions are in `pubspec.lock` after `flutter pub get`. Flutter and Dart versions are recorded in [Environment used](#environment-used).

## Repeat visits

A person (`Visitor`) and a visit session (`Visit`) are separate records. A visitor can have many visits; the status workflow above applies to each **visit**, not to the person.

- **Returning visitor:** find them by name, mobile, ID or QR, open the details and tap **Start new visit** (project and purpose are pre-filled from the last visit). A new visit is created as Registered; earlier visits are never modified and stay in the **Visit history** list on the details screen.
- **The QR code identifies the person**, not a single visit, so the same pass works on every visit.
- **One active visit at a time:** if the visitor already has a Registered or Checked In visit, *Start new visit* is not offered; if it is attempted anyway (stale screen, other device, double tap, repeated scanner callbacks) the app re-reads the server, creates nothing and tells the staff member which visit is active.
- **A finished visit is never reopened:** check-in/out always act on the active visit; with none, the app says to start a new visit.
- **What the screens show:** the list, filters and the details header describe the person's *current* visit (the active one, otherwise the latest). Search and filters are unchanged.
- **Dashboard (per visit session, local day):** *Registered today* = distinct visitors with a visit started today (a returning visitor counts today, once); *Currently checked in* = visits with status Checked In; *Checked out today* = visits whose check-out time is today. Recent activity lists the latest event of each visit.
- **Editing:** identity fields (name, mobile, email, type) always. Project and purpose only while the visit is unfinished; for a finished visit they are shown read-only.

## Known limitations

- **Not compiled or run yet** (see the note at the top). No APK and no screenshots are included because none could be produced honestly in the authoring environment. After building, capture: dashboard, visitor list, registration form, visitor details with QR, scanner.
- **Camera scanning is untested** on any device. `mobile_scanner` changes its API between major versions; the scanner uses only `MobileScannerController`, `MobileScanner(controller, onDetect)`, `start/stop`, `value.error` and `MobileScannerException.errorCode`. If a version mismatch shows up in `flutter analyze`, adjust `lib/features/qr_scanner/presentation/scanner_page.dart`.
- **Image upload is unverified.** `image_picker` and `mobile_scanner.analyzeImage` were added without being able to resolve or run them here, so their API use has not been checked against your installed versions. The decoding itself needs the device's ML Kit and is not covered by unit tests (the surrounding logic is, through a fake decoder). If `analyzeImage` has a different signature in your resolved `mobile_scanner`, only `lib/features/qr_scanner/data/mobile_scanner_image_decoder.dart` needs adjusting.
- **Share / save are unverified.** `share_plus` (10.x), `gal` and `path_provider` were added without being able to resolve or run them, so their API use has not been checked against your installed versions, and nothing was tested on a device. Only the pass image generation is covered by tests. After adding the packages, **fully stop and rebuild the app** (hot reload does not register new native plugins) and re-run `scripts/bootstrap_android.sh`.
- **Search ambiguity:** a numeric query such as `1` matches the visitor whose ID is exactly `1` **and** every mobile number containing a 1. That follows from searching by both ID and mobile; type more digits to narrow it.
- **Not implemented:** staff login/roles (the assignment does not ask for them), local caching and dark mode (all optional in the assignment).
- **Repeat visits are an optional enhancement** beyond the assignment (which allows one visit per registration). They need the second `visits` resource; without it the app cannot load.
- **No transactions on the mock API.** Registration is two requests (visitor, then first visit); if the visit fails the app tries to delete the new visitor again, and if that also fails a person without a visit can remain (shown as having no active visit, with *Start new visit* available). Two devices starting a visit for the same person at the same instant could still both succeed, because the check and the create are separate requests; the app narrows this by re-reading just before creating. Deleting a person deletes their visits one by one, so an interrupted delete can be repeated safely.
- **Not verified against MockAPI:** the `?visitor_id=` filter and the two-resource setup were written from the provider's documented behaviour and tested only against an in-memory fake server, not against a live MockAPI project.
- **Permission handling:** the camera permission prompt is shown by `mobile_scanner`. If it is denied permanently the app explains how to enable it in Android Settings; it does not deep-link into settings (that would need an extra package).
- **No authentication.** Anyone with the API URL can read and write visitor data. Acceptable for a mock API; a real deployment needs auth and HTTPS-only access control.
- **A single malformed record** (e.g. an unknown `status`) makes the list fail to load with a "could not read data" error rather than guessing a status. Unknown `visitor_type` values fall back to "Other".
- **MockAPI specifics:** an empty collection is expected to return `[]`; if your provider returns 404 for an empty list, the app will show that as an error.
- No offline cache, no dark mode, Android only.
