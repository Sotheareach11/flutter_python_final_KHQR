import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // For Android Emulator
  static const String baseUrl = "http://10.0.2.2:8000/api/";

  // Use emulator base URL — change to your server in production
  static const String baseUrls = "http://10.0.2.2:8000/api/payments";

  // ------------------------------
  // 📌 1. Create Stripe Checkout Session
  // ------------------------------
  static Future<Map<String, dynamic>> createStripeCheckout({
    required int userId,
    required double amount,
    String currency = "usd",
  }) async {
    final url = Uri.parse("$baseUrls/stripe/create-checkout/");

    final response = await http.post(
      url,
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({
        "user_id": userId,
        "amount": amount,
        "currency": currency,
      }),
    );

    return jsonDecode(response.body);
  }

  // ------------------------------
  // 📌 2. Check Payment Status (Stripe)
  // ------------------------------
  static Future<Map<String, dynamic>> checkPaymentStripe({
    required String sessionId,
  }) async {
    final url = Uri.parse(
      "$baseUrls/check-payment-stripe/?session_id=$sessionId",
    );

    final res = await http.get(url);
    return jsonDecode(res.body);
  }

  // ---------------- AUTH ----------------
  static Future<void> refreshToken() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString('refresh_token');
    final res = await http.post(
      Uri.parse('${baseUrl}auth/token/refresh/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'refresh': refresh}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      prefs.setString('access_token', data['access']);
    }
  }

  static Future<bool> login(String username, String password) async {
    final url = Uri.parse('${baseUrl}auth/login/');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'username': username, 'password': password}),
    );

    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString('token', data['access']);
      await prefs.setString('refresh', data['refresh']);
      await prefs.setString('username', data['username']);
      await prefs.setString('email', data['email']);
      await prefs.setBool('isSuperUser', data['is_superuser'] ?? false);
      await prefs.setBool('isStaff', data['is_staff'] ?? false);
      await prefs.setInt('userId', data['user_id']);

      return true;
    }
    return false;
  }

  // Fetch all tasks (admin view)
  static Future<List> getAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}tasks/'); // Assuming admin sees all tasks

    final res = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  // Delete a task
  static Future<String> deleteTask(int id) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return "No authentication token found.";

      final url = Uri.parse('${baseUrl}tasks/$id/');
      final res = await http.delete(
        url,
        headers: {'Authorization': 'Bearer $token'},
      );

      print('DELETE URL: $url');
      print('Response: ${res.statusCode}');
      print('Body: ${res.body}');

      if (res.statusCode == 204 || res.statusCode == 200) {
        return "Task deleted successfully";
      } else if (res.statusCode == 403) {
        return "You are not allowed to delete this task.";
      } else if (res.statusCode == 404) {
        return "Task not found (it may not belong to you).";
      } else {
        return "Failed to delete task (code: ${res.statusCode})";
      }
    } catch (e) {
      return "Error deleting task: $e";
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey('token');
  }

  // ---------------- REGISTER ----------------
  static Future<String> registerUser(
    String username,
    String email,
    String password,
  ) async {
    final url = Uri.parse("${baseUrl}auth/register/");
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          "username": username,
          "email": email,
          "password": password,
          "user_type": "basic",
        }),
      );

      if (response.statusCode == 201) {
        return "Registration successful! Please check your email to verify your account.";
      } else {
        final body = jsonDecode(response.body);
        return body.toString();
      }
    } catch (e) {
      return "Error connecting to server: $e";
    }
  }

  // ---------------- TASKS ----------------
  static Future<List<dynamic>> fetchTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}tasks/');
    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<String> createTask(String title) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}tasks/');

    try {
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'title': title}),
      );

      print('Response status: ${res.statusCode}');
      print('Response body: ${res.body}');

      final msg = jsonDecode(res.body);

      if (res.statusCode == 201) {
        // ✅ Try to get the success message from backend
        if (msg is Map<String, dynamic>) {
          if (msg.containsKey('message')) {
            return msg['message']; // e.g. {"message": "Task created successfully"}
          } else if (msg.containsKey('detail')) {
            return msg['detail']; // e.g. {"detail": "Task created"}
          }
        }

        // fallback if backend returns plain text or unknown structure
        if (msg is String) {
          return msg;
        } else {
          return "Task created successfully."; // default fallback
        }
      } else {
        // Handle error messages
        if (msg is Map<String, dynamic>) {
          if (msg.containsKey('detail')) {
            return msg['detail'];
          } else if (msg.containsKey('non_field_errors')) {
            return msg['non_field_errors'][0];
          } else if (msg.containsKey('error')) {
            return msg['error'];
          } else if (msg.containsKey('message')) {
            return msg['message'];
          }
        }

        return "Error creating task: ${res.body}";
      }
    } catch (e) {
      return "Network error: $e";
    }
  }

  // ---------------- PAYMENTS ----------------
  static Future<Map<String, dynamic>> generateKhqr() async {
    final response = await http.get(
      Uri.parse("${baseUrl}api/payments/generate-khqr/"),
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception("Failed to generate KHQR");
    }
  }

  // ✅ Return status instead of using BuildContext
  static Future<String> checkPaymentStatus(String md5, String userId) async {
    final response = await http.get(
      Uri.parse(
        "${baseUrl}api/payments/check-payment/?md5=$md5&user_id=$userId",
      ),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final status = data['status'];
      return status; // return "PAID", "UNPAID", etc.
    } else {
      throw Exception("Error checking payment: ${response.body}");
    }
  }

  // ---------------- FORGOT PASSWORD ----------------
  static Future<String> forgotPassword(String email) async {
    final url = Uri.parse('${baseUrl}auth/forgot-password/');
    final res = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email}),
    );

    if (res.statusCode == 200) {
      return "Reset link sent to your email.";
    } else if (res.statusCode == 404) {
      return "User not found.";
    } else {
      return "Something went wrong.";
    }
  }

  static Future<String> resetPassword(
    String uid,
    String token,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse("${baseUrl}reset-password/$uid/$token/"),
      headers: {"Content-Type": "application/json"},
      body: jsonEncode({"password": password}),
    );

    if (response.statusCode == 200) {
      return "Password reset successful!";
    } else {
      final data = jsonDecode(response.body);
      return data["error"] ?? "Failed to reset password";
    }
  }

  // ---------------- ADMIN ----------------
  static Future<List<dynamic>> getAllUsers() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}auth/users/');
    final res = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    return [];
  }

  static Future<Map<String, dynamic>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}auth/users/info/');

    var response = await http.get(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else if (response.statusCode == 401) {
      await refreshToken();

      // Retry once after refreshing
      final newToken = prefs.getString('token');
      if (newToken != null && newToken.isNotEmpty) {
        response = await http.get(
          url,
          headers: {
            'Authorization': 'Bearer $newToken',
            'Content-Type': 'application/json',
          },
        );

        if (response.statusCode == 200) {
          return jsonDecode(response.body);
        }
      }

      // If still unauthorized, log out
      await logout();
      throw Exception('Unauthorized');
    } else {
      throw Exception('Failed to load user info');
    }
  }

  static Future<String> enableUser(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}auth/users/$id/enable/');
    final res = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return "User enabled successfully";
    }
    return "Failed to enable user";
  }

  static Future<String> disableUser(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}auth/users/$id/disable/');
    final res = await http.post(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );
    if (res.statusCode == 200) {
      return "User disabled successfully";
    }
    return "Failed to disable user";
  }

  // ---------------- team ----------------
  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');

    if (token == null) return null;

    final response = await http.get(
      Uri.parse('${baseUrl}auth/user-role/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['role']; // 'admin' or 'user'
    } else {
      throw Exception('Failed to load user role');
    }
  }

  static Future<List<dynamic>> getTeams() async {
    final response = await http.get(Uri.parse('${baseUrl}auth/teams/'));
    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to load teams');
    }
  }

  static Future<List<dynamic>> getTeamMembers(int teamId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) throw Exception('No authentication token found');

      final url = Uri.parse(
        '${baseUrl}auth/teams/$teamId/members/',
      ); // ✅ correct trailing slash
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // ✅ required
          'Content-Type': 'application/json',
        },
      );

      print('🔍 GET: $url');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('members')) {
          return data['members'];
        } else {
          throw Exception('Unexpected response format: $data');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Invalid or expired token');
      } else if (response.statusCode == 404) {
        throw Exception('Team not found');
      } else {
        throw Exception(
          'Failed to load members (status ${response.statusCode})',
        );
      }
    } catch (e) {
      print('❌ Error in getTeamMembers: $e');
      throw Exception('Failed to load members');
    }
  }

  static Future<String> addMemberToTeam(int teamId, int userId) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final url = Uri.parse('${baseUrl}auth/teams/$teamId/add_member/');
    final response = await http.post(
      url,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'user_id': userId}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['message'] ?? 'Member added successfully';
    } else {
      print('Error adding member: ${response.body}');
      return 'Failed to add member (${response.statusCode})';
    }
  }

  static Future<String> removeMemberFromTeam(int teamId, int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) return 'No authentication token found';

      final url = Uri.parse('${baseUrl}auth/teams/$teamId/remove_member/');
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'user_id': userId}),
      );

      print('Remove Member: ${response.statusCode} - ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['message'] ?? 'Member removed successfully';
      } else {
        return 'Failed to remove member (${response.statusCode})';
      }
    } catch (e) {
      print('Error removing member: $e');
      return 'Error removing member: $e';
    }
  }

  static Future<List<dynamic>> getAllTeams() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');
      if (token == null) {
        throw Exception('No authentication token found');
      }

      final url = Uri.parse('${baseUrl}auth/teams/'); // ✅ correct path
      final response = await http.get(
        url,
        headers: {
          'Authorization': 'Bearer $token', // ✅ required
          'Content-Type': 'application/json',
        },
      );

      print('🔍 GET: $url');
      print('Status: ${response.statusCode}');
      print('Body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // ✅ handle both list and dict responses
        if (data is List) {
          return data;
        } else if (data is Map && data.containsKey('results')) {
          return data['results'];
        } else if (data is Map && data.containsKey('teams')) {
          return data['teams'];
        } else {
          throw Exception('Unexpected response format: $data');
        }
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: invalid or expired token');
      } else {
        throw Exception('Failed to load teams (status ${response.statusCode})');
      }
    } catch (e) {
      print('❌ Error in getAllTeams: $e');
      throw Exception('Failed to load teams');
    }
  }

  static Future<String> createTeam(String name) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return 'No authentication token found';

    final response = await http.post(
      Uri.parse('${baseUrl}auth/teams/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'name': name}),
    );

    print('Create Team: ${response.statusCode} - ${response.body}');

    return response.statusCode == 201
        ? 'Team created successfully'
        : 'Failed to create team (${response.statusCode})';
  }

  static Future<String> deleteTeam(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    if (token == null) return 'No authentication token found';

    final response = await http.delete(
      Uri.parse('${baseUrl}auth/teams/$id/'),
      headers: {'Authorization': 'Bearer $token'},
    );

    print('Delete Team: ${response.statusCode} - ${response.body}');

    return response.statusCode == 204
        ? 'Team deleted successfully'
        : 'Failed to delete team (${response.statusCode})';
  }

  // static Future<String> deleteTeam(int id) async {
  //   final response = await http.delete(Uri.parse('${baseUrl}auth/teams/$id/'));
  //   return response.statusCode == 204
  //       ? 'Team deleted'
  //       : 'Failed to delete team';
  // }

  // Future<void> handleStripePayment() async {
  //   final response = await http.post(
  //     Uri.parse("http://10.0.2.2:8000/api/payments/stripe/create-checkout/"),
  //     headers: {"Content-Type": "application/json"},
  //     body: jsonEncode({"user_id": userId, "amount": 10.0}),
  //   );

  //   final data = jsonDecode(response.body);

  //   if (data["success"] == true) {
  //     final url = Uri.parse(data["checkout_url"]);
  //     await launchUrl(url, mode: LaunchMode.externalApplication);
  //   } else {
  //     print("Stripe error: ${data['error']}");
  //   }
  // }
}
