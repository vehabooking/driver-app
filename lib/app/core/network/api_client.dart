import 'package:get/get.dart';

import '../config/app_config.dart';
import '../storage/storage_service.dart';
import 'api_exception.dart';

/// App HTTP client — the standard GetConnect structure: it **extends
/// [GetConnect]** and configures the shared [httpClient] in [onInit].
///
/// On top of GetConnect it adds:
///   - a request modifier that injects the bearer token (kept in-memory,
///     mirrored to [StorageService] by AuthService) + the `Accept` and
///     `Content-Language` headers;
///   - a response modifier that resets the session on a 401 and bounces to
///     login;
///   - guarded [getJson]/[postJson] verbs that normalize every failure into an
///     [ApiException] and return the decoded body on success.
///
/// We intentionally skip `defaultDecoder` (models are decoded per-repository)
/// and `addAuthenticator` (Sanctum tokens don't refresh — a 401 means logout).
class ApiClient extends GetConnect {
  ApiClient(this._storage);

  final StorageService _storage;

  /// In-memory token, set by AuthService so the request modifier stays sync.
  String? token;

  /// Called on a 401 so the app can reset to the login screen. Wired by main()
  /// to avoid a hard dependency on the routing/auth layers from here.
  void Function()? onUnauthorized;

  @override
  void onInit() {
    httpClient
      ..timeout = AppConfig.receiveTimeout
      ..defaultContentType = 'application/json';

    // Attach the bearer token + Accept/Content-Language headers to every
    // request. The backend's ContentLanguage middleware maps `km_KH`/`en_US`
    // to the app locale so translatable fields come back in the user's language.
    httpClient.addRequestModifier<dynamic>((request) {
      request.headers['Accept'] = 'application/json';
      request.headers['Content-Language'] = _storage.locale ?? 'en_US';
      if (token != null && token!.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      return request;
    });

    // Reset the session on a 401 and bounce to login.
    httpClient.addResponseModifier<dynamic>((request, response) {
      if (response.statusCode == 401) {
        token = null;
        _storage.clearSecure();
        onUnauthorized?.call();
      }
      return response;
    });

    super.onInit();
  }

  // ---- Guarded verbs: throw [ApiException] on failure, return decoded body --

  Future<dynamic> getJson(String url, {Map<String, dynamic>? query}) =>
      _guard(() => get(url, query: _stringifyQuery(query)));

  Future<dynamic> postJson(String url, {Object? data}) =>
      _guard(() => post(url, data));

  Future<dynamic> _guard(Future<Response<dynamic>> Function() request) async {
    final Response<dynamic> res;
    try {
      res = await request();
    } catch (_) {
      throw const ApiException(message: 'Network error. Please try again.');
    }
    if (!res.isOk) throw ApiException.fromResponse(res);
    return res.body;
  }

  /// GetConnect query values must be strings.
  Map<String, String>? _stringifyQuery(Map<String, dynamic>? query) =>
      query?.map((key, value) => MapEntry(key, '$value'));
}
