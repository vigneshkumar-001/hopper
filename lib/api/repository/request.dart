import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../Core/Constants/log.dart';
import 'package:shared_preferences/shared_preferences.dart';

class Request {
  static Future<dynamic> sendRequest(
    String url,
    Map<String, dynamic> body,
    String? method,
    bool isTokenRequired,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    Dio dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (kDebugMode) {
            final safeHeaders = Map<String, dynamic>.from(options.headers);
            if (safeHeaders.containsKey('Authorization')) {
              safeHeaders['Authorization'] = '<redacted>';
            }
            CommonLogger.log.d(
              "HTTP REQUEST ${options.method} ${options.uri}\n"
              "Headers: $safeHeaders\n"
              "Body: ${options.data}",
            );
          }
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          if (kDebugMode) {
            CommonLogger.log.d(
              "HTTP RESPONSE ${response.statusCode} ${response.realUri}\n"
              "Data: ${response.data}",
            );
          } else {
            CommonLogger.log.d("HTTP ${response.statusCode} $url");
          }
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
          CommonLogger.log.w(
            "HTTP ${error.response?.statusCode} $url (dio error: ${error.type})",
          );
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
              headers: {"Authorization": token != null ? "Bearer $token" : ""},
              validateStatus: (status) {
                // Allow all status codes below 500 to be handled manually
                return status != null && status < 503;
              },
            ),
          )
          .timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException("Request timed out after 10 seconds");
            },
          );

      CommonLogger.log.d("HTTP ${response.statusCode} $url");
      return response;
    } catch (e) {
      CommonLogger.log.e('API: $url \n ERROR: $e ');

      return e;
    }
  }

  static Future<dynamic> formData(
    String url,
    dynamic body,
    String? method,
    bool isTokenRequired,
  ) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String? token = prefs.getString('token');

    Dio dio = Dio();
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (kDebugMode) {
            final safeHeaders = Map<String, dynamic>.from(options.headers);
            if (safeHeaders.containsKey('Authorization')) {
              safeHeaders['Authorization'] = '<redacted>';
            }
            CommonLogger.log.d(
              "HTTP REQUEST ${options.method} ${options.uri}\n"
              "Headers: $safeHeaders\n"
              "Body: ${options.data}",
            );
          }
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          if (kDebugMode) {
            CommonLogger.log.d(
              "HTTP RESPONSE ${response.statusCode} ${response.realUri}\n"
              "Data: ${response.data}",
            );
          } else {
            CommonLogger.log.d("HTTP ${response.statusCode} $url");
          }
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
          CommonLogger.log.w(
            "HTTP ${error.response?.statusCode} $url (dio error: ${error.type})",
          );
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

      CommonLogger.log.d("HTTP ${response.statusCode} $url");

      return response;
    } catch (e) {
      CommonLogger.log.e('API: $url \n ERROR: $e ');

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

    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (RequestOptions options, RequestInterceptorHandler handler) {
          if (kDebugMode) {
            final safeHeaders = Map<String, dynamic>.from(options.headers);
            if (safeHeaders.containsKey('Authorization')) {
              safeHeaders['Authorization'] = '<redacted>';
            }
            CommonLogger.log.d(
              "HTTP REQUEST ${options.method} ${options.uri}\n"
              "Headers: $safeHeaders\n"
              "Query: ${options.queryParameters}",
            );
          }
          return handler.next(options);
        },
        onResponse: (
          Response<dynamic> response,
          ResponseInterceptorHandler handler,
        ) {
          if (kDebugMode) {
            CommonLogger.log.d(
              "HTTP RESPONSE ${response.statusCode} ${response.realUri}\n"
              "Data: ${response.data}",
            );
          } else {
            CommonLogger.log.d("HTTP ${response.statusCode} $url");
          }
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

      CommonLogger.log.d("HTTP ${response.statusCode} $url");
      return response;
    } catch (e) {
      CommonLogger.log.e('GET API: $url \n ERROR: $e');
      return null;
    }
  }
}
