import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import 'karaoke_session_setup_page.dart';

class KaraokePracticePage extends StatelessWidget {
  const KaraokePracticePage({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return KaraokeSessionSetupPage(
      apiClient: apiClient,
      appState: appState,
      title: 'Karaoke Practice',
      exerciseOptions: const [
        'karaoke_pop_hook',
        'karaoke_ballad_phrase',
        'karaoke_timing_focus',
      ],
    );
  }
}
