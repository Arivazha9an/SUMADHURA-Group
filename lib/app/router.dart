import 'package:flutter/material.dart';

import '../features/qr_scanner/presentation/scanner_page.dart';
import '../features/visitors/domain/visitor.dart';
import '../features/visitors/presentation/pages/visitor_details_page.dart';
import '../features/visitors/presentation/pages/visitor_form_page.dart';

/// Plain Navigator helpers. With five screens and no deep links, typed
/// functions are simpler and safer than string routes.
class AppRouter {
  const AppRouter._();

  static Future<void> openDetails(BuildContext context, String visitorId) {
    return Navigator.of(context).push<void>(_detailsRoute(visitorId));
  }

  /// Used after registration so Back returns to where the user started,
  /// not to the now-finished form.
  static Future<void> replaceWithDetails(
    BuildContext context,
    String visitorId,
  ) {
    return Navigator.of(context).pushReplacement<void, void>(
      _detailsRoute(visitorId),
    );
  }

  /// Registration when [visitor] is null, editing otherwise.
  static Future<void> openForm(BuildContext context, {Visitor? visitor}) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => VisitorFormPage(visitor: visitor),
      ),
    );
  }

  static Future<void> openScanner(BuildContext context) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute<void>(builder: (_) => const ScannerPage()),
    );
  }

  static Route<void> _detailsRoute(String visitorId) {
    return MaterialPageRoute<void>(
      builder: (_) => VisitorDetailsPage(visitorId: visitorId),
    );
  }
}
