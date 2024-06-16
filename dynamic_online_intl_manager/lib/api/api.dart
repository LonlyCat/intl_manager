import 'package:dynamic_online_intl_manager/model/Intl_file_response.dart';
import 'package:dynamic_online_intl_manager/model/Intl_list_response.dart';
import 'package:dynamic_online_intl_manager/model/base_response.dart';
import 'package:dynamic_online_intl_manager/api/url_constants.dart';
import 'package:dio/dio.dart';

mixin Api {
  static Api? _instance;
  static Api get instance {
    _instance ??= CommonApi();
    return _instance!;
  }

  Dio? _dio;
  Dio get dio {
    _dio ??= initDio();
    return _dio!;
  }

  Dio initDio() {
    _dio = Dio();
    _dio!.options.baseUrl = UrlConstants.baseURL;
    _dio!.options.connectTimeout = const Duration(seconds: 10);
    _dio!.options.receiveTimeout = const Duration(seconds: 20);
    _dio!.interceptors.addAll(_interceptors());
    return _dio!;
  }

  List<Interceptor> _interceptors() {
    return [
      InterceptorsWrapper(
        onRequest: (options, handler) {
          return handler.next(options); //continue
        },
        onResponse: (response, handler) {
          return handler.next(response); // continue
        },
        onError: (e, handler) {
          return handler.next(e); //continue
        },
      ),
    ];
  }
}

class CommonApi with Api {}

extension IntlInterface on Api {
  Future<List<String>> getLanguages() async {
    final Response response = await dio.get('/l10ns');
    if (response.statusCode != 200) {
      throw Exception('Failed to get languages');
    }
    final resData = IntlListResponse.fromJson(response.data);
    return resData.data ?? [];
  }

  Future<Map<String, String>> getLanguageFile(String fileName) async {
    final Response response = await dio.get('/l10ns/$fileName');
    if (response.statusCode != 200) {
      throw Exception('Failed to get language file');
    }
    final resData = IntlFileResponse.fromJson(response.data);
    return resData.data ?? {};
  }

  Future<CommonResponse> updateTranslation(String fileName, String key, String value) async {
    final Response response = await dio.post(
      '/l10ns/update',
      options: Options(receiveTimeout: const Duration(seconds: 2)),
      data: {
        'fileName': fileName,
        'key': key,
        'value': value,
      },
    );
    if (response.statusCode != 200) {
      throw Exception('Failed to update translation');
    }
    return CommonResponse.fromJson(response.data);
  }

  Future<CommonResponse> syncGitFile() async {
    final Response response = await dio.post('/l10ns/sync');
    if (response.statusCode != 200) {
      throw Exception('Failed to sync git file');
    }
    return CommonResponse.fromJson(response.data);
  }
}
