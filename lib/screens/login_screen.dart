import 'package:final_app/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'home_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/custom_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final usernameCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  String? error;

  void handleLogin() async {
    setState(() => isLoading = true);
    final success = await ApiService.login(
      usernameCtrl.text.trim(),
      passwordCtrl.text.trim(),
    );
    setState(() => isLoading = false);

    if (success) {
      final prefs = await SharedPreferences.getInstance();
      final isAdmin = prefs.getBool('isSuperUser') ?? false;
      print('Is Admin: $isAdmin');

      if (isAdmin) {
        // ✅ Go to Admin Dashboard
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const AdminScreen()),
        );
      } else {
        // ✅ Go to normal user HomeScreen
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() => error = "Invalid username or password");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Task Manager",
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 40),
              CustomTextField(controller: usernameCtrl, hint: "Username"),
              const SizedBox(height: 20),
              CustomTextField(
                controller: passwordCtrl,
                hint: "Password",
                obscure: true,
              ),
              const SizedBox(height: 20),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 20),
              CustomButton(
                text: isLoading ? "Logging in..." : "Login",
                onPressed: isLoading ? null : handleLogin,
              ),
              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const RegisterScreen()),
                ),
                child: const Text("Don't have an account? Register"),
              ),
              TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ForgotPasswordScreen(),
                  ),
                ),
                child: const Text("Forgot password?"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
