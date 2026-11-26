import 'package:http/http.dart' as http;

class BackendConfig {
  static const String _envApiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static const List<String> _candidateBackends = [
    'http://172.22.0.213:8080',
    'http://100.115.171.26:8080',
    'http://localhost:8080',
  ];

  static String _activeBaseUrl = _envApiBaseUrl.isNotEmpty
      ? _envApiBaseUrl.replaceAll(RegExp(r'/+$'), '')
      : 'http://172.22.0.213:8080';

  static DateTime? _lastResolveAttempt;

  static String get baseUrl => _activeBaseUrl;

  static String get grpcHost {
    final parsed = Uri.tryParse(_activeBaseUrl);
    if (parsed != null && parsed.host.isNotEmpty) {
      return parsed.host;
    }
    return 'localhost';
  }

  static const int grpcPort = 50051;

  /// Resuelve el backend activo probando Lab 410, Tailscale y localhost.
  /// Si se definió API_BASE_URL vía --dart-define, respeta ese valor sin sondeo.
  static Future<String> resolveActiveBackend({bool force = false}) async {
    if (_envApiBaseUrl.isNotEmpty) {
      _activeBaseUrl = _envApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
      return _activeBaseUrl;
    }

    final now = DateTime.now();
    if (!force &&
        _lastResolveAttempt != null &&
        now.difference(_lastResolveAttempt!).inSeconds < 10) {
      return _activeBaseUrl;
    }
    _lastResolveAttempt = now;

    final client = http.Client();
    try {
      for (final candidate in _candidateBackends) {
        try {
          final res = await client
              .get(Uri.parse('$candidate/api/v1/health'))
              .timeout(const Duration(milliseconds: 1000));
          if (res.statusCode == 200) {
            _activeBaseUrl = candidate;
            return _activeBaseUrl;
          }
        } catch (_) {
          // Intentar el siguiente candidato
        }
      }
    } finally {
      client.close();
    }

    return _activeBaseUrl;
  }
}
