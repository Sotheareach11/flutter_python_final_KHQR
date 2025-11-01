import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_service.dart';
import 'login_screen.dart';

class AdminScreen extends StatefulWidget {
  final bool isAdmin;
  const AdminScreen({super.key, this.isAdmin = true});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List users = [];
  List tasks = [];
  List teams = [];

  final titleCtrl = TextEditingController();
  final teamCtrl = TextEditingController();

  bool isLoading = true;
  bool isAddingTask = false;
  bool isAddingTeam = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: widget.isAdmin ? 3 : 1, vsync: this);
    fetchData();
  }

  Future<void> fetchData() async {
    setState(() => isLoading = true);

    try {
      await Future.wait([
        if (widget.isAdmin) fetchUsers(),
        fetchTasks(),
        if (widget.isAdmin) fetchTeams(),
      ]);
    } catch (e, stackTrace) {
      debugPrint('Error in fetchData: $e');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchUsers() async {
    users = await ApiService.getAllUsers();
  }

  Future<void> fetchTasks() async {
    tasks = await ApiService.getAllTasks();
  }

  Future<void> fetchTeams() async {
    teams = await ApiService.getAllTeams();
  }

  Future<void> refreshTasks() async {
    await fetchTasks();
    setState(() {});
  }

  Future<void> refreshTeams() async {
    await fetchTeams();
    setState(() {});
  }

  void toggleUserStatus(int id, bool isActive) async {
    setState(() => isLoading = true);
    String message;
    if (isActive) {
      message = await ApiService.disableUser(id);
    } else {
      message = await ApiService.enableUser(id);
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    await fetchUsers();
    setState(() => isLoading = false);
  }

  Future<void> addTask() async {
    final title = titleCtrl.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a task title')),
      );
      return;
    }

    setState(() => isAddingTask = true);
    final msg = await ApiService.createTask(title);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    titleCtrl.clear();
    await refreshTasks();
    setState(() => isAddingTask = false);
  }

  Future<void> addTeam() async {
    final name = teamCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter a team name')));
      return;
    }

    setState(() => isAddingTeam = true);
    final msg = await ApiService.createTeam(name);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

    teamCtrl.clear();
    await refreshTeams();
    setState(() => isAddingTeam = false);
  }

  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();

    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final tabs = widget.isAdmin
        ? const [
            Tab(icon: Icon(Icons.people), text: 'Users'),
            Tab(icon: Icon(Icons.task), text: 'Tasks'),
            Tab(icon: Icon(Icons.group), text: 'Teams'),
          ]
        : const [Tab(icon: Icon(Icons.task), text: 'Tasks')];

    final views = widget.isAdmin
        ? [_buildUsersTab(), _buildTasksTab(), _buildTeamsTab()]
        : [_buildTasksTab()];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isAdmin ? 'Admin Dashboard' : 'User Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Confirm Logout'),
                  content: const Text('Are you sure you want to log out?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Logout'),
                    ),
                  ],
                ),
              );
              if (confirm == true) _logout();
            },
          ),
        ],
        bottom: TabBar(controller: _tabController, tabs: tabs),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(controller: _tabController, children: views),
    );
  }

  // USERS TAB
  Widget _buildUsersTab() {
    if (users.isEmpty) {
      return const Center(child: Text('No users found'));
    }
    return ListView.builder(
      itemCount: users.length,
      itemBuilder: (_, i) {
        final user = users[i];
        final bool isActive = user['is_active'] ?? false;
        final userType = user['user_type'] ?? 'basic';

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isActive ? Colors.green : Colors.redAccent,
              child: Icon(
                isActive ? Icons.person : Icons.block,
                color: Colors.white,
              ),
            ),
            title: Text(user['username'] ?? 'Unknown'),
            subtitle: Text('Type: $userType • ${user['email'] ?? ''}'),
            trailing: ElevatedButton(
              onPressed: () => toggleUserStatus(user['id'], isActive),
              style: ElevatedButton.styleFrom(
                backgroundColor: isActive ? Colors.red : Colors.green,
              ),
              child: Text(isActive ? 'Disable' : 'Enable'),
            ),
          ),
        );
      },
    );
  }

  // TASKS TAB
  Widget _buildTasksTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          if (widget.isAdmin) ...[
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(
                labelText: 'New Task',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: isAddingTask ? null : addTask,
              child: Text(isAddingTask ? 'Adding...' : 'Add Task'),
            ),
            const SizedBox(height: 20),
          ],
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshTasks,
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  final task = tasks[i];
                  final title = task['title'] ?? 'Untitled';
                  final isCompleted = task['is_completed'] ?? false;

                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      leading: Icon(
                        isCompleted
                            ? Icons.check_circle
                            : Icons.circle_outlined,
                        color: isCompleted ? Colors.green : Colors.grey,
                      ),
                      title: Text(title),
                      trailing: widget.isAdmin
                          ? IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (ctx) => AlertDialog(
                                    title: const Text('Confirm Delete'),
                                    content: Text('Delete task "$title"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  final msg = await ApiService.deleteTask(
                                    task['id'],
                                  );
                                  ScaffoldMessenger.of(
                                    context,
                                  ).showSnackBar(SnackBar(content: Text(msg)));
                                  await refreshTasks();
                                }
                              },
                            )
                          : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // TEAMS TAB (Admin only)
  Widget _buildTeamsTab() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          TextField(
            controller: teamCtrl,
            decoration: const InputDecoration(
              labelText: 'New Team',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: isAddingTeam ? null : addTeam,
            child: Text(isAddingTeam ? 'Adding...' : 'Add Team'),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: RefreshIndicator(
              onRefresh: refreshTeams,
              child: ListView.builder(
                itemCount: teams.length,
                itemBuilder: (_, i) {
                  final team = teams[i];
                  return Card(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    child: ListTile(
                      title: Text(team['name'] ?? 'Unnamed Team'),
                      subtitle: Text('Members: ${team['member_count'] ?? 0}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(
                              Icons.person_add,
                              color: Colors.blue,
                            ),
                            onPressed: () => _showAddMemberDialog(team['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.people, color: Colors.green),
                            onPressed: () => _showMembersDialog(team['id']),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Confirm Delete'),
                                  content: Text(
                                    'Delete team "${team['name']}"?',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(ctx, false),
                                      child: const Text('Cancel'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                final msg = await ApiService.deleteTeam(
                                  team['id'],
                                );
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(msg)));
                                await refreshTeams();
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- Dialog to Add Member ---
  void _showAddMemberDialog(int teamId) async {
    int? selectedUserId;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Member to Team'),
        content: DropdownButtonFormField<int>(
          value: selectedUserId,
          hint: const Text('Select a user'),
          items: users.map<DropdownMenuItem<int>>((user) {
            return DropdownMenuItem<int>(
              value: user['id'],
              child: Text('${user['username']}'),
            );
          }).toList(),
          onChanged: (value) => selectedUserId = value,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (selectedUserId == null) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please select a user')),
                );
                return;
              }

              Navigator.pop(ctx);
              final msg = await ApiService.addMemberToTeam(
                teamId,
                selectedUserId!,
              );
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(msg)));
              await refreshTeams();
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  // --- Dialog to View Members ---
  void _showMembersDialog(int teamId) async {
    final members = await ApiService.getTeamMembers(teamId);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Team Members'),
        content: members.isEmpty
            ? const Text('No members found')
            : SizedBox(
                width: double.maxFinite,
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: members.length,
                  itemBuilder: (_, i) {
                    final member = members[i];
                    return ListTile(
                      title: Text(member['username']),
                      subtitle: Text(member['email']),
                    );
                  },
                ),
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
