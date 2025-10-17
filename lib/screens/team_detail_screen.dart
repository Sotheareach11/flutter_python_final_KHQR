import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TeamDetailScreen extends StatefulWidget {
  final int teamId;
  const TeamDetailScreen({super.key, required this.teamId});

  @override
  State<TeamDetailScreen> createState() => _TeamDetailScreenState();
}

class _TeamDetailScreenState extends State<TeamDetailScreen> {
  List<dynamic> members = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    loadMembers();
  }

  Future<void> loadMembers() async {
    final data = await ApiService.getTeamMembers(widget.teamId);
    setState(() {
      members = data;
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Team Members")),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                return ListTile(
                  leading: const Icon(Icons.person),
                  title: Text(member['username']),
                  subtitle: Text(member['email']),
                );
              },
            ),
    );
  }
}
