import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthService {
  final backendUrl = "http://192.168.18.94:8000/auth";
  final FlutterSecureStorage storage = const FlutterSecureStorage();

  Future<Map<String, String>> _getCookieHeader() async {
  final headers = {'Content-Type': 'application/json'};
  
  // Build cookie string properly
  final List<String> cookies = [];
  
  final accessToken = await storage.read(key: 'access_token');
  final refreshToken = await storage.read(key: 'refresh_token');
  final username = await storage.read(key: 'username');  // Add this
  
  if (accessToken != null) {
    cookies.add('access_token=$accessToken');
  }
  if (refreshToken != null) {
    cookies.add('refresh_token=$refreshToken');
  }
  if (username != null) {
    cookies.add('username=$username');  // Add username cookie
  }
  
  if (cookies.isNotEmpty) {
    headers['Cookie'] = cookies.join('; ');
  }
  
  return headers;
}

 Future<void> _storeCookies(http.Response response) async {
  final rawCookie = response.headers['set-cookie'];
  if (rawCookie == null) return;

  // Multiple cookies are comma-separated
  final cookies = rawCookie.split(',');

  for (final cookie in cookies) {
    final parts = cookie.split(';').first.split('=');
    if (parts.length < 2) continue;

    final key = parts[0].trim();
    final value = parts.sublist(1).join('=').trim(); // handles '=' in values

    if (key == 'access_token') {
      await storage.write(key: 'access_token', value: value);
      debugPrint('Stored access_token');
    } else if (key == 'refresh_token') {
      await storage.write(key: 'refresh_token', value: value);
      debugPrint('Stored refresh_token');
    } else if (key == 'username') {
      await storage.write(key: 'username', value: value);
      debugPrint('Stored username: $value');
    }
  }
}


  Future<String> signupuser({
    required String name,
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'name': name, 'email': email, 'password': password}),
    );
    debugPrint('Response is this: $response.header');

    if (response.statusCode != 200) {
      debugPrint('Signup failed: ${response.body}');
      throw json.decode(response.body)['detail'] ?? 'Signup failed';
    }
    return json.decode(response.body)['message'] ??
        'Signup successful,Please veify your email';
  }

  Future<String> confirmSignup({
    required String email,
    required String otp,
  }) async {
    final response = await http.post(
      Uri.parse('$backendUrl/confirm-signup'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'email': email, 'otp': otp}),
    );
    debugPrint('Response is this: $response.header');
    if (response.statusCode != 200) {
      debugPrint('Signup failed: ${response.body}');
      throw json.decode(response.body)['detail'] ?? 'Signup failed';
    }
    return json.decode(response.body)['message'] ??
        'Account Confirmed,Please Login';
  }

Future<String> loginuser({
  required String email,
  required String password,
}) async {
  final response = await http.post(
    Uri.parse('$backendUrl/login'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'password': password}),
  );
  
  debugPrint('Login Response: ${response.statusCode}');
  
  await _storeCookies(response);
  
  // Also manually store username since backend might not set it as cookie
  await storage.write(key: 'username', value: email);
  
  if (response.statusCode != 200) {
    debugPrint('Login failed: ${response.body}');
    throw json.decode(response.body)['detail'] ?? 'Login failed';
  }
  
  // Call isAuthenticated to verify and get user data
  final isAuth = await isAuthenticated();
  if (!isAuth) {
    throw 'Login failed - could not authenticate';
  }
  
  return json.decode(response.body)['message'] ?? 'Login successful';
}

Future<bool> isAuthenticated({int count = 0}) async {
  if (count > 1) {
    return false; // Prevent infinite recursion
  }
  
  final cookieHeaders = await _getCookieHeader();
  final res = await http.get(
    Uri.parse("$backendUrl/me"),
    headers: cookieHeaders,
  );

  debugPrint('Auth check: ${res.statusCode}');
  
  if (res.statusCode != 200) {
    try {
      await refreshToken();
      // Recursively call with increased count
      return await isAuthenticated(count: count + 1);
    } catch (e) {
      debugPrint('Refresh failed: $e');
      return false;
    }
  } else {
    // Store user data if needed
    try {
      final body = jsonDecode(res.body);
      final user = body['user'];
      if (user != null && user['sub'] != null) {
        await storage.write(
          key: 'user_cognito_sub',
          value: user['sub'].toString(),
        );
      }
    } catch (e) {
      debugPrint('Error parsing user data: $e');
    }
    return true;
  }
}

Future<String> refreshToken() async {
  final cookieHeaders = await _getCookieHeader();
  final res = await http.post(
    Uri.parse("$backendUrl/refresh"),
    headers: cookieHeaders,
  );

  debugPrint('Refresh Token Response: ${res.statusCode} - ${res.body}');

  if (res.statusCode == 200) {
    await _storeCookies(res);
    return 'Token refreshed successfully';
  } else {
    // Clear invalid tokens
    await storage.delete(key: 'access_token');
    await storage.delete(key: 'refresh_token');
    throw json.decode(res.body)['detail'] ?? 'Token refresh failed';
  }
}



}
