import 'dart:async';
import 'package:hopper/utils/sharedprefsHelper/sharedprefs_handler.dart';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:hopper/Core/Consents/app_logger.dart';
import 'package:hopper/Core/Services/logger_service.dart';
import 'package:hopper/api/interceptors/api_logger_interceptor.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Request {
  // SECURITY: never log the JWT. Returns only a presence indicator so logs stay
  // useful for debugging (was a token attached?) without ever leaking the token.
  // static String _tokenFromHeaders(Map<String, dynamic> headers) {
  //   final v = headers['Authorization']?.toString() ?? '';
  //   return v.trim().isEmpty ? '(none)' : 'Bearer ***masked***';
  // }
  static String _tokenFromHeaders(Map<String, dynamic> headers) {
    final token = headers['Authorization']?.toString() ?? '';

    if (token.trim().isEmpty) {
      return '(none)';
    }

    // Debug logs are routinely attached to support tickets, so never expose JWTs.
    return 'Bearer ***masked***';
  }

  static void _debugLogInfo(String message) {
    if (!kDebugMode) return;
    AppLogger.log.i(message);
  }

  static String _formatBody(dynamic body) {
    if (body == null) return '{}';
    if (body is FormData) {
      final fields = body.fields
          .map((e) => '${e.key}: ${e.value}')
          .toList(growable: false);
      final files = body.files
          .map((e) {
            final f = e.value;
            return '${e.key}: {filename: ${f.filename}, length: ${f.length}, contentType: ${f.contentType}}';
          })
          .toList(growable: false);
      return 'FormData{fields: $fields, files: $files}';
    }
    return body.toString();
  }

  static Future<dynamic> sendRequest(
    String url,
    Map<String, dynamic> body,
    String? method,
    bool isTokenRequired,
  ) async {
    String? token = await SharedPrefHelper.getToken();

    Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    dio.interceptors.add(ApiLoggerInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final t = _tokenFromHeaders(options.headers);
          _debugLogInfo(
            'Method: ${options.method}\n'
            'Url: ${options.uri}\n'
            'Token: $t\n'
            'Body: ${_formatBody(options.data)}',
          );
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          final t = _tokenFromHeaders(response.requestOptions.headers);
          final reqBody =
              response.requestOptions.data ??
              response.requestOptions.queryParameters;
          _debugLogInfo(
            'Method: ${response.requestOptions.method}\n'
            'Url: ${response.realUri}\n'
            'Token: $t\n'
            'Body: ${_formatBody(reqBody)}\n'
            'Response: ${response.data}',
          );
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final code = error.response?.statusCode;
          if (code == 402) {
            // app update new version
            return handler.reject(error);
          } else if (code == 406 || code == 401) {
            // Unauthorized user navigate to login page

            return handler.reject(error);
          } else if (code == 429) {
            //Too many Attempts
            return handler.reject(error);
          } else if (code == 409) {
            //Too many Attempts
            return handler.reject(error);
          }
          return handler.next(error);
        },
      ),
    );
    try {
      final response = await dio
          .post(
            url,
            data: body,
            options: Options(
              headers: {
                "Authorization": token != null ? "Bearer $token" : "",
                "Content-Type": "application/json",
              },
              validateStatus: (status) {
                // Allow non-standard backend/proxy codes (e.g. 600) to be handled
                // by the caller instead of surfacing as DioException.
                return status != null && status < 700;
              },
            ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("Request timed out after 10 seconds");
            },
          );

      return response;
    } catch (e) {
      // Production-safe: if Dio has a Response object (even for non-2xx / non-standard
      // codes), return it so the caller can show the backend message.
      if (e is DioException && e.response != null) {
        return e.response!;
      }

      return e;
    }
  }

  static Future<dynamic> formData(
    String url,
    dynamic body,
    String? method,
    bool isTokenRequired,
  ) async {
    String? token = await SharedPrefHelper.getToken();

    Dio dio = Dio();
    dio.interceptors.add(ApiLoggerInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final t = _tokenFromHeaders(options.headers);
          _debugLogInfo(
            'Method: ${options.method}\n'
            'Url: ${options.uri}\n'
            'Token: $t\n'
            'Body: ${_formatBody(options.data)}',
          );
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          final t = _tokenFromHeaders(response.requestOptions.headers);
          final reqBody =
              response.requestOptions.data ??
              response.requestOptions.queryParameters;
          _debugLogInfo(
            'Method: ${response.requestOptions.method}\n'
            'Url: ${response.realUri}\n'
            'Token: $t\n'
            'Body: ${_formatBody(reqBody)}\n'
            'Response: ${response.data}',
          );
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          final code = error.response?.statusCode;
          if (code == 402) {
            // app update new version
            return handler.reject(error);
          } else if (code == 406 || code == 401) {
            // Unauthorized user navigate to login page

            return handler.reject(error);
          } else if (code == 429) {
            //Too many Attempts
            return handler.reject(error);
          } else if (code == 409) {
            //Too many Attempts
            return handler.reject(error);
          }
          return handler.next(error);
        },
      ),
    );
    try {
      final response = await dio.post(
        url,
        data: body,
        options: Options(
          headers: {
            "Authorization": token != null ? "Bearer $token" : "",
            "Content-Type":
                body is FormData ? "multipart/form-data" : "application/json",
          },
          validateStatus: (status) {
            // Allow all status codes below 500 to be handled manually
            return status != null && status < 500;
          },
        ),
      );

      return response;
    } catch (e) {
      return e;
    }
  }

  static Future<Response?> sendGetRequest(
    String url,
    Map<String, dynamic> queryParams, // Empty map or any params if required
    String method,
    bool isTokenRequired,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString(
      'token',
    ); // Get the token from SharedPreferences

    Dio dio = Dio();

    dio.interceptors.add(ApiLoggerInterceptor());
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          final t = _tokenFromHeaders(options.headers);
          _debugLogInfo(
            'Method: ${options.method}\n'
            'Url: ${options.uri}\n'
            'Token: $t\n'
            'Body: ${options.queryParameters}',
          );
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          final t = _tokenFromHeaders(response.requestOptions.headers);
          final reqBody =
              response.requestOptions.data ??
              response.requestOptions.queryParameters;
          _debugLogInfo(
            'Method: ${response.requestOptions.method}\n'
            'Url: ${response.realUri}\n'
            'Token: $t\n'
            'Body: ${_formatBody(reqBody)}\n'
            'Response: ${response.data}',
          );
          return handler.next(response);
        },
        onError: (DioException error, ErrorInterceptorHandler handler) async {
          if (error.response?.statusCode == 402) {
            return handler.reject(error);
          } else if (error.response?.statusCode == 406 ||
              error.response?.statusCode == 401) {
            return handler.reject(error);
          } else if (error.response?.statusCode == 429) {
            return handler.reject(error);
          } else if (error.response?.statusCode == 409) {
            return handler.reject(error);
          }
          return handler.next(error);
        },
      ),
    );

    try {
      Response response = await dio.get(
        url,
        queryParameters:
            queryParams, // Pass any necessary query parameters (empty map in this case)
        options: Options(
          headers: {
            "Authorization":
                token != null
                    ? "Bearer $token"
                    : "", // Only the token in the header
          },
          validateStatus: (status) {
            return status != null && status < 500;
          },
        ),
      );

      return response;
    } catch (e) {
      return null;
    }
  }
}
