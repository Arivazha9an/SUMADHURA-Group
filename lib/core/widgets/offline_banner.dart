import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../network/connectivity_cubit.dart';

/// Wraps every screen (used as `MaterialApp.builder`) and shows a banner above
/// them while the API is unreachable. When the connection comes back,
/// [onReconnected] runs once, so data can be refreshed without user action.
///
/// It also pauses the connectivity probe while the app is in the background.
class ConnectivityHost extends StatefulWidget {
  const ConnectivityHost({
    super.key,
    required this.child,
    required this.onReconnected,
  });

  final Widget child;
  final VoidCallback onReconnected;

  @override
  State<ConnectivityHost> createState() => _ConnectivityHostState();
}

class _ConnectivityHostState extends State<ConnectivityHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final cubit = context.read<ConnectivityCubit>();
    if (state == AppLifecycleState.resumed) {
      cubit.resume();
    } else if (state == AppLifecycleState.paused) {
      cubit.pause();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ConnectivityCubit, ConnectionStatus>(
      listenWhen: (previous, current) =>
          previous == ConnectionStatus.offline &&
          current == ConnectionStatus.online,
      listener: (_, __) => widget.onReconnected(),
      builder: (context, status) {
        final offline = status == ConnectionStatus.offline;
        return Column(
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              alignment: Alignment.topCenter,
              child: offline
                  ? const _OfflineBanner()
                  : const SizedBox(width: double.infinity),
            ),
            Expanded(
              // The banner already covers the status bar, so the screens
              // below must not add that inset a second time.
              child: MediaQuery.removePadding(
                context: context,
                removeTop: offline,
                child: widget.child,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Material(
        color: scheme.error,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                Icon(Icons.wifi_off, size: 18, color: scheme.onError),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    "You're offline. Can't reach the server, so changes "
                    "can't be saved.",
                    style: TextStyle(
                      color: scheme.onError,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
