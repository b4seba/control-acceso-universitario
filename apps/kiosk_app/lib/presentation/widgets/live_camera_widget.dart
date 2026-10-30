import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/camera/camera_engine_service.dart';
import '../theme/kiosk_theme.dart';

/// Visor de Cámara en Vivo para el Kiosko Torniquete Edge
/// Consume el feed JPEG en tiempo real desde el servicio local en http://127.0.0.1:5050/snapshot
class LiveCameraWidget extends StatefulWidget {
  final double width;
  final double height;
  final Color haloColor;
  final bool showOverlayGuides;
  final VoidCallback? onFaceDetected;

  const LiveCameraWidget({
    super.key,
    this.width = 320,
    this.height = 320,
    this.haloColor = KioskTheme.haloFaceScanning,
    this.showOverlayGuides = true,
    this.onFaceDetected,
  });

  @override
  State<LiveCameraWidget> createState() => _LiveCameraWidgetState();
}

class _LiveCameraWidgetState extends State<LiveCameraWidget>
    with SingleTickerProviderStateMixin {
  Uint8List? _frameBytes;
  bool _isConnected = false;
  bool _isFetching = false;
  Timer? _streamTimer;
  late AnimationController _laserController;
  final http.Client _client = http.Client();

  bool _isStartingEngine = false;

  @override
  void initState() {
    super.initState();
    _laserController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _autoStartEngine();
    _startStream();
  }

  Future<void> _autoStartEngine() async {
    if (_isConnected) return;
    if (mounted) setState(() => _isStartingEngine = true);
    await CameraEngineService.instance.ensureEngineRunning();
    if (mounted) {
      setState(() => _isStartingEngine = false);
      _fetchFrame();
    }
  }

  @override
  void dispose() {
    _streamTimer?.cancel();
    _laserController.dispose();
    _client.close();
    super.dispose();
  }

  void _startStream() {
    _streamTimer?.cancel();
    // 30 FPS polling fluido sobre localhost (33 ms)
    _streamTimer = Timer.periodic(const Duration(milliseconds: 33), (_) => _fetchFrame());
  }

  Future<void> _fetchFrame() async {
    if (_isFetching || !mounted) return;
    _isFetching = true;

    try {
      final uri = Uri.parse('http://127.0.0.1:5050/snapshot');
      final response = await _client.get(uri).timeout(const Duration(milliseconds: 200));

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        if (mounted) {
          setState(() {
            _frameBytes = response.bodyBytes;
            _isConnected = true;
          });
        }
      } else {
        if (mounted && _isConnected) {
          setState(() => _isConnected = false);
        }
      }
    } catch (_) {
      if (mounted && _isConnected) {
        setState(() => _isConnected = false);
      }
    } finally {
      _isFetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF030712),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: widget.haloColor, width: 3),
        boxShadow: [
          BoxShadow(
            color: widget.haloColor.withValues(alpha: 0.35),
            blurRadius: 28,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Imagen de Video en Vivo o Pantalla de Desconexión
          if (_isConnected && _frameBytes != null)
            Image.memory(
              _frameBytes!,
              gaplessPlayback: true,
              fit: BoxFit.cover,
            )
          else
            _buildDisconnectedPlaceholder(),

          // 2. Retícula Biométrica y Línea Láser Animada
          if (widget.showOverlayGuides && _isConnected)
            _buildBiometricHudOverlay(),


        ],
      ),
    );
  }

  Widget _buildDisconnectedPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _isStartingEngine
                ? const SizedBox(
                    width: 48,
                    height: 48,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF38BDF8)),
                    ),
                  )
                : Icon(Icons.videocam_off_rounded, size: 52, color: Colors.grey.shade600),
            const SizedBox(height: 14),
            Text(
              _isStartingEngine ? 'INICIANDO MOTOR BIOMÉTRICO 512D...' : 'SENSOR FACIAL EN ESPERA',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.1,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isStartingEngine
                  ? 'Inicializando sensor óptico y red neuronal edge...'
                  : 'Motor biométrico integrado listo para enlace',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
            const SizedBox(height: 14),
            ElevatedButton.icon(
              onPressed: _isStartingEngine ? null : _autoStartEngine,
              icon: const Icon(Icons.power_settings_new_rounded, size: 16),
              label: Text(_isStartingEngine ? 'Iniciando...' : 'Activar Sensor'),
              style: ElevatedButton.styleFrom(
                backgroundColor: KioskTheme.industrialSurface,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBiometricHudOverlay() {
    return Stack(
      children: [
        // Guía Ovalada Central para el Rostro
        Center(
          child: Container(
            width: widget.width * 0.55,
            height: widget.height * 0.72,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(widget.width * 0.55, widget.height * 0.72),
              ),
              border: Border.all(
                color: widget.haloColor.withValues(alpha: 0.5),
                width: 2,
              ),
            ),
          ),
        ),

        // Línea Láser Animada
        AnimatedBuilder(
          animation: _laserController,
          builder: (context, child) {
            final double topPos = (widget.height * 0.15) +
                ((widget.height * 0.65) * _laserController.value);
            return Positioned(
              top: topPos,
              left: widget.width * 0.1,
              right: widget.width * 0.1,
              child: Container(
                height: 2,
                decoration: BoxDecoration(
                  color: widget.haloColor,
                  boxShadow: [
                    BoxShadow(
                      color: widget.haloColor,
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            );
          },
        ),

        // Esquinas de Retícula HUD
        _buildCorner(top: 14, left: 14, isTop: true, isLeft: true),
        _buildCorner(top: 14, right: 14, isTop: true, isLeft: false),
        _buildCorner(bottom: 14, left: 14, isTop: false, isLeft: true),
        _buildCorner(bottom: 14, right: 14, isTop: false, isLeft: false),
      ],
    );
  }

  Widget _buildCorner({
    double? top,
    double? bottom,
    double? left,
    double? right,
    required bool isTop,
    required bool isLeft,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 20,
        height: 20,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: widget.haloColor, width: 3) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: widget.haloColor, width: 3) : BorderSide.none,
            left: isLeft ? BorderSide(color: widget.haloColor, width: 3) : BorderSide.none,
            right: !isLeft ? BorderSide(color: widget.haloColor, width: 3) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
