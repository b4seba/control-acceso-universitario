import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../../data/camera/camera_engine_service.dart';
import '../theme/kiosk_theme.dart';

/// Live optical biometric camera viewport inside a crisp light hardware bezel.
class LiveCameraWidget extends StatefulWidget {
  final double width;
  final double height;
  final Color haloColor;
  final bool showOverlayGuides;
  final VoidCallback? onFaceDetected;

  const LiveCameraWidget({
    super.key,
    this.width = 320,
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
    final borderColor = _isConnected
        ? widget.haloColor.withValues(alpha: 0.65)
        : KioskTheme.borderStrong;

    return Container(
      width: widget.width,
      height: widget.height,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: KioskTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: KioskTheme.cardShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Container(
          color: _isConnected ? const Color(0xFF0F172A) : KioskTheme.surfaceSubtle,
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
        ),
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
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: KioskTheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: KioskTheme.border),
              ),
              child: Center(
                child: _isStartingEngine
                    ? const SizedBox(
                        width: 26,
                        height: 26,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          valueColor: AlwaysStoppedAnimation<Color>(KioskTheme.signalScanning),
                        ),
                      )
                    : const Icon(
                        Icons.videocam_off_rounded,
                        size: 28,
                        color: KioskTheme.textSecondary,
                      ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              _isStartingEngine ? 'INICIANDO SENSOR ÓPTICO' : 'SENSOR FACIAL EN ESPERA',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: KioskTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _isStartingEngine
                  ? 'Preparando red neuronal Edge 512D...'
                  : 'Motor biométrico local listo para captura',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 11.5, color: KioskTheme.textSecondary),
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
    final guideColor = Colors.white.withValues(alpha: 0.78);
    final innerW = widget.width - 16;
    final innerH = widget.height - 16;

    return Stack(
      children: [
        Center(
          child: Container(
            width: innerW * 0.56,
            height: innerH * 0.70,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.all(
                Radius.elliptical(innerW * 0.56, innerH * 0.70),
              ),
              border: Border.all(
                color: guideColor.withValues(alpha: 0.55),
                width: 1.4,
              ),
            ),
          ),
        ),
        if (!reduceMotion)
          AnimatedBuilder(
            animation: _scanController,
            builder: (context, _) {
              final double topPos = (innerH * 0.16) + ((innerH * 0.66) * _scanController.value);
              return Positioned(
                top: topPos,
                left: innerW * 0.14,
                right: innerW * 0.14,
                child: Container(
                  height: 2,
                  color: widget.haloColor.withValues(alpha: 0.8),
                ),
              );
            },
          ),
        _buildCorner(top: 10, left: 10, isTop: true, isLeft: true, color: guideColor),
        _buildCorner(top: 10, right: 10, isTop: true, isLeft: false, color: guideColor),
        _buildCorner(bottom: 10, left: 10, isTop: false, isLeft: true, color: guideColor),
        _buildCorner(bottom: 10, right: 10, isTop: false, isLeft: false, color: guideColor),
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
            top: isTop ? BorderSide(color: color, width: 2.2) : BorderSide.none,
            bottom: !isTop ? BorderSide(color: color, width: 2.2) : BorderSide.none,
            left: isLeft ? BorderSide(color: color, width: 2.2) : BorderSide.none,
            right: !isLeft ? BorderSide(color: color, width: 2.2) : BorderSide.none,
          ),
        ),
      ),
    );
  }
}
