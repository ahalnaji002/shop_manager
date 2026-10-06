import 'dart:convert';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;

class CloudFunctionException implements Exception {
  final String code;
  final String message;

  const CloudFunctionException(this.code, this.message);

  @override
  String toString() => '$code: $message';
}

/// Calls Firebase callable functions over HTTPS so the same secure path works
/// on every configured Flutter target, including Windows desktop.
class CloudFunctionClient {
  static const _timeout = Duration(seconds: 30);
  static final _client = http.Client();

  static Future<Map<String, dynamic>> call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw const CloudFunctionException(
        'unauthenticated',
        'سجّل الدخول أولاً.',
      );
    }
    final token = await user.getIdToken();
    if (token == null || token.isEmpty) {
      throw const CloudFunctionException(
        'unauthenticated',
        'تعذر التحقق من الحساب.',
      );
    }

    final projectId = Firebase.app().options.projectId;
    final uri = Uri.https(
      'us-central1-$projectId.cloudfunctions.net',
      functionName,
    );
    late final http.Response response;
    try {
      response = await _client
          .post(
            uri,
            headers: {
              'Authorization': 'Bearer $token',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'data': data}),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const CloudFunctionException(
        'deadline-exceeded',
        'انتهت مهلة الاتصال بالخادم.',
      );
    } on http.ClientException {
      throw const CloudFunctionException(
        'unavailable',
        'تعذر الاتصال بالخادم.',
      );
    }

    Map<String, dynamic> body;
    try {
      body = jsonDecode(response.body) as Map<String, dynamic>;
    } on FormatException {
      throw CloudFunctionException(
        'internal',
        'استجابة غير مفهومة من الخادم (${response.statusCode}).',
      );
    }
    final error = body['error'];
    if (error is Map<String, dynamic>) {
      throw CloudFunctionException(
        (error['status'] ?? 'internal').toString().toLowerCase().replaceAll(
          '_',
          '-',
        ),
        (error['message'] ?? 'تعذر تنفيذ العملية.').toString(),
      );
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw CloudFunctionException(
        'internal',
        'تعذر تنفيذ العملية (${response.statusCode}).',
      );
    }
    final result = body['result'] ?? body['data'];
    if (result is! Map<String, dynamic>) {
      throw const CloudFunctionException(
        'internal',
        'استجابة العملية غير صالحة.',
      );
    }
    return result;
  }
}
