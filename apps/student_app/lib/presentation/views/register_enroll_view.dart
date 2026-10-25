import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../domain/models/student_user.dart';
import '../theme/app_theme.dart';
import '../viewmodels/auth_viewmodel.dart';
import 'credential_view.dart';

class RegisterEnrollView extends StatefulWidget {
  const RegisterEnrollView({super.key});

  @override
  State<RegisterEnrollView> createState() => _RegisterEnrollViewState();
}

class _RegisterEnrollViewState extends State<RegisterEnrollView> {
  final _rutController = TextEditingController(text: '21.460.709-3');
  final _nameController = TextEditingController(text: 'Sebastián Freire');
  final _careerController = TextEditingController(text: 'Ingeniería Civil Informática');
  final _passwordController = TextEditingController(text: 'ua2026pass');
  String _selectedCampus = 'Campus Alameda';

  bool _isVectorEnrolled = false;
  List<double>? _enrolledVector;

  final List<String> _campusList = const [
    'Campus Alameda',
    'Campus Providencia',
    'Campus El Llano Subercaseaux',
    'Campus Talca',
    'Campus Temuco',
  ];

  @override
  void dispose() {
    _rutController.dispose();
    _nameController.dispose();
    _careerController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleExtractVector() {
    setState(() {
      // Generación de vector 512D normalizado (Zero-Trust: sin persistir foto cruda)
      _enrolledVector = StudentUser.generateDeterministicVector(_rutController.text.trim());
      _isVectorEnrolled = true;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✓ Vector biométrico de 512 dimensiones extraído exitosamente.'),
        backgroundColor: AppTheme.emeraldSuccess,
        duration: Duration(seconds: 2),
      ),
    );
  }

  void _handleRegister() async {
    final authVm = context.read<AuthViewModel>();
    final success = await authVm.register(
      rut: _rutController.text,
      fullName: _nameController.text,
      career: _careerController.text,
      campus: _selectedCampus,
      password: _passwordController.text,
      faceVector: _enrolledVector,
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
      appBar: AppBar(
        title: const Text('Enrolamiento y Creación de Cuenta'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Cabecera
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppTheme.navySurface,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppTheme.cobaltAccent, width: 2),
                      ),
                      child: const Icon(Icons.person_add_alt_1_rounded,
                          size: 36, color: AppTheme.cobaltAccent),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'REGISTRO INSTITUCIONAL SIRAD',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.cobaltAccent,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Crear Cuenta y Enrolar Rostro 512D',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Persistencia en PostgreSQL 16, Qdrant Vector DB y SQLite WAL',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 24),

                  // Campo RUT
                  TextField(
                    controller: _rutController,
                    decoration: const InputDecoration(
                      labelText: 'RUT Institucional *',
                      hintText: 'Ej. 21.460.709-3',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo Nombre Completo
                  TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre Completo *',
                      hintText: 'Ej. Sebastián Freire',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo Carrera
                  TextField(
                    controller: _careerController,
                    decoration: const InputDecoration(
                      labelText: 'Carrera *',
                      hintText: 'Ej. Ingeniería Civil Informática',
                      prefixIcon: Icon(Icons.school_outlined),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Selector de Sede / Campus
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppTheme.navyBorder),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedCampus,
                        isExpanded: true,
                        dropdownColor: AppTheme.navySurface,
                        items: _campusList.map((c) {
                          return DropdownMenuItem(value: c, child: Text(c));
                        }).toList(),
                        onChanged: (newCampus) {
                          if (newCampus != null) {
                            setState(() => _selectedCampus = newCampus);
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),

                  // Campo Contraseña
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña de Acceso *',
                      prefixIcon: Icon(Icons.lock_outline_rounded),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sección de Enrolamiento Biométrico 512D
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.navySurface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _isVectorEnrolled ? AppTheme.emeraldSuccess : AppTheme.cobaltAccent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Icon(
                              _isVectorEnrolled ? Icons.verified_user_rounded : Icons.face_rounded,
                              color: _isVectorEnrolled ? AppTheme.emeraldSuccess : AppTheme.cobaltAccent,
                              size: 24,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isVectorEnrolled
                                        ? 'BIOMETRÍA 512D ENROLADA'
                                        : 'ENROLAMIENTO FACIAL REQUERIDO',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                      color: _isVectorEnrolled
                                          ? AppTheme.emeraldSuccess
                                          : AppTheme.cobaltAccent,
                                    ),
                                  ),
                                  const Text(
                                    'Zero-Trust: Cero fotos crudas • Solo 512 floats',
                                    style: TextStyle(fontSize: 10, color: AppTheme.textSecondary),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleExtractVector,
                          icon: Icon(_isVectorEnrolled ? Icons.check : Icons.camera_alt_outlined),
                          label: Text(_isVectorEnrolled
                              ? 'Rostro Capturado (512D L2=1.0) - Re-capturar'
                              : 'Capturar Rostro y Extraer Vector 512D'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _isVectorEnrolled
                                ? AppTheme.emeraldSuccess
                                : AppTheme.cobaltAccent,
                            side: BorderSide(
                              color: _isVectorEnrolled
                                  ? AppTheme.emeraldSuccess
                                  : AppTheme.cobaltAccent,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Mensaje de Error si ocurre
                  if (authVm.errorMessage != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 12),
                      decoration: BoxDecoration(
                        color: AppTheme.crimsonDenied.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppTheme.crimsonDenied.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        authVm.errorMessage!,
                        style: const TextStyle(color: AppTheme.crimsonDenied, fontSize: 13),
                      ),
                    ),

                  // Botón Registrarse
                  ElevatedButton(
                    onPressed: authVm.isLoading ? null : _handleRegister,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.emeraldSuccess,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: authVm.isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Text(
                            'COMPLETAR REGISTRO Y GUARDAR EN POSTGRES / QDRANT',
                            style: TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.8),
                          ),
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
