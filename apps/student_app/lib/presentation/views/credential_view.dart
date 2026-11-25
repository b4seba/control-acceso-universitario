import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/credential_viewmodel.dart';
import '../widgets/credential_mode_selector.dart';
import '../widgets/digital_id_card.dart';
import '../widgets/dynamic_qr_panel.dart';
import '../widgets/nfc_broadcast_panel.dart';
import 'login_view.dart';

class CredentialView extends StatelessWidget {
  const CredentialView({super.key});

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final user = authVm.currentUser;

    if (user == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginView()),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return ChangeNotifierProvider(
      create: (_) => CredentialViewModel(user: user),
      child: const _CredentialContent(),
    );
  }
}

class _CredentialContent extends StatefulWidget {
  const _CredentialContent();

  @override
  State<_CredentialContent> createState() => _CredentialContentState();
}

class _CredentialContentState extends State<_CredentialContent>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();
    final credVm = context.watch<CredentialViewModel>();
    final user = credVm.user;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: AppTheme.border),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CREDENCIAL UNIVERSITARIA',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.4,
                fontWeight: FontWeight.w700,
                color: AppTheme.institutionalCrimson,
              ),
            ),
            Text(
              user.role.label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Cerrar Sesión',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
              onPressed: () {
                authVm.logout();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(builder: (_) => const LoginView()),
                );
              },
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Tactile Institutional Student Card
                  DigitalIdCard(user: user),
                  const SizedBox(height: 18),

                  // 2. Segmented Mode Switcher (NFC HCE / QR Dinámico)
                  CredentialModeSelector(
                    activeMode: credVm.mode,
                    onSelect: credVm.switchMode,
                  ),
                  const SizedBox(height: 16),

                  // 3. Active Transmission Panel
                  if (credVm.mode == CredentialMode.nfcHce)
                    NfcBroadcastPanel(waveAnimation: _waveController)
                  else
                    DynamicQrPanel(credVm: credVm),

                  const SizedBox(height: 16),

                  // 4. Discrete Payload Copy Action for Edge Testing
                  _buildCopyPayloadCard(credVm),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyPayloadCard(CredentialViewModel credVm) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_all_rounded, color: AppTheme.textSecondary, size: 20),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Trama criptográfica lista para lector de torniquete',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: () {
              Clipboard.setData(
                ClipboardData(
                  text: credVm.mode == CredentialMode.nfcHce
                      ? credVm.lastNfcPayloadJson
                      : credVm.qrString,
                ),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payload criptográfico copiado al portapapeles.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'COPIAR TRAMA',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
