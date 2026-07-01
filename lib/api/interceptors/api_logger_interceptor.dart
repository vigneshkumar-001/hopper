import 'package:dio/dio.dart';
import '../../Core/Services/logger_service.dart';

class ApiLoggerInterceptor extends Interceptor {
  final LoggerService _loggerService = LoggerService();
  final Map<String, int> _requestStartTimes = {};

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    _requestStartTimes[options.hashCode.toString()] = DateTime.now().millisecondsSinceEpoch;

    _loggerService.logApiRequest(
      url: options.uri.toString(),
      method: options.method,
      headers: options.headers.cast<String, dynamic>(),
      body: options.data,
    );

    handler.next(options);
  }

  @override
  void onResponse(
    Response response,
    ResponseInterceptorHandler handler,
  ) {
    final startTime = _requestStartTimes[response.requestOptions.hashCode.toString()] ?? DateTime.now().millisecondsSinceEpoch;
    final duration = DateTime.now().millisecondsSinceEpoch - startTime;

    _loggerService.logApiResponse(
      url: response.requestOptions.uri.toString(),
      statusCode: response.statusCode ?? 0,
      body: response.data,
      durationMs: duration,
    );

    _requestStartTimes.remove(response.requestOptions.hashCode.toString());

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    _loggerService.logApiError(
      url: err.requestOptions.uri.toString(),
      error: err.message ?? 'Unknown error',
      errorBody: err.response?.data,
    );

    _requestStartTimes.remove(err.requestOptions.hashCode.toString());

    handler.next(err);
  }
}
