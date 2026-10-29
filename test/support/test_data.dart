import 'package:visitor_management/features/visitors/domain/visitor.dart';

/// Builds one visit session; override only what a test needs.
Visit buildVisit({
  String id = 'v1',
  String visitorId = '1',
  String project = 'Project A',
  String purpose = 'Site Visit',
  VisitorStatus status = VisitorStatus.registered,
  DateTime? createdAt,
  DateTime? checkInTime,
  DateTime? checkOutTime,
}) {
  return Visit(
    id: id,
    visitorId: visitorId,
    project: project,
    purpose: purpose,
    status: status,
    createdAt: createdAt ?? DateTime(2026, 10, 27, 9),
    checkInTime: checkInTime,
    checkOutTime: checkOutTime,
  );
}

/// Builds a visitor with sensible defaults; override only what a test needs.
///
/// The visit fields (project, purpose, status, times) describe ONE visit with
/// id `v<visitorId>`. Pass [visits] to build a returning visitor with several
/// sessions instead; the visit fields are then ignored.
Visitor buildVisitor({
  String id = '1',
  String name = 'Rahul Sharma',
  String mobile = '9876543210',
  String? email = 'rahul@example.com',
  VisitorType type = VisitorType.customer,
  String project = 'Project A',
  String purpose = 'Site Visit',
  VisitorStatus status = VisitorStatus.registered,
  DateTime? createdAt,
  DateTime? checkInTime,
  DateTime? checkOutTime,
  List<Visit>? visits,
}) {
  final created = createdAt ?? DateTime(2026, 10, 27, 9);
  return Visitor(
    id: id,
    name: name,
    mobile: mobile,
    email: email,
    visitorType: type,
    createdAt: created,
    visits: visits ??
        [
          buildVisit(
            id: 'v$id',
            visitorId: id,
            project: project,
            purpose: purpose,
            status: status,
            createdAt: created,
            checkInTime: checkInTime,
            checkOutTime: checkOutTime,
          ),
        ],
  );
}

const VisitorDraft sampleDraft = VisitorDraft(
  name: 'Meera Iyer',
  mobile: '9845012345',
  visitorType: VisitorType.customer,
  project: 'Project B',
  purpose: 'Agreement signing',
);
