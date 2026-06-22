import 'package:firebase_auth/firebase_auth.dart';

abstract class AuthTokenProvider {
  Future<String> getToken();
}

class FirebaseAuthTokenProvider implements AuthTokenProvider {
  FirebaseAuthTokenProvider({
    FirebaseAuth? firebaseAuth,
    required bool useDevAuthToken,
  })  : _firebaseAuth = firebaseAuth ?? FirebaseAuth.instance,
        _useDevAuthToken = useDevAuthToken;

  final FirebaseAuth _firebaseAuth;
  final bool _useDevAuthToken;

  @override
  Future<String> getToken() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw StateError('No authenticated Firebase user.');
    }
    if (_useDevAuthToken) {
      return 'dev_${user.uid}';
    }

    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw StateError('Unable to resolve Firebase ID token.');
    }
    return token;
  }
}
