import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/viewmodels/auth_viewmodel.dart';
import 'presentation/views/login_view.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const StudentCredentialApp());
}

class StudentCredentialApp extends StatelessWidget {
  const StudentCredentialApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthViewModel()),
      ],
      child: MaterialApp(
        title: 'UA Credencial Digital',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.darkTheme,
        home: const LoginView(),
      ),
    );
  }
}
