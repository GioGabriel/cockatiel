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

  late final List<Widget> _pages;

  @override
  void initState() {
    super.initState();
    _pages = [
      HomeDashboardPage(
        appState: widget.appState,
        apiClient: widget.apiClient,
      ),
      VocalTrainingPage(
        apiClient: widget.apiClient,
        appState: widget.appState,
      ),
      KaraokePracticePage(
        apiClient: widget.apiClient,
        appState: widget.appState,
      ),
      UserProfilePage(
        appState: widget.appState,
        apiClient: widget.apiClient,
      ),
    ];
  }

  void _onTabSelected(int index) {
    if (index == _currentIndex) return;
    setState(() {
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
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: _pages,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: _onTabSelected,
          labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.mic_none_rounded),
              selectedIcon: Icon(Icons.mic_rounded),
              label: 'Training',
            ),
            NavigationDestination(
              icon: Icon(Icons.music_note_outlined),
              selectedIcon: Icon(Icons.music_note_rounded),
              label: 'Karaoke',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// Notification used by child pages to request a tab switch.
class TabSwitchNotification extends Notification {
  TabSwitchNotification(this.tabIndex);
  final int tabIndex;
}
