import 'package:flutter/material.dart';

import '../router/app_router.dart';
import '../theme/app_theme.dart';

class AppBootstrap extends StatelessWidget {
  const AppBootstrap({super.key});

  @override
  Widget build(BuildContext context) {
    final router = AppRouter();
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Cockatiel',
      theme: AppTheme.dark(),
      darkTheme: AppTheme.dark(),
      themeMode: ThemeMode.dark,
      onGenerateRoute: router.onGenerateRoute,
    );
  }
}
