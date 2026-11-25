import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'credential_view.dart';
// Enrolamiento centralizado en Web Enrollment (React + Vite)

class LoginView extends StatefulWidget {
  const LoginView({super.key});

  @override
  State<LoginView> createState() => _LoginViewState();
}

class _LoginViewState extends State<LoginView> {
  final _rutController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _rutController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final authVm = context.read<AuthViewModel>();
    final success = await authVm.login(
      _rutController.text,
      _passwordController.text,
    );
    if (success && mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const CredentialView()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final authVm = context.watch<AuthViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Institutional header
                  Center(
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppTheme.institutionalCrimson,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(
                        Icons.account_balance_rounded,
                        size: 32,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'UNIVERSIDAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 2.0,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.institutionalCrimson,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Credencial Digital Universitaria',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Pase estudiantil institucional · NFC HCE y QR TOTP 15s',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Clean Login Card
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: AppTheme.surface,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppTheme.border, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _rutController,
                          textInputAction: TextInputAction.next,
                          style: const TextStyle(
                            fontSize: 15,
                            fontFamily: 'monospace',
                            fontFamilyFallback: AppTheme.monoFallback,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: const InputDecoration(
                            labelText: 'RUT Institucional',
                            hintText: 'Ej. 12.345.678-9',
                            prefixIcon: Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        TextField(
                          controller: _passwordController,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) {
                            if (!authVm.isLoading) _handleLogin();
                          },
                          style: const TextStyle(
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                          decoration: InputDecoration(
                            labelText: 'Contraseña SIRAD',
                            hintText: 'Ingresa tu contraseña',
                            prefixIcon: const Icon(Icons.lock_outline_rounded),
                            suffixIcon: IconButton(
                              tooltip: _obscurePassword ? 'Mostrar contraseña' : 'Ocultar contraseña',
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: AppTheme.textSecondary,
                              ),
                              onPressed: () {
                                setState(() => _obscurePassword = !_obscurePassword);
                              },
                            ),
                          ),
                        ),

                        if (authVm.errorMessage != null) ...[
                          const SizedBox(height: 14),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.statusDeniedBg,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: AppTheme.statusDenied.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: AppTheme.statusDenied,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    authVm.errorMessage!,
                                    style: const TextStyle(
                                      color: AppTheme.statusDenied,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        ElevatedButton(
                          onPressed: authVm.isLoading ? null : _handleLogin,
                          child: authVm.isLoading
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.5,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('INGRESAR A MI CREDENCIAL'),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Accessible enrollment hint link
                  Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      const Text(
                        '¿No tienes credencial registrada?',
                        style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(
                          minimumSize: const Size(44, 44),
                          foregroundColor: AppTheme.institutionalCrimson,
                          textStyle: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                        onPressed: () {
                          // Enrolamiento en web_enrollment (React + Vite)
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'El enrolamiento biométrico se realiza en el Portal Web Central (/).',
                              ),
                            ),
                          );
                        },
                        child: const Text('Portal Web Central'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
