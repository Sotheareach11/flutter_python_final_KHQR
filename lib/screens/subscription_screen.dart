import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:app_links/app_links.dart';
import '../services/api_service.dart';

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
  StreamSubscription<Uri>? _linkSub;
  late AppLinks _appLinks;

  static const String baseUrl = "http://10.0.2.2:8000/api/payments";

  @override
  void initState() {
    super.initState();
    _loadUserId();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _pollingTimer?.cancel();
    _linkSub?.cancel();
    super.dispose();
  }

  // Load user ID
  Future<void> _loadUserId() async {
    final prefs = await SharedPreferences.getInstance();
    userId = prefs.getInt('userId');
    setState(() {});
  }

  // Listen for Stripe deep links
  Future<void> _initDeepLinks() async {
    _appLinks = AppLinks();
    final Uri? initial = await _appLinks.getInitialLink();
    if (initial != null) _handleDeepLink(initial);

    _linkSub = _appLinks.uriLinkStream.listen(_handleDeepLink);
  }

  void _handleDeepLink(Uri uri) async {
    debugPrint("🔗 Deep link: $uri");

    if (uri.scheme == 'myapp' &&
        uri.host == 'payments' &&
        uri.path == '/success') {
      final sessionId = uri.queryParameters['session_id'];
      if (sessionId != null) {
        _startStripePolling(sessionId);
      }
    }
  }

  // Fix localhost for emulator
  String? _normalizeQrUrl(dynamic url) {
    if (url == null) return null;
    final uri = Uri.parse(url as String);
    final fixed = (uri.host == '127.0.0.1' || uri.host == 'localhost')
        ? uri.replace(host: '10.0.2.2')
        : uri;
    return fixed.toString();
  }

  // KHQR Payment
  Future<void> handleSubscribe() async {
    if (userId == null) return _showMsg("⚠️ Please log in first");

    setState(() {
      isLoading = true;
      isPaid = false;
    });

    try {
      final response = await http.get(Uri.parse("$baseUrl/generate-khqr/"));
      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
        qrImageUrl = _normalizeQrUrl(data['qr_image_url']);
        deeplink = data['deeplink'];
        md5 = data['md5'];
        isLoading = false;
        setState(() {});

        startPaymentPolling(); // KHQR Polling
      } else {
        throw Exception("Backend error");
      }
    } catch (e) {
      _showMsg("⚠️ Error: $e");
      setState(() => isLoading = false);
    }
  }

  // Stripe Checkout
  Future<void> handleStripePayment() async {
    if (userId == null) return _showMsg("⚠️ Please log in first");

    setState(() => isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("$baseUrl/stripe/create-checkout/"),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "user_id": userId,
          "amount": 10.00,
          "currency": "usd",
        }),
      );

      setState(() => isLoading = false);

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        final checkoutUrl = Uri.parse(data["checkout_url"]);
        final sessionId = data["session_id"];

        if (!await launchUrl(
          checkoutUrl,
          mode: LaunchMode.externalApplication,
        )) {
          _showMsg("⚠️ Could not open Stripe Checkout");
        } else {
          // 🔥 Start Stripe polling here
          if (sessionId != null) {
            _startStripePolling(sessionId);
          }
        }

        _startStripePolling(sessionId);
      } else {
        _showMsg("Stripe Error: ${data['error'] ?? 'unknown'}");
      }
    } catch (e) {
      _showMsg("⚠️ Stripe Error: $e");
    }
  }

  // 🔥 Stripe Payment Polling
  void _startStripePolling(String sessionId) {
    _pollingTimer = Timer.periodic(Duration(seconds: 3), (timer) async {
      final data = await ApiService.checkPaymentStripe(sessionId: sessionId);

      print("Stripe status: $data");

      if (data["status"] == "PAID") {
        timer.cancel();
        setState(() => isPaid = true);
        _showMsg("Subscription activated!");
      }
    });
  }

  // KHQR Polling
  void startPaymentPolling() {
    if (md5 == null || userId == null) return;

    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (timer) async {
      try {
        final res = await http.get(
          Uri.parse("$baseUrl/check-payment/?md5=$md5&user_id=$userId"),
        );
        final status = jsonDecode(res.body)['status'];

        if (status == "PAID") {
          timer.cancel();
          setState(() => isPaid = true);
          _showMsg("✅ KHQR Payment successful!");
        }
      } catch (e) {
        debugPrint("Polling error: $e");
      }
    });
  }

  // UI Message
  void _showMsg(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Subscription")),
      body: Center(
        child: userId == null
            ? const Text("🔒 Please log in to subscribe")
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
                    style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 10),
                  Text("Thank you for your payment 🎉"),
                ],
              )
            : _buildPaymentOptions(),
      ),
    );
  }

  Widget _buildPaymentOptions() {
    return qrImageUrl == null
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
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "Subscribe for just \$10/month.",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: handleSubscribe,
                icon: const Icon(Icons.qr_code),
                label: const Text("Pay with KHQR (Bakong)"),
              ),
              const SizedBox(height: 10),
              ElevatedButton.icon(
                onPressed: handleStripePayment,
                icon: const Icon(Icons.credit_card),
                label: const Text("Pay with Stripe (Card)"),
              ),
            ],
          )
        : Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "Scan to Pay with Bakong",
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 20),
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  qrImageUrl!,
                  width: 250,
                  height: 250,
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 20),
              if (deeplink != null)
                ElevatedButton.icon(
                  onPressed: () async {
                    final uri = Uri.parse(deeplink!);
                    if (!await launchUrl(
                      uri,
                      mode: LaunchMode.externalApplication,
                    )) {
                      _showMsg("Could not open Bakong app");
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: const Text("Open in Bakong App"),
                ),
            ],
          );
  }
}
