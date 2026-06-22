import 'package:flutter/material.dart';

import '../di/service_locator.dart';
import '../../features/authentication/presentation/auth_gate_page.dart';

class AppRouter {
  Route<dynamic> onGenerateRoute(RouteSettings settings) {
    return MaterialPageRoute(
      builder: (_) => AuthGatePage(
        appState: ServiceLocator.instance.appState,
        apiClient: ServiceLocator.instance.apiClient,
      ),
    );
  }
}
