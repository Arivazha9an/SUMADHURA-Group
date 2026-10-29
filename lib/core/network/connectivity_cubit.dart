import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import 'connectivity_checker.dart';

enum ConnectionStatus { online, offline }

/// Tracks whether the API is reachable and exposes it to the whole app.
///
/// - Starts as [ConnectionStatus.online] so the banner does not flash on launch.
/// - Probes every [pollInterval] while the app is in the foreground
///   ([pause] / [resume] are called from the app lifecycle).
/// - Goes offline only after [failuresBeforeOffline] failed probes in a row,
///   so one dropped packet does not flicker the banner; goes online as soon
///   as one probe succeeds.
/// - With a null [checker] it never probes (used in widget tests).
class ConnectivityCubit extends Cubit<ConnectionStatus> {
  ConnectivityCubit(
    this._checker, {
    this.pollInterval = const Duration(seconds: 5),
    this.failuresBeforeOffline = 2,
  }) : super(ConnectionStatus.online) {
    resume();
  }

  final ConnectivityChecker? _checker;
  final Duration? pollInterval;
  final int failuresBeforeOffline;

  Timer? _timer;
  bool _checking = false;
  int _failures = 0;

  /// Probes once now. Overlapping calls are ignored.
  Future<void> check() async {
    final checker = _checker;
    if (checker == null || _checking || isClosed) return;
    _checking = true;
    try {
      final reachable = await checker.isReachable();
      if (isClosed) return;
      if (reachable) {
        _failures = 0;
        emit(ConnectionStatus.online);
      } else {
        _failures++;
        if (_failures >= failuresBeforeOffline) emit(ConnectionStatus.offline);
      }
    } finally {
      _checking = false;
    }
  }

  /// Starts probing (immediately, then every [pollInterval]).
  void resume() {
    final interval = pollInterval;
    if (_checker == null || interval == null) return;
    _timer?.cancel();
    unawaited(check());
    _timer = Timer.periodic(interval, (_) => unawaited(check()));
  }

  /// Stops probing, e.g. while the app is in the background.
  void pause() {
    _timer?.cancel();
    _timer = null;
  }

  @override
  Future<void> close() {
    pause();
    return super.close();
  }
}
