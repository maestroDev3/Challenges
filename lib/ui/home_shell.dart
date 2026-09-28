import 'package:flutter/material.dart';

import '../domain/active_challenge.dart';
import '../domain/challenge_repository.dart';
import 'catalog_screen.dart';
import 'today_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({
    super.key,
    required this.repository,
    this.clock = DateTime.now,
    this.onStarted,
    this.onStopped,
  });

  final ChallengeRepository repository;
  final Clock clock;
  final ChallengeStarted? onStarted;
  final Future<void> Function(ActiveChallenge challenge)? onStopped;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    _lifecycle = AppLifecycleListener(
      onResume: () {
        widget.repository.refresh();
        setState(() {}); // neues „Heute“, falls über Mitternacht
      },
    );
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: [
          TodayScreen(
            repository: widget.repository,
            clock: widget.clock,
            onDiscover: () => setState(() => _tab = 1),
            onStopped: widget.onStopped,
          ),
          CatalogScreen(
            repository: widget.repository,
            onStarted: (c) async {
              await widget.onStarted?.call(c);
              if (mounted) setState(() => _tab = 0);
            },
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.local_fire_department_outlined),
            selectedIcon: Icon(Icons.local_fire_department),
            label: 'Heute',
          ),
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Entdecken',
          ),
        ],
      ),
    );
  }
}
