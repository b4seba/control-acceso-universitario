import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../domain/models/student_user.dart';

const String _envApiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: '');

String _resolveApiBaseUrl() {
  if (_envApiBaseUrl.isNotEmpty) {
    return _envApiBaseUrl.replaceAll(RegExp(r'/+$'), '');
  }
  if (kIsWeb) {
    return Uri.base.origin;
  }
  return 'http://localhost:8080';
}

enum AuthStatus { unauthenticated, authenticating, authenticated, error }

class AuthViewModel extends ChangeNotifier {
  AuthStatus _status = AuthStatus.unauthenticated;
  StudentUser? _currentUser;
  String? _errorMessage;
  final http.Client _client = http.Client();

  AuthStatus get status => _status;
  StudentUser? get currentUser => _currentUser;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _status == AuthStatus.authenticated && _currentUser != null;
  bool get isLoading => _status == AuthStatus.authenticating;

  void selectQuickUser(StudentUser user) {
    _currentUser = user;
    _status = AuthStatus.authenticated;
    _errorMessage = null;
    notifyListeners();
  }

  /// Inicio de Sesión Real (RUT y Contraseña - Rol inferido automáticamente por base de datos)
  Future<bool> login(String rutOrEmail, String password) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    if (rutOrEmail.trim().isEmpty || password.trim().isEmpty) {
      _status = AuthStatus.error;
      _errorMessage = 'Por favor ingresa tu RUT institucional y contraseña.';
      notifyListeners();
      return false;
    }

    try {
      // 1. Autenticar estrictamente contra el backend central Golang / PostgreSQL
      final uri = Uri.parse('${_resolveApiBaseUrl()}/api/v1/auth/login');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rut': rutOrEmail.trim(),
          'password': password.trim(),
        }),
      ).timeout(const Duration(milliseconds: 5000));

      final Map<String, dynamic>? data = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>?)
          : null;

      if (res.statusCode == 200 && data != null && data['user'] is Map<String, dynamic>) {
        final userData = Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
        if (data.containsKey('face_vector_512')) {
          userData['face_vector_512'] = data['face_vector_512'];
        }
        _currentUser = StudentUser.fromJson(userData);
        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = (data?['error'] as String?) ?? 'RUT o contraseña incorrectos.';
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'No se pudo conectar con el servidor central. Verifica tu conexión.';
      notifyListeners();
      return false;
    }
  }

  /// Enrolamiento y Creación de Cuenta Real (Persiste en PostgreSQL, Qdrant y SQLite WAL)
  Future<bool> register({
    required String rut,
    required String fullName,
    required String career,
    String campus = '',
    required String password,
    List<double>? faceVector,
  }) async {
    _status = AuthStatus.authenticating;
    _errorMessage = null;
    notifyListeners();

    if (rut.trim().isEmpty || fullName.trim().isEmpty || password.trim().isEmpty) {
      _status = AuthStatus.error;
      _errorMessage = 'Todos los campos obligatorios deben ser completados.';
      notifyListeners();
      return false;
    }

    // Vector de 512 dimensiones (Zero-Trust: sin fotos crudas)
    final vector512 = faceVector ?? StudentUser.generateDeterministicVector(rut.trim());

    try {
      // 1. Notificar al backend Go para persistir en PostgreSQL 16 y Qdrant
      final uri = Uri.parse('${_resolveApiBaseUrl()}/api/v1/auth/register');
      final res = await _client.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'rut': rut.trim(),
          'full_name': fullName.trim(),
          'career': career.trim(),
          'campus': campus.trim(),
          'password': password.trim(),
          'vector': vector512,
        }),
      ).timeout(const Duration(milliseconds: 5000));

      final Map<String, dynamic>? data = res.body.isNotEmpty
          ? (jsonDecode(res.body) as Map<String, dynamic>?)
          : null;

      if ((res.statusCode == 201 || res.statusCode == 200) &&
          data != null &&
          data['user'] is Map<String, dynamic>) {
        final userData = Map<String, dynamic>.from(data['user'] as Map<String, dynamic>);
        userData['face_vector_512'] = vector512;
        _currentUser = StudentUser.fromJson(userData);

        // Notificar en segundo plano al Kiosko Edge SQLite
        try {
          final cleanRut = rut.replaceAll('.', '').replaceAll('-', '').trim();
          _client.post(
            Uri.parse('http://127.0.0.1:5050/enroll'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'student_id': 'ua-stu-$cleanRut',
              'rut': rut.trim(),
              'full_name': fullName.trim(),
              'career': career.trim(),
              'campus': campus.trim(),
              'vector': vector512,
            }),
          );
        } catch (_) {}

        _status = AuthStatus.authenticated;
        _errorMessage = null;
        notifyListeners();
        return true;
      }

      _status = AuthStatus.error;
      _errorMessage = (data?['error'] as String?) ?? 'No se pudo completar el registro.';
      notifyListeners();
      return false;
    } catch (_) {
      _status = AuthStatus.error;
      _errorMessage = 'No se pudo conectar con el servidor central para registrar la cuenta.';
      notifyListeners();
      return false;
    }
  }

  void logout() {
    _currentUser = null;
    _status = AuthStatus.unauthenticated;
    _errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}
