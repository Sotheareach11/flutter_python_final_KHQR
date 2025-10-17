import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:app_links/app_links.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/reset_password_screen.dart';
import 'screens/admin_screen.dart'; // ✅ create this
import 'services/api_service.dart';

void main() {
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends ConsumerStatefulWidget {
  const MyApp({super.key});

  @override
  ConsumerState<MyApp> createState() => _MyAppState();
}

class _MyAppState extends ConsumerState<MyApp> {
  late final AppLinks _appLinks;
  StreamSubscription<Uri>? _sub;
  bool _isLoadingLink = true;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();

    // Handle initial link when the app starts
    final Uri? initialLink = await _appLinks.getInitialLink();
    if (initialLink != null &&
        initialLink.toString().startsWith('myapp://reset-password/')) {
      _handleLink(initialLink.toString());
    }

    // Listen for incoming links while the app is running
    _sub = _appLinks.uriLinkStream.listen((Uri uri) {
      if (uri.toString().startsWith('myapp://reset-password/')) {
        _handleLink(uri.toString());
      }
    });

    setState(() {
      _isLoadingLink = false;
    });
  }

  void _handleLink(String link) {
    final parts = link.split('/');
    if (parts.length >= 5) {
      final uid = parts[3];
      final token = parts[4];
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(uid: uid, token: token),
        ),
      );
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Task Manager',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
        textTheme: Theme.of(context).textTheme.apply(fontFamily: 'Roboto'),
      ),
      home: _isLoadingLink
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : FutureBuilder<bool>(
              future: ApiService.isLoggedIn(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (snapshot.data == true) {
                  // ✅ After login, check if the user is admin
                  return FutureBuilder<bool>(
                    future: _isAdmin(),
                    builder: (context, adminSnapshot) {
                      if (adminSnapshot.connectionState ==
                          ConnectionState.waiting) {
                        return const Scaffold(
                          body: Center(child: CircularProgressIndicator()),
                        );
                      }

                      if (adminSnapshot.data == true) {
                        return const AdminScreen(); // ✅ admin home
                      } else {
                        return const HomeScreen(); // normal user home
                      }
                    },
                  );
                } else {
                  return const LoginScreen();
                }
              },
            ),
    );
  }

  // ✅ Helper method to check admin flag from SharedPreferences
  Future<bool> _isAdmin() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool('isSuperUser') ?? false;
  }
}
