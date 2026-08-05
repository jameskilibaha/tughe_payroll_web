import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';
import 'app_config.dart';
import 'token_storage.dart';

/// Thin HTTP client for the FastAPI backend (`tughePayrollCore`).
///
/// This intentionally does not use a code-generated client (e.g. Chopper):
/// generated clients need `build_runner` to succeed for the app to compile
/// at all, which is an extra moving part this project doesn't need. A plain
/// `package:http` wrapper is easier to reason about and keeps the app
/// buildable without a codegen step.
class ApiClient {
  ApiClient({String? baseUrl, TokenStorage? tokenStorage, http.Client? httpClient})
      : baseUrl = baseUrl ?? apiBaseUrl,
        _tokenStorage = tokenStorage ?? TokenStorage(),
        _http = httpClient ?? http.Client();

  final String baseUrl;
  final TokenStorage _tokenStorage;
  final http.Client _http;

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final full = path.startsWith('http') ? path : '$baseUrl$path';
    final uri = Uri.parse(full);
    if (query == null || query.isEmpty) return uri;
    return uri.replace(queryParameters: {
      ...uri.queryParameters,
      ...query.map((k, v) => MapEntry(k, '$v')),
    });
  }

  Future<Map<String, String>> _headers({bool withBody = true}) async {
    final headers = <String, String>{'Accept': 'application/json'};
    if (withBody) headers['Content-Type'] = 'application/json';
    final token = await _tokenStorage.readToken();
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    return _send(() async => _http.get(_uri(path, query), headers: await _headers(withBody: false)));
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _send(() async =>
        _http.post(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _send(() async =>
        _http.put(_uri(path), headers: await _headers(), body: jsonEncode(body ?? {})));
  }

  Future<dynamic> delete(String path) async {
    return _send(() async => _http.delete(_uri(path), headers: await _headers(withBody: false)));
  }

  /// Downloads a binary/file response (PDF, DOCX, XLSX) as raw bytes.
  Future<List<int>> getBytes(String path) async {
    final response = await _http.get(_uri(path), headers: await _headers(withBody: false));
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return response.bodyBytes;
    }
    throw ApiException(_extractError(response.body) ?? 'Imeshindwa kupakua faili (${response.statusCode})',
        statusCode: response.statusCode);
  }

  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;
    try {
      response = await request();
    } on TimeoutException {
      throw ApiException('Muunganisho na seva umechelewa (timeout). Jaribu tena.');
    } catch (_) {
      throw ApiException(
          'Imeshindwa kuunganisha na seva. Hakikisha una mtandao na seva ya backend inafanya kazi.');
    }

    final statusCode = response.statusCode;
    if (statusCode >= 200 && statusCode < 300) {
      if (response.body.isEmpty) return null;
      try {
        return jsonDecode(response.body);
      } catch (_) {
        return response.body;
      }
    }

    if (statusCode == 401) {
      // Token missing/expired/invalid: clear it so the next screen redirect
      // sends the user back to a clean login instead of retry-looping.
      await _tokenStorage.clearToken();
    }

    final message = _extractError(response.body) ?? 'Hitilafu imetokea (status $statusCode)';
    throw ApiException(message, statusCode: statusCode);
  }

  String? _extractError(String body) {
    if (body.isEmpty) return null;
    try {
      final decoded = jsonDecode(body);
      if (decoded is Map && decoded['detail'] != null) {
        final detail = decoded['detail'];
        if (detail is String) return detail;
        return detail.toString();
      }
    } catch (_) {
      /* body wasn't JSON, e.g. a plain-text 500 */
    }
    return null;
  }
}
