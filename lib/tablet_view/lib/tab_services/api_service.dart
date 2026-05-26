// import 'dart:async';
// import 'dart:convert';
// import 'dart:io';
// import 'dart:math';

// import 'package:http/http.dart' as http;

// import '../tab_utils/console_util.dart';
// import '../tab_utils/custom_exceptions.dart';
// import 'api_routes.dart';

// class ApiService {
//   ApiService._internal();

//   static final ApiService _instance = ApiService._internal();

//   factory ApiService() => _instance;

//   static const _timeOut = 30;
//   static final Random _rng = Random();

//   /// GET Request (Handles API and Direct URLs)
//   Future<dynamic> getDataFromApi({
//     required String api,
//     String? url,
//     dynamic headers,
//     bool decode = true,
//     bool showRes = true,
//     int timeOut = _timeOut,
//   }) async {
//     final Uri uri = _buildUri(path: api, url: url);

//     try {
//       final response = await http
//           .get(uri, headers: headers)
//           .timeout(Duration(seconds: timeOut));

//       return _response(response, showRes, decode: decode);
//     } on SocketException {
//       throw FetchDataException('No Internet Connection', '$uri');
//     } on TimeoutException {
//       throw ApiNotRespondingException('API Not Responding', '$uri');
//     }
//   }

//   /// POST / PUT / DELETE Request (Handles API and File Uploads)
//   Future<dynamic> postDataToApi({
//     required String api,
//     dynamic headers,
//     dynamic payload,
//     List<String> filePaths = const [],
//     List<String> fileNames = const [],
//     List<String> fileKeys = const [],
//     bool multipart = false,
//     bool isPut = false,
//     bool isDelete = false,
//     bool showRes = true,
//   }) async {
//     final Uri uri = _buildUri(path: api);

//     try {
//       if (multipart) {
//         final method = isPut ? 'PUT' : 'POST';

//         final request = http.MultipartRequest(method, uri);
//         request.fields.addAll(payload);
//         if (headers != null) request.headers.addAll(headers);

//         for (int i = 0; i < filePaths.length; i++) {
//           if (filePaths[i].isNotEmpty && fileNames[i].isNotEmpty) {
//             final image = await http.MultipartFile.fromPath(
//               fileKeys[i],
//               filePaths[i],
//               filename: fileNames[i],
//             );
//             request.files.add(image);
//           }
//         }

//         final response = await http.Response.fromStream(await request.send());
//         return _response(response, showRes);
//       } else {
//         final method = isDelete
//             ? http.delete
//             : isPut
//                 ? http.put
//                 : http.post;

//         final res = method(uri, headers: headers, body: payload);
//         final response = await res.timeout(const Duration(seconds: _timeOut));

//         return _response(response, showRes);
//       }
//     } on SocketException {
//       throw FetchDataException('No Internet Connection', '$uri');
//     } on TimeoutException {
//       throw ApiNotRespondingException('API Not Responding', '$uri');
//     }
//   }

//   /// Builds a URI with automatic query parameters.
//   Uri _buildUri({String path = '', String? url}) {
//     final Uri uri;

//     if (url != null) {
//       uri = Uri.parse(url);
//     } else {
//       uri = Uri.parse('${ApiRoutes.baseUrl}$path');
//     }

//     return uri.replace(
//       queryParameters: {
//         ...uri.queryParameters,
//         'v': '${_rng.nextInt(100)}',
//         // 'lang': 'en',
//       },
//     );
//   }

//   dynamic _response(
//     http.Response response,
//     bool showRes, {
//     bool decode = true,
//   }) {
//     switch (response.statusCode) {
//       case 200:
//       case 201:
//         return _processResponse(response, false, showRes, decode: decode);
//       case 400:
//       case 401:
//       case 403:
//       case 500:
//       default:
//         return _processResponse(response, true, showRes, decode: decode);
//     }
//   }

//   dynamic _processResponse(
//     http.Response response,
//     bool isError,
//     bool showRes, {
//     bool decode = true,
//   }) {
//     final sts = isError ? '\x1B[31m' : '\x1B[32m';
//     const uClr = '\x1B[33m';
//     const dClr = '\x1B[35m';
//     const stp = '\x1B[0m';

//     final rStCode = response.statusCode;
//     final rUrl = response.request?.url;

//     Platform.isAndroid
//         ? printData(
//             title: '${sts}status $rStCode$stp$uClr url : $rUrl$stp\n',
//             data: showRes ? '$dClr ${response.body} $stp' : '',
//           )
//         : printData(
//             title: 'status $rStCode url : $rUrl\n',
//             data: showRes ? response.body : '',
//           );

//     return decode ? json.decode(response.body) : response;
//   }
// }

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:print_helper/auth/login_screen.dart';
import 'package:print_helper/services/call_device_service.dart';
import 'package:print_helper/services/db_service.dart';
import 'package:print_helper/services/navigation_service.dart';
import '../tab_widgets/tab_toasts.dart';

import '../tab_utils/console_util.dart';
import '../tab_utils/custom_exceptions.dart';
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

  /// GET Request
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

  /// POST / PUT / DELETE Request
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
  }) async {
    final Uri uri = _buildUri(path: api);
    final client = _getBypassedClient();

    try {
      if (multipart) {
        final method = isPut ? 'PUT' : 'POST';

        final request = http.MultipartRequest(method, uri);
        request.fields.addAll(payload);
        if (headers != null) request.headers.addAll(headers);

        for (int i = 0; i < filePaths.length; i++) {
          if (filePaths[i].isNotEmpty && fileNames[i].isNotEmpty) {
            final file = await http.MultipartFile.fromPath(
              fileKeys[i],
              filePaths[i],
              filename: fileNames[i],
            );
            request.files.add(file);
          }
        }

        final streamedRes = await client.send(request);
        final response = await http.Response.fromStream(streamedRes);

        return _response(response, showRes);
      } else {
        Future<http.Response> res;

        if (isDelete) {
          res = client.delete(uri, headers: headers, body: payload);
        } else if (isPut) {
          res = client.put(uri, headers: headers, body: payload);
        } else {
          res = client.post(uri, headers: headers, body: payload);
        }

        final response = await res.timeout(const Duration(seconds: _timeOut));

        return _response(response, showRes);
      }
    } on SocketException {
      throw FetchDataException('No Internet Connection', '$uri');
    } on TimeoutException {
      throw ApiNotRespondingException('API Not Responding', '$uri');
    }
  }

  /// Build URI
  Uri _buildUri({String path = '', String? url}) {
    final Uri uri = url != null
        ? Uri.parse(url)
        : Uri.parse('${ApiRoutes.baseUrl}$path');

    return uri.replace(
      queryParameters: {...uri.queryParameters, 'v': '${_rng.nextInt(100)}'},
    );
  }

  /// Response Handler
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
      default:
        result = _processResponse(response, true, showRes, decode: decode);
        break;
    }

    if (_shouldForceReauthentication(response.statusCode, result)) {
      final sessionMessage =
          result is Map &&
              (result['message']?.toString().trim().isNotEmpty ?? false)
          ? result['message'].toString()
          : 'Session expired. Please sign in again.';
      unawaited(_clearSessionAndNavigateToLogin(message: sessionMessage));
    }

    return result;
  }

  bool _shouldForceReauthentication(int statusCode, dynamic payload) {
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

    // Logging
    Platform.isAndroid
        ? printData(
            title: '${sts}status $rStCode$stp$uClr url : $rUrl$stp\n',
            data: showRes ? '$dClr ${response.body} $stp' : '',
          )
        : printData(
            title: 'status $rStCode url : $rUrl\n',
            data: showRes ? response.body : '',
          );

    return decode ? json.decode(response.body) : response;
  }
}
