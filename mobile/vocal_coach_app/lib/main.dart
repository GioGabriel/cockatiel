import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'app/bootstrap/app_bootstrap.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initializeFirebase();
  _configureFirebaseAuth();
  await NotificationService.instance.initialize();
  runApp(const AppBootstrap());
}

Future<void> _initializeFirebase() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on UnsupportedError {
    // Firebase options are currently configured for Android and iOS only.
  }
}

void _configureFirebaseAuth() {
  if (!appConfig.useFirebaseAuthEmulator) {
    return;
  }
  FirebaseAuth.instance.useAuthEmulator(
    appConfig.firebaseAuthEmulatorHost,
    appConfig.firebaseAuthEmulatorPort,
  );
}
