import 'package:flutter/material.dart';

import '../tracker.dart';
import 'food_page.dart';
import 'progress_page.dart';
import 'today_page.dart';
import 'walk_page.dart';

/// Lets any screen switch tabs (e.g. "Start walk" on Today).
final tabIndex = ValueNotifier<int>(0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  @override
  void initState() {
    super.initState();
    if (WalkTracker.instance.active) tabIndex.value = 1;
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: tabIndex,
      builder: (context, i, _) => Scaffold(
        body: IndexedStack(
          index: i,
          children: const [TodayPage(), WalkPage(), FoodPage(), ProgressPage()],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: WalkTracker.instance,
          builder: (context, _) {
            final walking = WalkTracker.instance.active;
            return NavigationBar(
              selectedIndex: i,
              onDestinationSelected: (v) => tabIndex.value = v,
              destinations: [
                const NavigationDestination(
                    icon: Icon(Icons.today_outlined),
                    selectedIcon: Icon(Icons.today),
                    label: 'Today'),
                NavigationDestination(
                    icon: Badge(
                        isLabelVisible: walking,
                        child: const Icon(Icons.directions_walk_outlined)),
                    selectedIcon: Badge(
                        isLabelVisible: walking,
                        child: const Icon(Icons.directions_walk)),
                    label: 'Walk'),
                const NavigationDestination(
                    icon: Icon(Icons.restaurant_outlined),
                    selectedIcon: Icon(Icons.restaurant),
                    label: 'Food'),
                const NavigationDestination(
                    icon: Icon(Icons.insights_outlined),
                    selectedIcon: Icon(Icons.insights),
                    label: 'Progress'),
              ],
            );
          },
        ),
      ),
    );
  }
}
