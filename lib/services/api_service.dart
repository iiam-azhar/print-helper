import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../auth/login_screen.dart';
import '../services/call_device_service.dart';
import '../services/db_service.dart';
import '../services/navigation_service.dart';
import '../utils/console_util.dart';
import '../utils/custom_exceptions.dart';
import '../widgets/toasts.dart';
import 'api_routes.dart';

class ApiService {
  ApiService._internal();

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  static const _timeOut = 30;
  static final Random _rng = Random();
  static bool _isHandlingUnauthorized = false;

  /// Create IOClient that bypasses SSL
  IOClient _getBypassedClient() {
    final HttpClient httpClient = HttpClient()
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => true;

    return IOClient(httpClient);
  }

  /// GET Request (Handles API and Direct URLs)
  Future<dynamic> getDataFromApi({
    required String api,
    String? url,
    dynamic headers,
    bool decode = true,
    bool showRes = true,
    int timeOut = _timeOut,
  }) async {
    final Uri uri = _buildUri(path: api, url: url);
    final client = _getBypassedClient();

    try {
      final response = await client
          .get(uri, headers: headers)
          .timeout(Duration(seconds: timeOut));

      return _response(response, showRes, decode: decode);
    } on SocketException {
      throw FetchDataException('No Internet Connection', '$uri');
    } on TimeoutException {
      throw ApiNotRespondingException('API Not Responding', '$uri');
    }
  }

  /// POST / PUT / DELETE Request (Handles API and File Uploads)
  Future<dynamic> postDataToApi({
    required String api,
    dynamic headers,
    dynamic payload,
    List<String> filePaths = const [],
    List<String> fileNames = const [],
    List<String> fileKeys = const [],
    bool multipart = false,
    bool isPut = false,
    bool isDelete = false,
    bool showRes = true,
    int timeOut = _timeOut,
  }) async {
    final Uri uri = _buildUri(path: api);
    final client = _getBypassedClient();

    try {
      if (multipart) {
        final method = isPut ? 'PUT' : 'POST';

        final request = http.MultipartRequest(method, uri);

        // Handle Map<String, dynamic> and convert values to String,
        // especially for List values which should be added multiple times.
        if (payload is Map) {
          payload.forEach((key, value) {
            final fieldKey = key.toString();
            if (value is List) {
              final baseKey = fieldKey.replaceAll('[]', '');
              for (int i = 0; i < value.length; i++) {
                request.fields['$baseKey[$i]'] = value[i].toString();
              }
            } else {
              request.fields[fieldKey] = value.toString();
            }
          });
        }

        if (headers != null) request.headers.addAll(headers);

        for (int i = 0; i < filePaths.length; i++) {
          if (filePaths[i].isNotEmpty && fileNames[i].isNotEmpty) {
            final image = await http.MultipartFile.fromPath(
              fileKeys[i],
              filePaths[i],
              filename: fileNames[i],
            );
            request.files.add(image);
          }
        }

        final streamedResponse = await client.send(request).timeout(
          Duration(seconds: timeOut),
        );
        final response = await http.Response.fromStream(streamedResponse);
        return _response(response, showRes);
      } else {
        final normalizedHeaders = headers == null
            ? null
            : Map<String, String>.from(headers as Map);

        final hasJsonContentType =
            normalizedHeaders?.entries.any((entry) {
              final key = entry.key.toLowerCase();
              final value = entry.value.toLowerCase();
              return key == 'content-type' &&
                  value.contains('application/json');
            }) ??
            false;

        final requestBody = hasJsonContentType && payload is! String && payload != null
            ? jsonEncode(payload)
            : payload;


        Future<http.Response> res;
        if (isDelete) {
          res = client.delete(uri, headers: normalizedHeaders, body: requestBody);
        } else if (isPut) {
          res = client.put(uri, headers: normalizedHeaders, body: requestBody);
        } else {
          res = client.post(uri, headers: normalizedHeaders, body: requestBody);
        }
        final response = await res.timeout(Duration(seconds: timeOut));

        return _response(response, showRes);
      }
    } on SocketException {
      throw FetchDataException('No Internet Connection', '$uri');
    } on TimeoutException {
      throw ApiNotRespondingException('API Not Responding', '$uri');
    }
  }

  /// Builds a URI with automatic query parameters.
  Uri _buildUri({String path = '', String? url}) {
    final Uri uri;

    if (url != null) {
      uri = Uri.parse(url);
    } else {
      uri = Uri.parse('${ApiRoutes.baseUrl}$path');
    }

    return uri.replace(
      queryParameters: {
        ...uri.queryParameters,
        'v': '${_rng.nextInt(100)}',
        // 'lang': 'en',
      },
    );
  }

  dynamic _response(
    http.Response response,
    bool showRes, {
    bool decode = true,
  }) {
    dynamic result;
    switch (response.statusCode) {
      case 200:
      case 201:
        result = _processResponse(response, false, showRes, decode: decode);
        break;
      case 204:
        // 204 No Content — success with no body (common for DELETE requests)
        printData(
          title: '\x1B[32mstatus 204 (No Content)\x1B[0m',
          data: 'url: ${response.request?.url}',
        );
        result = {'success': true, 'message': 'Operation completed successfully'};
        break;
      case 302:
        // Some Laravel endpoints redirect on success (e.g. PUT requests).
        // Treat a 302 whose Location points back to the app base URL as a success
        // and return a synthetic success map so callers don't break.
        final location = response.headers['location'] ?? '';
        if (location.isNotEmpty) {
          printData(
            title: '\x1B[33m302 Redirect → $location\x1B[0m',
            data: 'Treating as success (no body to decode)',
          );
          result = {'success': true, 'redirected': true, 'location': location};
        } else {
          result = _processResponse(response, true, showRes, decode: decode);
        }
        break;
      case 400:
      case 401:
      case 403:
      case 500:
      default:
        result = _processResponse(response, true, showRes, decode: decode);
        break;
    }

    if (_shouldForceReauthentication(
      response.statusCode,
      result,
      response.request?.url,
    )) {
      final sessionMessage =
          result is Map &&
              (result['message']?.toString().trim().isNotEmpty ?? false)
          ? result['message'].toString()
          : 'Session expired. Please sign in again.';
      unawaited(_clearSessionAndNavigateToLogin(message: sessionMessage));
    }

    return result;
  }

  bool _shouldForceReauthentication(
    int statusCode,
    dynamic payload,
    Uri? requestUrl,
  ) {
    // For mailbox listing endpoint only (`/api/mail?folder=...`),
    // do not clear app session/shared prefs on provider auth failures.
    if (_isMailListEndpoint(requestUrl)) {
      return false;
    }

    if (statusCode != 401 || payload is! Map) return false;

    final data = Map<String, dynamic>.from(payload);
    final tokenExpired = data['token_expired'] == true;
    final requiresReauth = data['requires_reauthentication'] == true;
    final errorCode = (data['error_code'] ?? '').toString().toUpperCase();
    final message = (data['message'] ?? '').toString().toLowerCase();

    return tokenExpired ||
        requiresReauth ||
        errorCode == 'UNAUTHENTICATED' ||
        message.contains('unauthenticated');
  }

  bool _isMailListEndpoint(Uri? requestUrl) {
    if (requestUrl == null) return false;

    final path = requestUrl.path.toLowerCase();
    if (!path.endsWith('/mail')) return false;

    final folder = requestUrl.queryParameters['folder'];
    return folder != null && folder.trim().isNotEmpty;
  }

  Future<void> _clearSessionAndNavigateToLogin({
    required String message,
  }) async {
    if (_isHandlingUnauthorized) return;
    _isHandlingUnauthorized = true;

    try {
      showToast(message: message);

      try {
        await CallDeviceService.unregister();
      } catch (_) {}

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      await DbService.clearAllData();

      final nav = NavigationService.navigatorKey.currentState;
      if (nav != null) {
        nav.pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
          (route) => false,
        );
      }
    } finally {
      _isHandlingUnauthorized = false;
    }
  }

  dynamic _processResponse(
    http.Response response,
    bool isError,
    bool showRes, {
    bool decode = true,
  }) {
    final sts = isError ? '\x1B[31m' : '\x1B[32m';
    const uClr = '\x1B[33m';
    const dClr = '\x1B[35m';
    const stp = '\x1B[0m';

    final rStCode = response.statusCode;
    final rUrl = response.request?.url;

    Platform.isAndroid
        ? printData(
            title: '${sts}status $rStCode$stp$uClr url : $rUrl$stp\n',
            data: showRes ? '$dClr ${response.body} $stp' : '',
          )
        : printData(
            title: 'status $rStCode url : $rUrl\n',
            data: showRes ? response.body : '',
          );

    if (!decode) return response;

    // Empty body (e.g. 204) — return a success map instead of crashing on json.decode
    if (response.body.trim().isEmpty) {
      return {'success': !isError, 'message': isError ? 'Empty error response' : 'OK'};
    }

    try {
      return json.decode(response.body);
    } catch (e) {
      printData(
        title: 'JSON Decode Error',
        data: 'Failed to decode response from $rUrl. Body: ${response.body}',
        e: true,
      );
      // Return a standard error map to avoid crashing the provider
      return {
        'success': false,
        'message': 'Invalid server response',
        'status_code': rStCode,
        'body': response.body,
      };
    }
  }
}
