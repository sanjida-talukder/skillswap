
import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'http://127.0.0.1:8000';

  // Register API
  static Future<Map<String, dynamic>> register({
    required String uniqueUsername,
    required String email,
    required String password,
    required String fullName,
    required String teachSkill,
    required String learnSkill,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/register'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'unique_username': uniqueUsername,
        'email': email,
        'password': password,
        'full_name': fullName,
        'teach_skill': teachSkill,
        'learn_skill': learnSkill,
      }),
    );

    return _handleResponse(response);
  }

  // Check Username Availability API
  static Future<Map<String, dynamic>> checkUsername(
    String username,
  ) async {
    final encodedUsername = Uri.encodeComponent(username.trim());

    final response = await http.get(
      Uri.parse('$baseUrl/check-username/$encodedUsername'),
    );

    return _handleResponse(response);
  }


  // Login API
  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/login'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'email': email,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  // Add / Edit User Skills API
  static Future<Map<String, dynamic>> updateSkills({
    required String userId,
    required String teachSkill,
    required String learnSkill,
  }) async {
    final response = await http.put(
      Uri.parse('$baseUrl/user-skills'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'user_id': userId,
        'teach_skill': teachSkill,
        'learn_skill': learnSkill,
      }),
    );

    return _handleResponse(response);
  }

  // Handle API response
  static Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    final Map<String, dynamic> data =
        jsonDecode(response.body) as Map<String, dynamic>;

    if (response.statusCode >= 200 &&
        response.statusCode < 300) {
      return data;
    }

    throw Exception(
      data['detail'] ??
          data['message'] ??
          'Request failed: ${response.statusCode}',
    );
  }
  // Find Skills API
  static Future<List<dynamic>> findSkills({
    String search = '',
  }) async {
    final uri = Uri.parse('$baseUrl/skills').replace(
      queryParameters: {'search': search},
    );

    final response = await http.get(uri);
    final data = _handleResponse(response);

    return data['skills'] as List<dynamic>;
  }

}

