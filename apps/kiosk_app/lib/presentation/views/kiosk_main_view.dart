import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../data/outbox/outbox_worker.dart';
import '../../domain/fsm/turnstile_state.dart';
import '../theme/kiosk_theme.dart';
import '../viewmodels/kiosk_viewmodel.dart';
import '../widgets/kiosk_bottom_dock.dart';
import '../widgets/kiosk_diagnostic_toast.dart';
import '../widgets/kiosk_header_bar.dart';
import '../widgets/kiosk_state_views.dart';

class KioskMainView extends StatefulWidget {
  const KioskMainView({super.key});

  @override
  State<KioskMainView> createState() => _KioskMainViewState();
}

class _KioskMainViewState extends State<KioskMainView> {
  final _qrInputController = TextEditingController();

  @override
  void dispose() {
    _qrInputController.dispose();
    super.dispose();
  }

  void _processPastedPayload(String rawText) {
    if (rawText.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ingrese o pegue la trama de credencial (RUT o JSON de la app).'),
          duration: Duration(seconds: 2),
          backgroundColor: KioskTheme.brandCrimson,
        ),
      );
      return;
    }
    context.read<KioskViewModel>().process2FAVerification(rawText.trim());
  }

  Color _stateRailColor(TurnstileStateType type) {
    switch (type) {
      case TurnstileStateType.idle:
        return KioskTheme.brandCrimson;
      case TurnstileStateType.nfcReading:
        return KioskTheme.signalAmber;
      case TurnstileStateType.faceScanning:
        return KioskTheme.signalScanning;
      case TurnstileStateType.accessGranted:
        return KioskTheme.signalGranted;
      case TurnstileStateType.accessDenied:
        return KioskTheme.signalDenied;
    }
  }

  @override
  Widget build(BuildContext context) {
    final kioskVm = context.watch<KioskViewModel>();
    final outboxWorker = context.watch<OutboxWorker>();
    final currentState = kioskVm.currentState;
    final railColor = _stateRailColor(currentState.type);
    final isWideViewport = MediaQuery.sizeOf(context).width >= 760;

    return Scaffold(
      backgroundColor: KioskTheme.canvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              height: 5,
              color: railColor,
            ),

            KioskHeaderBar(kioskVm: kioskVm, outboxWorker: outboxWorker),

            if (kioskVm.currentToast != null)
              Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: KioskDiagnosticToast(
                    toast: kioskVm.currentToast!,
                    onDismiss: kioskVm.clearToast,
                  ),
                ),
              ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: isWideViewport ? 32 : 16,
                    vertical: isWideViewport ? 24 : 16,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 1060),
                      child: KioskStateCenter(
                        state: currentState,
                        kioskVm: kioskVm,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            KioskBottomDock(
              controller: _qrInputController,
              kioskVm: kioskVm,
              onSubmitPayload: _processPastedPayload,
            ),
          ],
        ),
      ),
    );
  }
}
