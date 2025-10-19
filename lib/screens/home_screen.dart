import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'admin_screen.dart';
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
  bool hasSubscription = false;
  int remainingDays = 0;
  String? username;

  @override
  void initState() {
    super.initState();
    checkUserStatus();
  }

  Future<void> checkUserStatus() async {
    final userInfo = await ApiService.getUserInfo();
    print('userInfo: $userInfo');
    final userType = userInfo['user_type'];
    final subscriptionEnd = userInfo['subscription_end'];
    username = userInfo['username'] ?? 'User';

    bool activeSubscription = false;
    int daysLeft = 0;

    if (subscriptionEnd != null && subscriptionEnd.isNotEmpty) {
      final endDate = DateTime.parse(subscriptionEnd);
      final now = DateTime.now();
      if (endDate.isAfter(now)) {
        activeSubscription = true;
        daysLeft = endDate.difference(now).inDays;
      }
    }

    setState(() {
      isAdmin =
          userInfo['is_staff'] == true || userInfo['is_superuser'] == true;
      hasSubscription = userType == 'subscription' || activeSubscription;
      remainingDays = daysLeft;
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
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF4A90E2), Color(0xFF007AFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
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
            icon: const Icon(Icons.logout, color: Colors.white),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade50, Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                'Welcome, ${username ?? ''}! 👋',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 15),

            if (isAdmin)
              _buildMenuCard(
                icon: Icons.admin_panel_settings,
                title: 'Manage Users (Admin)',
                color: Colors.orange,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AdminScreen()),
                ),
              ),

            _buildMenuCard(
              icon: Icons.task,
              title: 'My Tasks',
              color: Colors.indigo,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TasksScreen()),
              ),
            ),

            const SizedBox(height: 10),

            if (!hasSubscription)
              _buildMenuCard(
                icon: Icons.credit_card,
                title: 'Upgrade Subscription',
                color: Colors.green,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                ),
              )
            else
              Card(
                elevation: 4,
                color: Colors.green.shade100,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  leading: const Icon(Icons.verified, color: Colors.green),
                  title: const Text(
                    "Active Subscription",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    remainingDays > 0
                        ? "You have $remainingDays days remaining"
                        : "Subscription ends today",
                    style: const TextStyle(color: Colors.black87),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard({
    required IconData icon,
    required String title,
    required Color color,
    required VoidCallback onTap,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Card(
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: color.withOpacity(0.2),
              child: Icon(icon, color: color),
            ),
            title: Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 18),
          ),
        ),
      ),
    );
  }
}
