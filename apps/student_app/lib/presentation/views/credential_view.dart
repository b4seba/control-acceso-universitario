import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../domain/models/student_user.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import '../viewmodels/credential_viewmodel.dart';
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
      duration: const Duration(milliseconds: 1800),
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
        backgroundColor: AppTheme.navyDark,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CREDENCIAL UNIVERSITARIA',
              style: TextStyle(
                fontSize: 12,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700,
                color: AppTheme.cobaltAccent,
              ),
            ),
            Text(
              user.campus,
              style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar Sesión',
            icon: const Icon(Icons.logout_rounded, color: AppTheme.textSecondary),
            onPressed: () {
              authVm.logout();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const LoginView()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // 1. Tarjeta Credencial Digital
                _buildPhysicalCard(user),

                const SizedBox(height: 20),

                // 2. Selector de Modo: NFC HCE vs QR Dinámico
                _buildModeSelector(credVm),

                const SizedBox(height: 20),

                // 3. Área de Transmisión Activa
                if (credVm.mode == CredentialMode.nfcHce)
                  _buildNfcHceSection(credVm)
                else
                  _buildDynamicQrSection(credVm),

                const SizedBox(height: 20),

                // 4. Auditoría y Botón de Prueba Rápida de Intercambio
                _buildDemoHelper(credVm),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPhysicalCard(StudentUser user) {
    final isVigente = user.isVigente;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF003049),
            Color(0xFF0A2463),
            Color(0xFF001233),
          ],
        ),
        border: Border.all(
          color: isVigente ? AppTheme.cobaltAccent.withValues(alpha: 0.4) : AppTheme.crimsonDenied,
          width: 1.8,
        ),
        boxShadow: [
          BoxShadow(
            color: (isVigente ? AppTheme.cobaltAccent : AppTheme.crimsonDenied).withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Cabecera de la Tarjeta con Sello Holográfico
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 10),
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'UNIVERSIDAD',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        'SISTEMA DE ACCESO INTELIGENTE',
                        style: TextStyle(
                          color: AppTheme.cobaltAccent,
                          fontSize: 9,
                          letterSpacing: 1.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Chip Inteligente Simulado
              Container(
                width: 38,
                height: 28,
                decoration: BoxDecoration(
                  color: const Color(0xFFD4AF37),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: const Color(0xFFB8860B), width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.3),
                      blurRadius: 4,
                      offset: const Offset(1, 1),
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 28,
                    height: 18,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.black26, width: 0.8),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 22),

          // Cuerpo: Fotografía referencial y Datos del Alumno
          Row(
            children: [
              // Avatar Fotográfico
              Container(
                width: 76,
                height: 94,
                decoration: BoxDecoration(
                  color: AppTheme.navySurface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.cobaltAccent, width: 2),
                ),
                child: Center(
                  child: Text(
                    user.avatarInitials,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.cobaltAccent,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.fullName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user.career,
                      style: const TextStyle(
                        color: AppTheme.cobaltAccent,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'RUT: ${user.rut}',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontFamily: 'monospace',
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Footer: Sello de Matrícula y Rol
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (isVigente ? AppTheme.emeraldSuccess : AppTheme.crimsonDenied)
                      .withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isVigente ? AppTheme.emeraldSuccess : AppTheme.crimsonDenied,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isVigente ? Icons.verified_rounded : Icons.block_rounded,
                      size: 14,
                      color: isVigente ? AppTheme.emeraldSuccess : AppTheme.crimsonDenied,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      isVigente ? 'MATRÍCULA VIGENTE 2026' : 'SUSPENDIDO / SANCIONADO',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        color: isVigente ? AppTheme.emeraldSuccess : AppTheme.crimsonDenied,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                'ID: ${user.id.toUpperCase()}',
                style: const TextStyle(
                  fontSize: 10,
                  color: AppTheme.textMuted,
                  fontFamily: 'monospace',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeSelector(CredentialViewModel credVm) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => credVm.switchMode(CredentialMode.nfcHce),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: credVm.mode == CredentialMode.nfcHce
                      ? AppTheme.autonomousBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.nfc_rounded,
                      size: 18,
                      color: credVm.mode == CredentialMode.nfcHce
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'NFC HCE (13.56 MHz)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: credVm.mode == CredentialMode.nfcHce
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => credVm.switchMode(CredentialMode.dynamicQr),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: credVm.mode == CredentialMode.dynamicQr
                      ? AppTheme.autonomousBlue
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.qr_code_2_rounded,
                      size: 18,
                      color: credVm.mode == CredentialMode.dynamicQr
                          ? Colors.white
                          : AppTheme.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'QR Dinámico (15s)',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: credVm.mode == CredentialMode.dynamicQr
                            ? Colors.white
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNfcHceSection(CredentialViewModel credVm) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Column(
        children: [
          // Animación de Ondas de Radiofrecuencia 13.56 MHz
          AnimatedBuilder(
            animation: _waveController,
            builder: (context, child) {
              return SizedBox(
                width: 140,
                height: 140,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Onda 3 exterior
                    Container(
                      width: 70 + (70 * _waveController.value),
                      height: 70 + (70 * _waveController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.cyanNfc.withValues(alpha: 1.0 - _waveController.value),
                          width: 2,
                        ),
                      ),
                    ),
                    // Onda 2 intermedia
                    Container(
                      width: 50 + (50 * _waveController.value),
                      height: 50 + (50 * _waveController.value),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppTheme.cobaltAccent.withValues(alpha: (1.0 - _waveController.value) * 0.8),
                          width: 2.5,
                        ),
                      ),
                    ),
                    // Núcleo NFC
                    Container(
                      width: 66,
                      height: 66,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppTheme.autonomousBlue,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.cyanNfc,
                            blurRadius: 16,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.nfc_rounded,
                        color: Colors.white,
                        size: 38,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            'TRANSMITIENDO POR CAMPO CERCANO (HCE)',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.cyanNfc,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Acerque el smartphone a la antena del Kiosko Torniquete para validar su identidad en < 500 ms.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildDynamicQrSection(CredentialViewModel credVm) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.navySurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Column(
        children: [
          const Text(
            'RESPALDO CRIPTOGRÁFICO ROTATIVO',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: AppTheme.amberWarning,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Enfoque este código QR al visor de la cámara del Kiosko si el NFC no está disponible',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 18),

          // Contenedor QR de Alto Contraste
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.3),
                  blurRadius: 16,
                ),
              ],
            ),
            child: QrImageView(
              data: credVm.qrString,
              version: QrVersions.auto,
              size: 190.0,
              backgroundColor: Colors.white,
              eyeStyle: const QrEyeStyle(
                eyeShape: QrEyeShape.square,
                color: Color(0xFF0A192F),
              ),
              dataModuleStyle: const QrDataModuleStyle(
                dataModuleShape: QrDataModuleShape.square,
                color: Color(0xFF0A192F),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Código TOTP Numérico
          Text(
            credVm.totpCode,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w900,
              letterSpacing: 4.0,
              fontFamily: 'monospace',
              color: AppTheme.textPrimary,
            ),
          ),

          const SizedBox(height: 10),

          // Barra de Cuenta Regresiva de 15 Segundos
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: credVm.progress,
              minHeight: 8,
              backgroundColor: AppTheme.navyBorder,
              valueColor: AlwaysStoppedAnimation<Color>(
                credVm.remainingSeconds <= 4
                    ? AppTheme.crimsonDenied
                    : AppTheme.amberWarning,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Rotación TOTP RFC 6238:',
                style: TextStyle(fontSize: 10, color: AppTheme.textMuted),
              ),
              Text(
                'Válido por ${credVm.remainingSeconds} segundos',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textSecondary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDemoHelper(CredentialViewModel credVm) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.navySurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppTheme.navyBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.copy_all_rounded, color: AppTheme.cobaltAccent, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Payload criptográfico listo para Kiosko:',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              side: const BorderSide(color: AppTheme.cobaltAccent),
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(
                text: credVm.mode == CredentialMode.nfcHce
                    ? credVm.lastNfcPayloadJson
                    : credVm.qrString,
              ));
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Payload criptográfico copiado al portapapeles.'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text('COPIAR TRAMA', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }
}
