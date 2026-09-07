import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../../shared/models/session_models.dart';
import '../network/api_client.dart';
import '../notifications/notification_service.dart';
import '../../shared/models/user_models.dart';

/// Builds the minimum local account model available from Firebase Auth.
///
/// Authentication and persistent profile storage are separate dependencies.
/// Keeping this fallback lets a user reach the app during a temporary API or
/// Firestore outage without inventing progress, preferences, or scores.
UserProfileFull buildLocalProfile({
  required String uid,
  String? email,
  String? displayName,
}) {
  final normalizedEmail = (email ?? '').trim();
  final normalizedName = (displayName ?? '').trim();
  return UserProfileFull(
    uid: uid,
    email: normalizedEmail,
    name: normalizedName.isEmpty ? 'Singer' : normalizedName,
    accessTier: AccessTier.registered,
  );
}

/// Returns whether the client needs another status check for AI feedback.
/// Terminal jobs are retained in memory for the queue screen, but they do not
/// justify a background request once processing has finished.
bool shouldPollAIJobs(Iterable<AIJob> jobs) {
  return jobs.any(
    (job) =>
        job.state == 'pending_enqueue' ||
        job.state == 'queued' ||
        job.state == 'processing',
  );
}

/// Prevents an async response started for one Firebase account from being
/// applied after sign-out or account switching.
bool isCurrentAccountRequest({
  required String? requestUid,
  required String? currentUid,
}) {
  return requestUid != null && requestUid == currentUid;
}

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
  bool _isProfileReady = false;
  UserProfileFull? _currentUser;
  AccessTier _accessTier = AccessTier.registered; // ignore: prefer_final_fields
  String? _authError;
  String? _authNotice;
  String? _accountDataNotice;
  List<AIJob> _aiJobs = const [];
  Future<void>? _syncInFlight;
  String? _syncInFlightUid;

  bool get isBootstrapping => _isBootstrapping;
  bool get isAuthenticating => _isAuthenticating;
  bool get isSendingPasswordReset => _isSendingPasswordReset;
  bool get isAuthenticated => _currentUser != null;
  bool get isProfileReady => _isProfileReady;
  bool get isGuest => !isAuthenticated;
  bool get isRefreshingAIJobs => _isRefreshingAIJobs;
  UserProfileFull? get currentUser => _currentUser;
  AccessTier get accessTier => isAuthenticated ? _accessTier : AccessTier.guest;
  String? get authError => _authError;
  String? get authNotice => _authNotice;
  String? get accountDataNotice => _accountDataNotice;
  List<AIJob> get aiJobs => List.unmodifiable(_aiJobs);
  int get pendingAIJobsCount => _aiJobs
      .where((job) => job.state == 'queued' || job.state == 'processing')
      .length;

  /// Applies a profile returned by the API without re-authenticating.
  ///
  /// This is used after first-run voice setup so the auth gate can immediately
  /// transition to the main shell while preserving the server as the source of truth.
  void updateCurrentUserProfile(UserProfileFull profile) {
    _currentUser = profile;
    _accessTier = profile.accessTier;
    _isProfileReady = true;
    _accountDataNotice = null;
    notifyListeners();
  }

  Future<void> initialize(ApiClient apiClient) async {
    if (_hasInitialized) {
      return;
    }
    _hasInitialized = true;
    _apiClient = apiClient;
    _isBootstrapping = true;
    unawaited(apiClient.pingBackend());
    await _notificationService.initialize();
    notifyListeners();

    _authSubscription = _firebaseAuth.authStateChanges().listen(
      (user) {
        unawaited(_syncCurrentUser(user, apiClient));
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
      // Firebase Auth is the login authority. Do not keep the user staring at
      // a spinner while a secondary profile store is rate-limited or slow.
      await _syncCurrentUser(credential.user, apiClient).timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
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
      await _syncCurrentUser(credential.user, apiClient).timeout(
        const Duration(seconds: 5),
        onTimeout: () {},
      );
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
    _isProfileReady = false;
    _accountDataNotice = null;
    _aiJobs = const [];
    _stopAIJobsPolling();
    notifyListeners();
  }

  Future<void> refreshAIJobs() async {
    final apiClient = _apiClient;
    final requestUid = _firebaseAuth.currentUser?.uid;
    if (apiClient == null ||
        !isAuthenticated ||
        requestUid == null ||
        _isRefreshingAIJobs) {
      return;
    }

    _isRefreshingAIJobs = true;
    notifyListeners();

    try {
      final previousById = {for (final item in _aiJobs) item.jobId: item};
      final latest = await apiClient.fetchAIJobs();
      if (!isCurrentAccountRequest(
        requestUid: requestUid,
        currentUid: _firebaseAuth.currentUser?.uid,
      )) {
        return;
      }
      _aiJobs = latest;

      if (shouldPollAIJobs(latest)) {
        _startAIJobsPolling();
      } else {
        _stopAIJobsPolling();
      }

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

  /// Re-attempts the server-side profile without signing the user out.
  Future<void> retryAccountData() async {
    final apiClient = _apiClient;
    if (apiClient == null) return;
    await _syncCurrentUser(_firebaseAuth.currentUser, apiClient);
  }

  Future<void> _syncCurrentUser(User? user, ApiClient apiClient) {
    final uid = user?.uid;
    if (_syncInFlight != null && _syncInFlightUid == uid) {
      return _syncInFlight!;
    }

    final future = _syncCurrentUserInternal(user, apiClient);
    _syncInFlight = future;
    _syncInFlightUid = uid;
    unawaited(
      future.then<void>(
        (_) {
          if (identical(_syncInFlight, future)) {
            _syncInFlight = null;
            _syncInFlightUid = null;
          }
        },
        onError: (_, __) {
          if (identical(_syncInFlight, future)) {
            _syncInFlight = null;
            _syncInFlightUid = null;
          }
        },
      ),
    );
    return future;
  }

  Future<void> _syncCurrentUserInternal(User? user, ApiClient apiClient) async {
    if (user == null) {
      _currentUser = null;
      _isProfileReady = false;
      _accountDataNotice = null;
      _aiJobs = const [];
      _stopAIJobsPolling();
      _isBootstrapping = false;
      notifyListeners();
      return;
    }

    // Publish the Firebase identity immediately. The persistent profile is a
    // second phase and must never turn a valid password into a login failure.
    _currentUser = buildLocalProfile(
      uid: user.uid,
      email: user.email,
      displayName: user.displayName,
    );
    _accessTier = AccessTier.registered;
    _isProfileReady = false;
    _accountDataNotice = null;
    _authError = null;
    notifyListeners();

    try {
      // First, hit /auth/me to guarantee the user is upserted in the backend database
      await apiClient.fetchCurrentUser();

      // Then fetch the full profile which contains vocal_preferences
      final profile = await apiClient.fetchFullProfile();

      if (!_isCurrentFirebaseUser(user.uid)) {
        return;
      }

      final effectiveName = (user.displayName ?? '').trim().isNotEmpty
          ? user.displayName!.trim()
          : profile.name;
      final effectiveEmail = (user.email ?? '').trim().isNotEmpty
          ? user.email!.trim()
          : profile.email;

      _currentUser = UserProfileFull(
        uid: profile.uid,
        email: effectiveEmail,
        name: effectiveName,
        accessTier: profile.accessTier,
        vocalPreferences: profile.vocalPreferences,
        premiumExpiresAt: profile.premiumExpiresAt,
      );
      _accessTier = _currentUser!.accessTier;
      _isProfileReady = true;
      _authError = null;
      _authNotice = null;

      // Fetch once after profile bootstrap. A recurring timer is started only
      // when the response contains an active queued/processing job.
      unawaited(refreshAIJobs());
    } on ApiException catch (error) {
      if (!_isCurrentFirebaseUser(user.uid)) {
        return;
      }
      _authError = _safeApiErrorMessage(error);
      _accountDataNotice = _accountDataMessage(error);
      _aiJobs = const [];
      _stopAIJobsPolling();
    } catch (_) {
      if (!_isCurrentFirebaseUser(user.uid)) {
        return;
      }
      _accountDataNotice =
          'You are signed in, but saved account data is temporarily unavailable. Please try again shortly.';
      _aiJobs = const [];
      _stopAIJobsPolling();
    } finally {
      if (_isCurrentFirebaseUser(user.uid)) {
        _isBootstrapping = false;
        notifyListeners();
      }
    }
  }

  bool _isCurrentFirebaseUser(String uid) {
    return isCurrentAccountRequest(
      requestUid: uid,
      currentUid: _firebaseAuth.currentUser?.uid,
    );
  }

  String _accountDataMessage(ApiException error) {
    switch (error.code) {
      case 'STORAGE_QUOTA_EXCEEDED':
        return 'You are signed in, but saved progress is temporarily unavailable. Your data has not been deleted. Please try again shortly.';
      case 'NETWORK_ERROR':
      case 'NETWORK_TIMEOUT':
        return 'You are signed in, but we cannot reach the account service. Check your connection and try again.';
      default:
        return 'You are signed in, but saved account data is temporarily unavailable. Please try again shortly.';
    }
  }

  void _startAIJobsPolling() {
    if (_aiJobsPollTimer != null) {
      return;
    }
    _aiJobsPollTimer?.cancel();
    _aiJobsPollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshAIJobs(),
    );
  }

  void _stopAIJobsPolling() {
    _aiJobsPollTimer?.cancel();
    _aiJobsPollTimer = null;
  }

  String _authMessageForCode(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'user-not-found':
      case 'wrong-password':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'weak-password':
        return 'Password must be at least 6 characters.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'network-request-failed':
        return 'Network unavailable. Check your internet connection.';
      default:
        return 'Authentication failed. Please try again.';
    }
  }

  String _safeApiErrorMessage(ApiException error) {
    switch (error.code) {
      case 'AUTH_INVALID':
      case 'AUTH_MISSING':
        return 'Your session has expired. Please sign in again.';
      case 'NETWORK_ERROR':
      case 'NETWORK_TIMEOUT':
        return 'We could not reach the server. Check your connection and try again.';
      default:
        return 'We could not load your account right now. Please try again.';
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _stopAIJobsPolling();
    super.dispose();
  }
}
