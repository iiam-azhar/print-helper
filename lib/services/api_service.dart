import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

import '../utils/console_util.dart';
import '../utils/custom_exceptions.dart';
import 'api_routes.dart';

class ApiService {
  ApiService._internal();

  static final ApiService _instance = ApiService._internal();

  factory ApiService() => _instance;

  static const _timeOut = 30;
  static final Random _rng = Random();

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

    try {
      final response = await http
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

    try {
      if (multipart) {
        final method = isPut ? 'PUT' : 'POST';

        final request = http.MultipartRequest(method, uri);
        request.fields.addAll(payload);
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

        final streamedResponse = await request
            .send()
            .timeout(Duration(seconds: timeOut));
        final response = await http.Response.fromStream(streamedResponse);
        return _response(response, showRes);
      } else {
        final method = isDelete
            ? http.delete
            : isPut
            ? http.put
            : http.post;

        final res = method(uri, headers: headers, body: payload);
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
    switch (response.statusCode) {
      case 200:
      case 201:
        return _processResponse(response, false, showRes, decode: decode);
      case 400:
      case 401:
      case 403:
      case 500:
      default:
        return _processResponse(response, true, showRes, decode: decode);
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

    return decode ? json.decode(response.body) : response;
  }
}
