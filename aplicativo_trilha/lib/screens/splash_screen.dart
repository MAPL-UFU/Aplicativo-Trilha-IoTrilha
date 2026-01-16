// lib/screens/splash_screen.dart
import 'package:aplicativo_trilha/main.dart';
import 'package:aplicativo_trilha/screens/login_screen.dart';
import 'package:aplicativo_trilha/screens/main_shell.dart';
import 'package:flutter/material.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkUserSession();
  }

  Future<void> _checkUserSession() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      final userData = await authService.getUserData();

      if (userData['user_id'] != null) {
        print(
          "[SplashScreen] Sessão encontrada. Logando usuário ID: ${userData['user_id']}",
        );

        final tipoPerfil = int.parse(userData['user_tipo_perfil'] ?? '1');
        UserProfile profile = UserProfile.trilheiro;
        if (tipoPerfil == 2) profile = UserProfile.guia;
        if (tipoPerfil == 3) profile = UserProfile.operador;

        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MainShell(profile: profile),
            ),
          );
        }
      } else {
        print("[SplashScreen] Nenhuma sessão encontrada. Indo para Login.");
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginScreen()),
          );
        }
      }
    } catch (e) {
      print("[SplashScreen] Erro ao checar sessão: $e");
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(),

              Text(
                'Desenvolvido por:',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                  letterSpacing: 1.0,
                ),
              ),

              const SizedBox(height: 24),

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Expanded(
                    child: SizedBox(
                      height: 100,
                      child: Image.asset(
                        'assets/images/logo_ufu.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.school, size: 50, color: Colors.grey),
                              Text(
                                "Logo UFU",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(width: 20),

                  Expanded(
                    child: SizedBox(
                      height: 100,
                      child: Image.asset(
                        'assets/images/logo_lab.png',
                        fit: BoxFit.contain,
                        errorBuilder: (context, error, stackTrace) {
                          return Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: const [
                              Icon(Icons.science, size: 50, color: Colors.grey),
                              Text(
                                "Logo Lab",
                                style: TextStyle(
                                  fontSize: 10,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),

              const Spacer(),

              const CircularProgressIndicator(
                color: Color(0xFF2E7D32),
                strokeWidth: 3,
              ),
              const SizedBox(height: 25),
              const Text(
                'Iniciando sistema...',
                style: TextStyle(color: Colors.grey, fontSize: 12),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
