import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/camera/camera_engine_service.dart';
import '../theme/kiosk_theme.dart';

/// Live biometric camera viewport consuming real-time JPEG frames
/// from http://127.0.0.1:5050/snapshot with restrained industrial framing.
class LiveCameraWidget extends StatefulWidget {
  final double width;
  final double height;
  final Color haloColor;
  final bool showOverlayGuides;
  final VoidCallback? onFaceDetected;

  const LiveCameraWidget({
    super.key,
    this.width = 280,
    this.height = 280,
    this.haloColor = KioskTheme.signalScanning,
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
  late AnimationController _scanController;
  final http.Client _client = http.Client();

  bool _isStartingEngine = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
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
    _scanController.dispose();
    _client.close();
    super.dispose();
  }

  void _startStream() {
    _streamTimer?.cancel();
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
      } else if (mounted && _isConnected) {
        setState(() => _isConnected = false);
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
    final borderColor = _isConnected ? widget.haloColor.withValues(alpha: 0.7) : KioskTheme.industrialBorderStrong;

    return Container(
      width: widget.width,
      height: widget.height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0A0C10),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor, width: 1.5),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (_isConnected && _frameBytes != null)
            Image.memory(
              _frameBytes!,
              gaplessPlayback: true,
              fit: BoxFit.cover,
            )
          else
            _buildDisconnectedPlaceholder(),

          if (widget.showOverlayGuides && _isConnected)
            _buildCleanReticleOverlay(context),
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
                    width: 36,
                    height: 36,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation<Color>(KioskTheme.signalScanning),
                    ),
                  )
                : const Icon(
                    Icons.videocam_off_rounded,
                    size: 40,
                    color: KioskTheme.textMuted,
                  ),
            const SizedBox(height: 12),
            Text(
              _isStartingEngine ? 'INICIANDO MOTOR ÓPTICO' : 'SENSOR FACIAL EN ESPERA',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.8,
                color: KioskTheme.textWhite,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              _isStartingEngine
                  ? 'Preparando red neuronal edge 512D...'
                  : 'Servicio local listo para captura',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11, color: KioskTheme.textGrey),
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: _isStartingEngine ? null : _autoStartEngine,
              icon: const Icon(Icons.power_settings_new_rounded, size: 15),
              label: Text(_isStartingEngine ? 'Iniciando...' : 'Activar Sensor'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCleanReticleOverlay(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final guideColor = Colors.white.withValues(alpha: 0.72);

    return Stack(
      children: [
        // Subtle matte oval silhouette frame
        Center(
          child: Container(
            width: widget.width * 0.56,
            height: widget.height * 0.70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(widget.width * 0.56, widget.height * 0.70),
              ),
              border: Border.all(
                color: guideColor.withValues(alpha: 0.55),
                width: 1.2,
              ),
            ),
          ),
        ),

        // Subtle hairline scan indicator (no glow blur, disabled under reduced motion)
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              final double topPos =
                  (widget.height * 0.16) + ((widget.height * 0.66) * _scanController.value);
              return Positioned(
                top: topPos,
                left: widget.width * 0.14,
                right: widget.width * 0.14,
                child: Container(
                  height: 1.5,
                  color: widget.haloColor.withValues(alpha: 0.65),
                ),
              );
            },
          ),

        // Clean architectural corner brackets
        _buildCorner(top: 12, left: 12, isTop: true, isLeft: true, color: guideColor),
        _buildCorner(top: 12, right: 12, isTop: true, isLeft: false, color: guideColor),
        _buildCorner(bottom: 12, left: 12, isTop: false, isLeft: true, color: guideColor),
        _buildCorner(bottom: 12, right: 12, isTop: false, isLeft: false, color: guideColor),
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
    required Color color,
  }) {
    return Positioned(
      top: top,
      bottom: bottom,
      left: left,
      right: right,
      child: Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          border: Border(
            top: isTop ? BorderSide(color: color, width: 2) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: color, width: 2) : BorderSide.none,
            left: isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
            right: !isLeft ? BorderSide(color: color, width: 2) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
