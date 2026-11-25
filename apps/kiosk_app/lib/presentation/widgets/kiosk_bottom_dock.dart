import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';

/// Bottom input dock for 2FA credential submission plus progressive-disclosure QA triggers.
class KioskBottomDock extends StatefulWidget {
  final TextEditingController controller;
  final KioskViewModel kioskVm;
  final ValueChanged<String> onSubmitPayload;

  const KioskBottomDock({
    super.key,
    required this.controller,
    required this.kioskVm,
    required this.onSubmitPayload,
  });

  @override
  State<KioskBottomDock> createState() => _KioskBottomDockState();
}

class _KioskBottomDockState extends State<KioskBottomDock> {
  bool _showDemoTools = false;

  Future<void> _pasteAndSubmit() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (data?.text != null && data!.text!.trim().isNotEmpty) {
      final text = data.text!.trim();
      widget.controller.text = text;
      widget.onSubmitPayload(text);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        color: KioskTheme.industrialSurface,
        border: Border(top: BorderSide(color: KioskTheme.industrialBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Primary 2FA credential input row
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 520;

              final inputField = SizedBox(
                height: 44,
                child: TextField(
                  controller: widget.controller,
                  style: const TextStyle(
                    fontSize: 13,
                    fontFamily: 'monospace',
                    fontFamilyFallback: KioskTheme.monoFallback,
                    color: KioskTheme.textWhite,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Pegue trama NFC/QR o ingrese RUT (ej. 21.460.709-3)...',
                    prefixIcon: const Icon(Icons.qr_code_scanner_rounded, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.content_paste_rounded, size: 17),
                      tooltip: 'Pegar desde portapapeles y procesar',
                      onPressed: _pasteAndSubmit,
                    ),
                  ),
                  onChanged: (val) {
                    final trimmed = val.trim();
                    if ((trimmed.startsWith('{') && trimmed.endsWith('}')) ||
                        (trimmed.length >= 11 &&
                            trimmed.contains('-') &&
                            RegExp(r'^\d{1,2}\.?\d{3}\.?\d{3}-[\dkK]$').hasMatch(trimmed))) {
                      widget.onSubmitPayload(trimmed);
                    }
                  },
                  onSubmitted: widget.onSubmitPayload,
                ),
              );

              final processButton = ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: KioskTheme.signalGranted,
                  foregroundColor: const Color(0xFF090A0D),
                  minimumSize: const Size(140, 44),
                ),
                icon: const Icon(Icons.check_circle_outline_rounded, size: 17),
                onPressed: () => widget.onSubmitPayload(widget.controller.text),
                label: const Text(
                  'PROCESAR 2FA',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800),
                ),
              );

              if (isNarrow) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    inputField,
                    const SizedBox(height: 8),
                    processButton,
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(child: inputField),
                  const SizedBox(width: 10),
                  processButton,
                ],
              );
            },
          ),

          const SizedBox(height: 8),

          // Progressive disclosure header for Demo / QA Simulation triggers
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _showDemoTools = !_showDemoTools),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _showDemoTools
                            ? Icons.keyboard_arrow_down_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 18,
                        color: KioskTheme.textGrey,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Herramientas de Simulación / QA (6)',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: KioskTheme.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              TextButton.icon(
                onPressed: widget.kioskVm.resetToIdle,
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: const Text('Reset IDLE', style: TextStyle(fontSize: 11)),
                style: TextButton.styleFrom(
                  foregroundColor: KioskTheme.textGrey,
                  minimumSize: const Size(40, 32),
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                ),
              ),
            ],
          ),

          if (_showDemoTools) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                _buildQaChip(
                  icon: Icons.verified_user_rounded,
                  iconColor: KioskTheme.signalGrantedText,
                  label: 'Luciano Valenzuela (2FA)',
                  onPressed: () {
                    widget.controller.text = '21.041.170-4';
                    widget.onSubmitPayload('21.041.170-4');
                  },
                ),
                _buildQaChip(
                  icon: Icons.verified_user_rounded,
                  iconColor: KioskTheme.signalGrantedText,
                  label: 'Sebastián Freire (2FA)',
                  onPressed: () {
                    widget.controller.text = '21.460.709-3';
                    widget.onSubmitPayload('21.460.709-3');
                  },
                ),
                _buildQaChip(
                  icon: Icons.block_rounded,
                  iconColor: KioskTheme.signalDenied,
                  label: 'RUT No Registrado (Denegado)',
                  textColor: KioskTheme.signalDenied,
                  onPressed: () {
                    widget.controller.text = '99.999.999-9';
                    widget.onSubmitPayload('99.999.999-9');
                  },
                ),
                _buildQaChip(
                  icon: Icons.face_retouching_off_rounded,
                  iconColor: KioskTheme.signalDenied,
                  label: 'Rostro Divergente (2FA)',
                  textColor: KioskTheme.signalDenied,
                  onPressed: () {
                    widget.kioskVm.handleNfcOrQrDetected({
                      'student_id': 'ua-stu-2026-001',
                      'rut': '21.460.709-3',
                    }, autoSimulateFace: false);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      widget.kioskVm.handleFaceMismatchSimulation();
                    });
                  },
                ),
                _buildQaChip(
                  icon: Icons.timer_off_rounded,
                  iconColor: KioskTheme.signalAmber,
                  label: 'Timeout 3.5s',
                  textColor: KioskTheme.signalAmber,
                  onPressed: () {
                    widget.kioskVm.handleNfcOrQrDetected({
                      'student_id': 'ua-stu-2026-001',
                      'rut': '20.456.789-K',
                    }, autoSimulateFace: false);
                    Future.delayed(const Duration(milliseconds: 300), () {
                      widget.kioskVm.handleTimeoutForceSimulation();
                    });
                  },
                ),
                _buildQaChip(
                  icon: Icons.clear_rounded,
                  iconColor: KioskTheme.textGrey,
                  label: 'Limpiar entrada',
                  onPressed: () => widget.controller.clear(),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQaChip({
    required IconData icon,
    required Color iconColor,
    required String label,
    Color textColor = KioskTheme.textWhite,
    required VoidCallback onPressed,
  }) {
    return ActionChip(
      backgroundColor: KioskTheme.industrialCard,
      side: const BorderSide(color: KioskTheme.industrialBorderStrong),
      avatar: Icon(icon, size: 14, color: iconColor),
      label: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: textColor),
      ),
      onPressed: onPressed,
    );
  }
}
