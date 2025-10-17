import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/custom_button.dart';
import 'login_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final usernameCtrl = TextEditingController();
  final emailCtrl = TextEditingController();
  final passwordCtrl = TextEditingController();

  bool isLoading = false;
  String? message;

  void handleRegister() async {
    setState(() {
      isLoading = true;
      message = null;
    });

    final response = await ApiService.registerUser(
      usernameCtrl.text.trim(),
      emailCtrl.text.trim(),
      passwordCtrl.text.trim(),
    );

    setState(() {
      isLoading = false;
      message = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Register Account")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.person_add_alt_1,
                size: 100,
                color: Colors.indigo,
              ),
              const SizedBox(height: 20),
              const Text(
                "Create an Account",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Sign up to manage your daily tasks and projects.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),

              CustomTextField(controller: usernameCtrl, hint: "Username"),
              const SizedBox(height: 15),
              CustomTextField(controller: emailCtrl, hint: "Email"),
              const SizedBox(height: 15),
              CustomTextField(
                controller: passwordCtrl,
                hint: "Password",
                obscure: true,
              ),
              const SizedBox(height: 25),

              CustomButton(
                text: isLoading ? "Registering..." : "Register",
                onPressed: isLoading ? null : handleRegister,
              ),
              const SizedBox(height: 20),

              if (message != null)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message!.toLowerCase().contains("verify")
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () => Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                ),
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
