import 'package:flutter/material.dart';

import '../../../core/network/api_client.dart';
import '../../../core/state/app_state.dart';
import 'karaoke_catalog_page.dart';

class KaraokePracticePage extends StatelessWidget {
  const KaraokePracticePage({
    super.key,
    required this.apiClient,
    required this.appState,
  });

  final ApiClient apiClient;
  final AppState appState;

  Widget build(BuildContext context) {
    return KaraokeCatalogPage(
      apiClient: apiClient,
      appState: appState,
    );
  }
}
