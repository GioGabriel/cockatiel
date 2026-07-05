import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/session_models.dart';
import '../network/api_client.dart';
import '../notifications/notification_service.dart';
import '../../shared/models/user_models.dart';

class AppState extends ChangeNotifier {
  AppState({
    FirebaseAuth? firebaseAuth,
    NotificationService? notificationService,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _notificationService =
            notificationService ?? NotificationService.instance;

  final FirebaseAuth _firebaseAuth;
  final NotificationService _notificationService;
  StreamSubscription<User?>? _authSubscription;
  Timer? _aiJobsPollTimer;
  ApiClient? _apiClient;

  bool _hasInitialized = false;
  bool _isBootstrapping = true;
  bool _isAuthenticating = false;
  bool _isSendingPasswordReset = false;
  bool _isRefreshingAIJobs = false;
  UserProfile? _currentUser;
  AccessTier _accessTier = AccessTier.registered; // ignore: prefer_final_fields
  String? _authError;
  String? _authNotice;
  List<AIJob> _aiJobs = const [];

  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticating => _isAuthenticating;
  bool get isSendingPasswordReset => _isSendingPasswordReset;
  bool get isAuthenticated => _currentUser != null;
  bool get isGuest => !isAuthenticated;
  bool get isRefreshingAIJobs => _isRefreshingAIJobs;
  UserProfile? get currentUser => _currentUser;
  AccessTier get accessTier => isAuthenticated ? _accessTier : AccessTier.guest;
  String? get authError => _authError;
  String? get authNotice => _authNotice;
  List<AIJob> get aiJobs => List.unmodifiable(_aiJobs);
  int get pendingAIJobsCount => _aiJobs
      .where((job) => job.state == 'queued' || job.state == 'processing')
      .length;

  Future<void> initialize(ApiClient apiClient) async {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;
    _apiClient = apiClient;
    _isBootstrapping = true;
    await _notificationService.initialize();
    notifyListeners();

    _authSubscription = _firebaseAuth.authStateChanges().listen(
      (user) {
        _syncCurrentUser(user, apiClient);
      },
    );

    await _syncCurrentUser(_firebaseAuth.currentUser, apiClient);
  }

  Future<void> signInWithEmailPassword({
    required ApiClient apiClient,
    required String email,
    required String password,
  }) async {
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    _authError = null;
    _authNotice = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await _syncCurrentUser(credential.user, apiClient);
    } on FirebaseAuthException catch (error) {
      _currentUser = null;
      _authError = _authMessageForCode(error.code);
    } catch (_) {
      _currentUser = null;
      _authError = 'Unable to sign in right now. Please try again.';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> signUpWithEmailPassword({
    required ApiClient apiClient,
    required String email,
    required String password,
    required String displayName,
  }) async {
    if (_isAuthenticating) {
      return;
    }

    _isAuthenticating = true;
    _authError = null;
    _authNotice = null;
    notifyListeners();

    try {
      final credential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final trimmedName = displayName.trim();
      if (trimmedName.isNotEmpty) {
        await credential.user?.updateDisplayName(trimmedName);
      }
      await _syncCurrentUser(credential.user, apiClient);
    } on FirebaseAuthException catch (error) {
      _currentUser = null;
      _authError = _authMessageForCode(error.code);
    } catch (_) {
      _currentUser = null;
      _authError = 'Unable to create your account right now. Please try again.';
    } finally {
      _isAuthenticating = false;
      notifyListeners();
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    if (_isSendingPasswordReset) {
      return;
    }

    _isSendingPasswordReset = true;
    _authError = null;
    _authNotice = null;
    notifyListeners();

    try {
      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
      _authNotice = 'Password reset link sent. Check your email inbox.';
    } on FirebaseAuthException catch (error) {
      _authError = _authMessageForCode(error.code);
    } catch (_) {
      _authError = 'Unable to send reset email. Please try again.';
    } finally {
      _isSendingPasswordReset = false;
      notifyListeners();
    }
  }

  void clearAuthMessages() {
    _authError = null;
    _authNotice = null;
    notifyListeners();
  }

  Future<void> signOut() async {
    _authError = null;
    _authNotice = null;
    await _firebaseAuth.signOut();
    _currentUser = null;
    _aiJobs = const [];
    _stopAIJobsPolling();
    notifyListeners();
  }

  Future<void> refreshAIJobs() async {
    final apiClient = _apiClient;
    if (apiClient == null || !isAuthenticated || _isRefreshingAIJobs) {
      return;
    }

    _isRefreshingAIJobs = true;
    notifyListeners();

    try {
      final previousById = {for (final item in _aiJobs) item.jobId: item};
      final latest = await apiClient.fetchAIJobs();
      _aiJobs = latest;

      for (final job in latest) {
        final previous = previousById[job.jobId];
        if (previous == null || previous.state == job.state) {
          continue;
        }
        if (job.state == 'completed') {
          await _notificationService.showAnalysisCompleted(
            sessionId: job.sessionId,
            exerciseType: job.exerciseType,
          );
        } else if (job.state == 'failed') {
          await _notificationService.showAnalysisFailed(
            sessionId: job.sessionId,
            exerciseType: job.exerciseType,
          );
        }
      }
    } catch (_) {
      // Non-blocking background refresh.
    } finally {
      _isRefreshingAIJobs = false;
      notifyListeners();
    }
  }

  Future<void> _syncCurrentUser(User? user, ApiClient apiClient) async {
    if (user == null) {
      _currentUser = null;
      _aiJobs = const [];
      _stopAIJobsPolling();
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    try {
      final profile = await apiClient.fetchCurrentUser();
      final effectiveName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : profile.name;
      final effectiveEmail = (user.email ?? '').trim().isNotEmpty
          ? user.email!.trim()
          : profile.email;
      _currentUser = UserProfile(
        uid: profile.uid,
        email: effectiveEmail,
        name: effectiveName,
      );
      _authError = null;
      _startAIJobsPolling();
      await refreshAIJobs();
    } catch (_) {
      _currentUser = null;
      _aiJobs = const [];
      _stopAIJobsPolling();
      _authError = 'Authenticated, but failed to load profile from backend.';
    } finally {
      _isBootstrapping = false;
      notifyListeners();
    }
  }

  void _startAIJobsPolling() {
    _stopAIJobsPolling();
    _aiJobsPollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => refreshAIJobs(),
    );
  }

  void _stopAIJobsPolling() {
    _aiJobsPollTimer?.cancel();
    _aiJobsPollTimer = null;
  }

  String _authMessageForCode(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
        return 'Email or password is incorrect.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'weak-password':
        return 'Use a stronger password (at least 6 characters).';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network unavailable. Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopAIJobsPolling();
    super.dispose();
  }
}
