import 'package:equatable/equatable.dart';

import '../../../core/utils/date_time_utils.dart';

/// Projects offered in the registration form.
const List<String> kProjects = ['Project A', 'Project B', 'Project C'];

enum VisitorType {
  customer('Customer'),
  vendor('Vendor'),
  other('Other');

  const VisitorType(this.label);

  final String label;

  /// Unknown values from the API fall back to [other] so a single odd record
  /// does not make the whole list unreadable.
  static VisitorType fromLabel(String? label) {
    for (final type in VisitorType.values) {
      if (type.label.toLowerCase() == label?.trim().toLowerCase()) return type;
    }
    return VisitorType.other;
  }
}

/// Registered → Checked In → Checked Out. These rules are the single source of
/// truth for which action is valid; the UI and the cubit both ask this enum.
enum VisitorStatus {
  registered('Registered'),
  checkedIn('Checked In'),
  checkedOut('Checked Out');

  const VisitorStatus(this.label);

  final String label;

  /// Unlike [VisitorType], an unknown status is an error: guessing a status
  /// could allow an invalid check-in or check-out.
  static VisitorStatus fromLabel(String label) {
    for (final status in VisitorStatus.values) {
      if (status.label.toLowerCase() == label.trim().toLowerCase()) {
        return status;
      }
    }
    throw FormatException('Unknown visitor status "$label"');
  }

  /// Null when check-in is allowed, otherwise the reason it is not.
  String? get checkInBlockedReason => switch (this) {
        VisitorStatus.registered => null,
        VisitorStatus.checkedIn => 'This visitor is already checked in.',
        VisitorStatus.checkedOut =>
          'This visit is already completed and cannot be checked in again.',
      };

  /// Null when check-out is allowed, otherwise the reason it is not.
  String? get checkOutBlockedReason => switch (this) {
        VisitorStatus.registered => 'This visitor has not checked in yet.',
        VisitorStatus.checkedIn => null,
        VisitorStatus.checkedOut => 'This visitor has already checked out.',
      };

  bool get canCheckIn => checkInBlockedReason == null;
  bool get canCheckOut => checkOutBlockedReason == null;
}

/// One visit session: a single Registered -> Checked In -> Checked Out cycle.
/// A visitor can have many of these; finished ones are never modified again.
class Visit extends Equatable {
  const Visit({
    required this.id,
    required this.visitorId,
    required this.project,
    required this.purpose,
    required this.status,
    required this.createdAt,
    this.checkInTime,
    this.checkOutTime,
  });

  final String id;
  final String visitorId;
  final String project;
  final String purpose;
  final VisitorStatus status;
  final DateTime createdAt;
  final DateTime? checkInTime;
  final DateTime? checkOutTime;

  /// A visit that is not finished yet (Registered or Checked In).
  bool get isActive => status != VisitorStatus.checkedOut;

  /// Throws [FormatException] when a required field is missing or malformed.
  factory Visit.fromJson(Map<String, dynamic> json) {
    final rawId = json['id'];
    if (rawId == null || rawId.toString().trim().isEmpty) {
      throw const FormatException('Visit record has no id');
    }
    return Visit(
      id: rawId.toString(),
      visitorId: _requiredString(json, 'visitor_id'),
      project: _requiredString(json, 'project'),
      purpose: _optionalString(json['purpose']) ?? '',
      status: VisitorStatus.fromLabel(_requiredString(json, 'status')),
      createdAt: _requiredDateTime(json, 'created_at'),
      checkInTime: _optionalDateTime(json['check_in_time']),
      checkOutTime: _optionalDateTime(json['check_out_time']),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'visitor_id': visitorId,
        'project': project,
        'purpose': purpose,
        'status': status.label,
        'created_at': toIso8601WithOffset(createdAt),
        'check_in_time':
            checkInTime == null ? null : toIso8601WithOffset(checkInTime!),
        'check_out_time':
            checkOutTime == null ? null : toIso8601WithOffset(checkOutTime!),
      };

  /// Body for POST /visits: every new session starts as Registered with no
  /// check times. The server generates the visit id.
  static Map<String, dynamic> createJson({
    required String visitorId,
    required String project,
    required String purpose,
    required DateTime createdAt,
  }) =>
      {
        'visitor_id': visitorId,
        'project': project.trim(),
        'purpose': purpose.trim(),
        'status': VisitorStatus.registered.label,
        'created_at': toIso8601WithOffset(createdAt),
        'check_in_time': null,
        'check_out_time': null,
      };

  @override
  List<Object?> get props => [
        id,
        visitorId,
        project,
        purpose,
        status,
        createdAt,
        checkInTime,
        checkOutTime,
      ];
}

/// A person (identity) together with all of their visit sessions.
///
/// Only the identity fields are stored in the `visitors` resource; [visits]
/// come from the `visits` resource and are joined by `visitor_id`. The
/// project / purpose / status / check-in-time getters describe the
/// [currentVisit], so list and details screens can keep reading them from the
/// visitor.
class Visitor extends Equatable {
  const Visitor({
    required this.id,
    required this.name,
    required this.mobile,
    required this.visitorType,
    required this.createdAt,
    this.email,
    this.visits = const [],
  });

  final String id;
  final String name;
  final String mobile;
  final String? email;
  final VisitorType visitorType;

  /// When the person was first registered (not when a visit started).
  final DateTime createdAt;
  final List<Visit> visits;

  /// Identity only. Extra keys (such as the old single-visit fields) are
  /// ignored. Throws [FormatException] when a required field is malformed.
  factory Visitor.fromJson(
    Map<String, dynamic> json, {
    List<Visit> visits = const [],
  }) {
    final rawId = json['id'];
    if (rawId == null || rawId.toString().trim().isEmpty) {
      throw const FormatException('Visitor record has no id');
    }
    return Visitor(
      id: rawId.toString(),
      name: _requiredString(json, 'name'),
      mobile: _requiredString(json, 'mobile'),
      email: _optionalString(json['email']),
      visitorType: VisitorType.fromLabel(_optionalString(json['visitor_type'])),
      createdAt: _requiredDateTime(json, 'created_at'),
      visits: visits,
    );
  }

  /// Identity only; visits are stored as their own records.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'mobile': mobile,
        'email': email,
        'visitor_type': visitorType.label,
        'created_at': toIso8601WithOffset(createdAt),
      };

  /// Visits, most recently started first.
  List<Visit> get visitsNewestFirst {
    final sorted = [...visits];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  Visit? get latestVisit {
    final sorted = visitsNewestFirst;
    return sorted.isEmpty ? null : sorted.first;
  }

  /// The unfinished visit, if any. There should be at most one; if a race on
  /// the server ever created two, the newest one is used.
  Visit? get activeVisit {
    for (final visit in visitsNewestFirst) {
      if (visit.isActive) return visit;
    }
    return null;
  }

  /// The visit the screens show and act on: the active one, otherwise the most
  /// recent finished one.
  Visit? get currentVisit => activeVisit ?? latestVisit;

  bool get hasActiveVisit => activeVisit != null;

  /// A start-of-visit moment for sorting: latest visit, else registration.
  DateTime get lastActivityAt => latestVisit?.createdAt ?? createdAt;

  String get project => currentVisit?.project ?? '';
  String get purpose => currentVisit?.purpose ?? '';

  /// A person with no visit at all (only possible if a visit could not be
  /// created) is treated as "not in a visit": no check-in is offered.
  VisitorStatus get status => currentVisit?.status ?? VisitorStatus.checkedOut;
  DateTime? get checkInTime => currentVisit?.checkInTime;
  DateTime? get checkOutTime => currentVisit?.checkOutTime;

  /// Same person with [visit] added, or replaced when its id is already known.
  Visitor withVisit(Visit visit) {
    final list = [...visits];
    final index = list.indexWhere((v) => v.id == visit.id);
    if (index == -1) {
      list.add(visit);
    } else {
      list[index] = visit;
    }
    return withVisits(list);
  }

  Visitor withVisits(List<Visit> newVisits) => Visitor(
        id: id,
        name: name,
        mobile: mobile,
        email: email,
        visitorType: visitorType,
        createdAt: createdAt,
        visits: newVisits,
      );

  @override
  List<Object?> get props =>
      [id, name, mobile, email, visitorType, createdAt, visits];
}

// Parsing helpers shared by Visit and Visitor.
String _requiredString(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is String && value.trim().isNotEmpty) return value.trim();
  // Some mock APIs coerce numeric-looking strings to numbers.
  if (value is num) return value.toString();
  throw FormatException('Missing or invalid "$key"');
}

String? _optionalString(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  return text.isEmpty ? null : text;
}

DateTime _requiredDateTime(Map<String, dynamic> json, String key) {
  final parsed = _optionalDateTime(json[key]);
  if (parsed == null) throw FormatException('Missing or invalid "$key"');
  return parsed;
}

DateTime? _optionalDateTime(Object? value) {
  if (value == null) return null;
  final text = value.toString().trim();
  if (text.isEmpty) return null;
  // DateTime.parse honours the UTC offset; convert once to device-local time.
  return DateTime.parse(text).toLocal();
}

/// The fields captured by the registration / edit form. Identity fields go to
/// the visitor record, project and purpose belong to a visit.
class VisitorDraft extends Equatable {
  const VisitorDraft({
    required this.name,
    required this.mobile,
    required this.visitorType,
    required this.project,
    required this.purpose,
    this.email,
  });

  final String name;
  final String mobile;
  final String? email;
  final VisitorType visitorType;
  final String project;
  final String purpose;

  /// Body for POST /visitors. The server generates the id.
  Map<String, dynamic> toVisitorCreateJson(DateTime createdAt) => {
        ...toVisitorUpdateJson(),
        'created_at': toIso8601WithOffset(createdAt),
      };

  /// Body for PATCH /visitors/{id}: identity only.
  Map<String, dynamic> toVisitorUpdateJson() => {
        'name': name.trim(),
        'mobile': mobile.trim(),
        'email': (email == null || email!.trim().isEmpty) ? null : email!.trim(),
        'visitor_type': visitorType.label,
      };

  /// Body for PATCH /visits/{id} when editing an unfinished visit: never
  /// touches status or timestamps.
  Map<String, dynamic> toVisitUpdateJson() => {
        'project': project.trim(),
        'purpose': purpose.trim(),
      };

  @override
  List<Object?> get props => [name, mobile, email, visitorType, project, purpose];
}

/// Extracts a visitor ID from raw QR content, or null when it cannot be one.
/// The QR payload is the bare ID, so anything with spaces, URLs or other
/// punctuation is rejected before any network request is made.
String? parseVisitorId(String? raw) {
  final text = raw?.trim() ?? '';
  return _visitorIdPattern.hasMatch(text) ? text : null;
}

final RegExp _visitorIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
