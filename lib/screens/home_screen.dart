import 'package:final_app/screens/admin_screen.dart';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'tasks_screen.dart';
import 'subscription_screen.dart';
import 'login_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool isAdmin = false;
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    checkIfAdmin();
  }

  Future<void> checkIfAdmin() async {
    final userInfo = await ApiService.getUserInfo(); // backend call
    setState(() {
      isAdmin =
          userInfo['is_staff'] == true || userInfo['is_superuser'] == true;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          IconButton(
            onPressed: () async {
              await ApiService.logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginScreen()),
                );
              }
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (isAdmin)
            ListTile(
              leading: const Icon(
                Icons.admin_panel_settings,
                color: Colors.orange,
              ),
              title: const Text("Manage Users (Admin)"),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminScreen()),
              ),
            ),
          ListTile(
            leading: const Icon(Icons.task, color: Colors.indigo),
            title: const Text("My Tasks"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TasksScreen()),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.credit_card, color: Colors.green),
            title: const Text("Upgrade Subscription"),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
            ),
          ),
        ],
      ),
    );
  }
}
