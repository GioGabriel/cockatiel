import '../../core/auth/auth_token_provider.dart';
import '../../core/config/app_config.dart';
import '../../core/network/api_client.dart';
import '../../core/state/app_state.dart';

class ServiceLocator {
  ServiceLocator._();

  static final ServiceLocator instance = ServiceLocator._();

  late final AuthTokenProvider authTokenProvider = FirebaseAuthTokenProvider(
    useDevAuthToken: appConfig.useDevAuthToken,
  );
  late final ApiClient apiClient = ApiClient(
    config: appConfig,
    tokenProvider: authTokenProvider,
  );
  late final AppState appState = AppState();
}
