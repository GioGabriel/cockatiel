import 'package:flutter/material.dart';

import '../../core/network/api_client.dart';
import '../../core/state/app_state.dart';
import '../../features/home_dashboard/presentation/home_dashboard_page.dart';
import '../../features/karaoke_practice/presentation/karaoke_practice_page.dart';
import '../../features/user_profile/presentation/user_profile_page.dart';
import '../../features/vocal_training/presentation/vocal_training_page.dart';

/// Main app shell with bottom navigation bar.
///
/// Provides persistent tab navigation between the four thesis modules:
/// - Home (Dashboard Module)
/// - Training (Voice Room + Coaching/Tutorial Module)
/// - Karaoke (Karaoke Module)
/// - Profile (Account Module + Progress Tracking)
class MainShellPage extends StatefulWidget {
  const MainShellPage({
    super.key,
    required this.appState,
    required this.apiClient,
  });

  final AppState appState;
  final ApiClient apiClient;

  @override
  State<MainShellPage> createState() => _MainShellPageState();
}

class _MainShellPageState extends State<MainShellPage> {
  int _currentIndex = 0;

  late final List<Widget?> _pages;

  @override
  void initState() {
    super.initState();
    // Keep only the visible tab mounted initially. IndexedStack preserves the
    // state of pages that have been opened, while lazy construction avoids
    // firing four independent API loads during authentication bootstrap.
    _pages = List<Widget?>.filled(4, null);
    _pages[0] = _buildPage(0);
  }

  Widget _buildPage(int index) {
    return switch (index) {
      0 => HomeDashboardPage(
          appState: widget.appState,
          apiClient: widget.apiClient,
        ),
      1 => VocalTrainingPage(
          apiClient: widget.apiClient,
          appState: widget.appState,
        ),
      2 => KaraokePracticePage(
          apiClient: widget.apiClient,
          appState: widget.appState,
        ),
      3 => UserProfilePage(
          appState: widget.appState,
          apiClient: widget.apiClient,
        ),
      _ => const SizedBox.shrink(),
    };
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
      _pages[index] ??= _buildPage(index);
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: (notification) {
        if (notification is TabSwitchNotification) {
          _onTabSelected(notification.tabIndex);
          return true;
        }
        return false;
      },
      child: LayoutBuilder(builder: (context, constraints) {
        final wide = constraints.maxWidth >= 1000;
        final content = IndexedStack(index: _currentIndex, children: [
          for (final page in _pages) page ?? const SizedBox.shrink(),
        ]);
        const destinations = [
          NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon: Icon(Icons.space_dashboard_rounded),
              label: 'Home',
              tooltip: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.graphic_eq_rounded),
              label: 'Train',
              tooltip: 'Train'),
          NavigationDestination(
              icon: Icon(Icons.library_music_outlined),
              selectedIcon: Icon(Icons.library_music_rounded),
              label: 'Songs',
              tooltip: 'Songs'),
          NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
              tooltip: 'Profile'),
        ];
        if (wide) {
          return Scaffold(
              body: Row(children: [
            NavigationRail(
              backgroundColor: Theme.of(context).colorScheme.surface,
              selectedIndex: _currentIndex,
              onDestinationSelected: _onTabSelected,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Icon(Icons.graphic_eq_rounded, size: 28)),
              destinations: [
                for (final item in destinations)
                  NavigationRailDestination(
                      icon: item.icon,
                      selectedIcon: item.selectedIcon,
                      label: Text(item.label))
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: content),
          ]));
        }
        return Scaffold(
          body: content,
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: _onTabSelected,
            backgroundColor: Theme.of(context).colorScheme.surface,
            indicatorColor: Theme.of(context).colorScheme.primaryContainer,
            labelBehavior: MediaQuery.textScalerOf(context).scale(1) > 1.4
                ? NavigationDestinationLabelBehavior.alwaysHide
                : NavigationDestinationLabelBehavior.alwaysShow,
            destinations: destinations,
          ),
        );
      }),
    );
  }
}

/// Notification used by child pages to request a tab switch.
class TabSwitchNotification extends Notification {
  TabSwitchNotification(this.tabIndex);
  final int tabIndex;
}
