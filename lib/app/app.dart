import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/config/api_config.dart';
import '../core/network/connectivity_checker.dart';
import '../core/network/connectivity_cubit.dart';
import '../core/network/dio_client.dart';
import '../core/widgets/offline_banner.dart';
import '../features/visitors/data/visitor_repository.dart';
import '../features/visitors/presentation/cubit/visitors_cubit.dart';
import 'app_shell.dart';
import 'setup_required_page.dart';
import 'theme/app_theme.dart';

class VisitorApp extends StatelessWidget {
  /// [repository] is injectable for widget tests; production uses the API.
  const VisitorApp({super.key, this.repository, this.connectivityChecker});

  final VisitorRepository? repository;

  /// Injectable for tests. When null, production probes the API host; with an
  /// injected [repository] (tests) no probing happens.
  final ConnectivityChecker? connectivityChecker;

  static const String _title = 'Visitor Desk';

  @override
  Widget build(BuildContext context) {
    if (repository == null && !ApiConfig.isConfigured) {
      return MaterialApp(
        title: _title,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        home: const SetupRequiredPage(),
      );
    }

    final checker = connectivityChecker ??
        (repository == null ? SocketConnectivityChecker.forApi() : null);

    // One cubit for the whole app: dashboard, list and details all read the
    // same visitor data, so they can never disagree. Both providers sit above
    // MaterialApp so every pushed route can read them.
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) => VisitorsCubit(
            repository ?? ApiVisitorRepository(createDioClient()),
          )..load(),
        ),
        BlocProvider(create: (_) => ConnectivityCubit(checker)),
      ],
      child: Builder(
        builder: (providerContext) => MaterialApp(
          title: _title,
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          builder: (context, child) => ConnectivityHost(
            // Back online: reload so the screens stop showing stale data.
            onReconnected: () =>
                unawaited(providerContext.read<VisitorsCubit>().load()),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const AppShell(),
        ),
      ),
    );
  }
}
