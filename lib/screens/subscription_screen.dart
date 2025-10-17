import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  String? qrImageUrl;
  String? deeplink;
  String? md5;
  int? userId;
  bool isLoading = false;
  bool isPaid = false;
  Timer? _pollingTimer;

  // Use 10.0.2.2 to access your backend from Android emulator
  static const String baseUrl = "http://10.0.2.2:8000/api/payments";

  @override
  void initState() {
    super.initState();
    _loadUserId();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    super.dispose();
  }

  // ✅ Load logged-in user ID from SharedPreferences
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getInt('userId');
    setState(() {
      userId = id;
    });
    debugPrint("✅ Logged-in userId: $userId");
  }

  // ✅ Normalize backend URL for emulator (localhost → 10.0.2.2)
  String? _normalizeQrUrl(dynamic url) {
    if (url == null) return null;
    final uri = Uri.parse(url as String);
    final needsRewrite = (uri.host == '127.0.0.1' || uri.host == 'localhost');
    final fixed = needsRewrite ? uri.replace(host: '10.0.2.2') : uri;
    // Add cache-buster timestamp
    final withTs = fixed.replace(
      queryParameters: {
        ...fixed.queryParameters,
        'ts': DateTime.now().millisecondsSinceEpoch.toString(),
      },
    );
    return withTs.toString();
  }

  // ✅ Generate KHQR
  Future<void> handleSubscribe() async {
    if (userId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("⚠️ Please log in first")));
      return;
    }

    setState(() {
      isLoading = true;
      isPaid = false;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/generate-khqr/"));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          qrImageUrl =
              _normalizeQrUrl(data['qr_image_url']) ??
              'https://img.freepik.com/free-vector/scan-me-qr-code_78370-9714.jpg';
          deeplink = data['deeplink'];
          md5 = data['md5'];
          isLoading = false;
        });

        startPaymentPolling();
      } else {
        throw Exception("Backend returned ${response.statusCode}");
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        qrImageUrl =
            'https://img.freepik.com/free-vector/scan-me-qr-code_78370-9714.jpg';
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("⚠️ Error: $e — showing test QR")));
    }
  }

  // ✅ Periodically check payment
  void startPaymentPolling() {
    if (md5 == null || userId == null) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final status = await checkPaymentStatus(md5!, userId!);
        if (status == "PAID" && mounted) {
          setState(() {
            isPaid = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("✅ Payment successful! Subscription activated."),
              backgroundColor: Colors.green,
            ),
          );
          _pollingTimer?.cancel();
        } else {
          debugPrint("Current payment status: $status");
        }
      } catch (e) {
        debugPrint("Error checking payment: $e");
      }
    });
  }

  // ✅ Check payment status API
  Future<String> checkPaymentStatus(String md5, int userId) async {
    final response = await http.get(
      Uri.parse("$baseUrl/check-payment/?md5=$md5&user_id=$userId"),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['status'];
    } else {
      throw Exception("Failed to check payment: ${response.body}");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subscription")),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: userId == null
              ? const Text(
                  "🔒 Please log in to subscribe",
                  style: TextStyle(fontSize: 18, color: Colors.grey),
                )
              : isLoading
              ? const CircularProgressIndicator()
              : isPaid
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.verified, color: Colors.green, size: 100),
                    SizedBox(height: 20),
                    Text(
                      "Subscription Activated!",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 10),
                    Text(
                      "Thank you for your payment 🎉",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                )
              : qrImageUrl == null
              ? Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.workspace_premium,
                      color: Colors.amber,
                      size: 90,
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      "Upgrade to PRO",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 10),
                    const Text(
                      "Scan the KHQR to subscribe for just \$10/month.",
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton.icon(
                      onPressed: handleSubscribe,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.qr_code, color: Colors.white),
                      label: const Text(
                        "Generate KHQR",
                        style: TextStyle(fontSize: 16, color: Colors.white),
                      ),
                    ),
                  ],
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      "Scan to Pay with Bakong",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ QR Image
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(
                        qrImageUrl!,
                        width: 250,
                        height: 250,
                        fit: BoxFit.contain,
                        loadingBuilder: (context, child, progress) {
                          if (progress == null) return child;
                          return const CircularProgressIndicator();
                        },
                        errorBuilder: (context, error, stackTrace) {
                          debugPrint(
                            "❌ Image load error for $qrImageUrl: $error",
                          );
                          return const Icon(Icons.broken_image, size: 100);
                        },
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ✅ Open Bakong App
                    if (deeplink != null)
                      ElevatedButton.icon(
                        onPressed: () async {
                          final uri = Uri.parse(deeplink!);
                          if (!await launchUrl(
                            uri,
                            mode: LaunchMode.externalApplication,
                          )) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Could not open Bakong app"),
                              ),
                            );
                          }
                        },
                        icon: const Icon(Icons.open_in_new),
                        label: const Text("Open in Bakong App"),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}
