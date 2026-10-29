import 'package:flutter/material.dart';

import '../core/widgets/glass.dart';
import '../features/dashboard/presentation/dashboard_page.dart';
import '../features/visitors/presentation/pages/visitor_list_page.dart';
import 'router.dart';

/// Hosts the Dashboard and Visitors tabs. "Scan" opens the camera screen as a
/// separate route (instead of a tab) so the camera is only held while the
/// scanner is actually on screen.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  static const int _dashboardTab = 0;
  static const int _visitorsTab = 1;
  static const int _scanTab = 2;

  int _index = _dashboardTab;

  void _onSelected(int index) {
    if (index == _scanTab) {
      AppRouter.openScanner(context);
      return;
    }
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    return GlassScaffold(
      extendBody: true,
      body: IndexedStack(
        index: _index,
        children: [
          DashboardPage(
            onViewAllVisitors: () => setState(() => _index = _visitorsTab),
          ),
          const VisitorListPage(),
        ],
      ),
      bottomNavigationBar: GlassNavBar(
        selectedIndex: _index,
        onSelected: _onSelected,
        items: const [
          GlassNavItem(
            icon: Icons.dashboard_outlined,
            selectedIcon: Icons.dashboard,
            label: 'Dashboard',
          ),
          GlassNavItem(
            icon: Icons.groups_outlined,
            selectedIcon: Icons.groups,
            label: 'Visitors',
          ),
          GlassNavItem(
            icon: Icons.qr_code_scanner,
            selectedIcon: Icons.qr_code_scanner,
            label: 'Scan',
          ),
        ],
      ),
    );
  }
}
