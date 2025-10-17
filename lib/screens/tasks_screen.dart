import 'package:flutter/material.dart';
import '../services/api_service.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  List tasks = [];
  final titleCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    loadTasks();
  }

  void loadTasks() async {
    tasks = await ApiService.fetchTasks();
    setState(() {});
  }

  void addTask() async {
    if (titleCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Task title cannot be empty")),
      );
      return;
    }

    final msg = await ApiService.createTask(titleCtrl.text);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    titleCtrl.clear();
    loadTasks();
  }

  void deleteTask(int id) async {
    final msg = await ApiService.deleteTask(id);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    loadTasks(); // Refresh list
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Tasks')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: titleCtrl,
              decoration: const InputDecoration(labelText: 'New Task'),
            ),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: addTask, child: const Text('Add Task')),
            const SizedBox(height: 20),
            Expanded(
              child: ListView.builder(
                itemCount: tasks.length,
                itemBuilder: (_, i) {
                  final task = tasks[i];
                  return Card(
                    child: ListTile(
                      title: Text(task['title']),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () {
                          showDialog(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text("Delete Task"),
                              content: Text(
                                "Are you sure you want to delete '${task['title']}'?",
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx),
                                  child: const Text("Cancel"),
                                ),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(ctx);
                                    deleteTask(task['id']);
                                  },

                                  child: const Text(
                                    "Delete",
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
