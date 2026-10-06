import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

import 'sync_service.dart';

class SyncListener extends StatefulWidget {
  final SyncService syncService;
  final Widget child;

  const SyncListener({
    super.key,
    required this.syncService,
    required this.child,
  });

  @override
  State<SyncListener> createState() =>
      _SyncListenerState();
}

class _SyncListenerState extends State<SyncListener> {
  StreamSubscription<List<ConnectivityResult>>?
  _subscription;

  Timer? _syncTimer;

  @override
  void initState() {
    super.initState();

    // محاولة مزامنة عند فتح التطبيق.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.syncService.syncPendingSales();
    });

    // محاولة مزامنة فور تغيّر الاتصال ووجود شبكة.
    _subscription = Connectivity()
        .onConnectivityChanged
        .listen((results) {
      final hasNetwork = results.any(
            (result) =>
        result != ConnectivityResult.none,
      );

      if (hasNetwork) {
        widget.syncService.syncPendingSales();
      }
    });

    // Fallback:
    // محاولة دورية حتى لو حدث رجوع الشبكة لم يصل بشكل صحيح.
    _syncTimer = Timer.periodic(
      const Duration(seconds: 30),
          (_) {
        widget.syncService.syncPendingSales();
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _syncTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}