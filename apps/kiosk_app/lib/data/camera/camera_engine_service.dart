import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Servicio para auto-gestionar el motor biométrico de visión artificial local (512D)
/// Permite que Flutter arranque y supervise el proceso de visión sin que el usuario
/// tenga que ejecutar scripts manualmente por terminal.
class CameraEngineService {
  static final CameraEngineService instance = CameraEngineService._internal();
  CameraEngineService._internal();

  final http.Client _client = http.Client();
  Process? _spawnedProcess;
  bool _isLaunching = false;

  /// Verifica si el servicio de visión en http://127.0.0.1:5050 está activo
  Future<bool> isEngineRunning() async {
    try {
      final res = await _client
          .get(Uri.parse('http://127.0.0.1:5050/status'))
          .timeout(const Duration(milliseconds: 350));
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  /// Inicia automáticamente el motor biométrico si se encuentra inactivo
  Future<bool> ensureEngineRunning() async {
    if (kIsWeb) return false;
    if (_isLaunching) return false;

    final alreadyRunning = await isEngineRunning();
    if (alreadyRunning) {
      debugPrint('[CameraEngineService] Motor de visión ya está activo en http://127.0.0.1:5050');
      return true;
    }

    _isLaunching = true;
    try {
      final scriptPath = _resolveScriptPath();
      if (scriptPath == null) {
        debugPrint('[CameraEngineService] Advertencia: No se encontró scripts/kiosk_camera_service.py');
        return false;
      }

      debugPrint('[CameraEngineService] Auto-lanzando motor de visión: $scriptPath');

      // Iniciar proceso desacoplado en segundo plano
      _spawnedProcess = await Process.start(
        'python',
        [scriptPath],
        mode: ProcessStartMode.detachedWithStdio,
        runInShell: true,
      );

      // Esperar hasta 5 segundos a que el servidor HTTP responda
      for (int i = 0; i < 15; i++) {
        await Future.delayed(const Duration(milliseconds: 350));
        if (await isEngineRunning()) {
          debugPrint('[CameraEngineService] Motor de visión biométrica iniciado exitosamente.');
          return true;
        }
      }
      return false;
    } catch (e) {
      debugPrint('[CameraEngineService] Error al auto-iniciar motor: $e');
      return false;
    } finally {
      _isLaunching = false;
    }
  }

  /// Busca la ruta del script en el árbol de carpetas
  String? _resolveScriptPath() {
    final candidateDirs = [
      Directory.current.path,
      Directory.current.parent.path,
      '${Directory.current.path}/../..',
      'C:/Users/HP/Documents/U/ARQ SOFTWARE/EV 2',
      'C:\\Users\\HP\\Documents\\U\\ARQ SOFTWARE\\EV 2',
    ];

    for (final base in candidateDirs) {
      final p1 = File('$base/scripts/kiosk_camera_service.py');
      if (p1.existsSync()) return p1.absolute.path;
      final p2 = File('$base\\scripts\\kiosk_camera_service.py');
      if (p2.existsSync()) return p2.absolute.path;
    }
    return null;
  }

  /// Detiene el proceso hijo si fue lanzado por esta sesión
  void stopEngineIfSpawned() {
    try {
      _spawnedProcess?.kill(ProcessSignal.sigterm);
    } catch (_) {}
    _spawnedProcess = null;
  }
}
