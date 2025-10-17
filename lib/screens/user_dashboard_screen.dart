import 'package:flutter/material.dart';
import '../services/api_service.dart';
import 'team_detail_screen.dart';

class UserDashboardScreen extends StatefulWidget {
  const UserDashboardScreen({super.key});

  @override
  State<UserDashboardScreen> createState() => _UserDashboardScreenState();
}

class _UserDashboardScreenState extends State<UserDashboardScreen> {
  List<dynamic> teams = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadUserTeams();
  }

  Future<void> loadUserTeams() async {
    final data =
        await ApiService.getTeams(); // Replace with /user/teams/ API if available
    setState(() {
      teams = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("My Teams")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: teams.length,
              itemBuilder: (context, index) {
                final team = teams[index];
                return ListTile(
                  title: Text(team['name']),
                  subtitle: Text("Members: ${team['member_count']}"),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TeamDetailScreen(teamId: team['id']),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
