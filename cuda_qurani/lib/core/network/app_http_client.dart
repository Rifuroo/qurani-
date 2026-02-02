import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../config/app_config.dart';

class AppHttpClient {
  static final AppHttpClient _instance = AppHttpClient._internal();
  factory AppHttpClient() => _instance;

  late final Dio dio;
  final _storage = const FlutterSecureStorage();

  AppHttpClient._internal() {
    dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print('🌐 HTTP: [${options.method}] ${options.path}');
        
        final token = await _storage.read(key: 'access_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
          print('🔑 HTTP: Token attached');
        }
        
        if (options.data != null) {
          print('📦 HTTP: Request Data: ${options.data}');
        }
        
        return handler.next(options);
      },
      onResponse: (response, handler) {
        print('✅ HTTP: [${response.statusCode}] ${response.requestOptions.path}');
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print('❌ HTTP: [${e.response?.statusCode}] ${e.requestOptions.path}');
        print('💬 HTTP: Error: ${e.message}');
        if (e.response?.data != null) {
          print('📦 HTTP: Error Data: ${e.response?.data}');
        }

        if (e.response?.statusCode == 401) {
          print('🔄 HTTP: Token expired, attempting refresh...');
          final success = await _refreshToken();
          if (success) {
            print('✅ HTTP: Token refreshed, retrying original request');
            // Update the header and retry
            final token = await _storage.read(key: 'access_token');
            e.requestOptions.headers['Authorization'] = 'Bearer $token';
            
            final opts = Options(
              method: e.requestOptions.method,
              headers: e.requestOptions.headers,
            );
            
            try {
              final response = await dio.request(
                e.requestOptions.path,
                options: opts,
                data: e.requestOptions.data,
                queryParameters: e.requestOptions.queryParameters,
              );
              return handler.resolve(response);
            } catch (retryError) {
              return handler.next(e);
            }
          } else {
            print('❌ HTTP: Refresh token failed or missing');
          }
        }
        
        return handler.next(e);
      },
    ));
  }

  Future<bool> _refreshToken() async {
    try {
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken == null) return false;

      // Use a separate Dio instance to avoid interceptor infinite loop
      final refreshDio = Dio(BaseOptions(baseUrl: AppConfig.baseUrl));
      final response = await refreshDio.post('/api/v1/Auth/refresh-token', data: {
        'refreshToken': refreshToken,
      });

      if (response.statusCode == 200 && response.data['success'] == true) {
        final data = response.data['data'];
        await _storage.write(key: 'access_token', value: data['accessToken']);
        await _storage.write(key: 'refresh_token', value: data['refreshToken']);
        return true;
      }
    } catch (e) {
      print('❌ HTTP: Refresh token exception: $e');
    }
    return false;
  }
}
