import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../widgets/custom_textfield.dart';
import '../widgets/custom_button.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String uid;
  final String token;

  const ResetPasswordScreen({
    super.key,
    required this.uid,
    required this.token,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final passwordCtrl = TextEditingController();
  bool isLoading = false;
  String? message;

  void handleResetPassword() async {
    if (passwordCtrl.text.isEmpty) {
      setState(() => message = "Please enter your new password");
      return;
    }

    setState(() {
      isLoading = true;
      message = null;
    });

    final response = await ApiService.resetPassword(
      widget.uid,
      widget.token,
      passwordCtrl.text,
    );

    setState(() {
      isLoading = false;
      message = response;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reset Password")),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open, size: 100, color: Colors.indigo),
              const SizedBox(height: 20),
              const Text(
                "Enter a new password",
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Please enter your new password below.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              CustomTextField(
                controller: passwordCtrl,
                hint: "New password",
                obscure: true,
              ),
              const SizedBox(height: 20),
              CustomButton(
                text: isLoading ? "Resetting..." : "Reset Password",
                onPressed: isLoading ? null : handleResetPassword,
              ),
              const SizedBox(height: 30),
              if (message != null)
                Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: message!.toLowerCase().contains("successful")
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
