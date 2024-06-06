import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

const String _lanDir = '../dynamic_online_intl/lib/language/l10n';
const String _shDir = '../dynamic_online_intl';

// 获取文件列表
Future<Response> _getLanguages(Request request) async {
  try {
    final directory = Directory(_lanDir);
    final files = await directory.list().toList();
    // 获取文件名列表
    final fileList = files.map((file) => file.uri.pathSegments.last).toList();
    final responseData = _successResponse(fileList);
    // 返回 json 格式的文件名列表
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  } catch (e) {
    // 处理异常
    final responseData = _errorResponse(code: -1, msg: 'Failed to get files: ${e.toString()}');
    return Response.notFound(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

// 获取指定语言文件并通过 JSON 返回
Future<Response> _getLanguageFile(Request request, String fileName) async {
  final file = File('$_lanDir/$fileName');
  try {
    if (await file.exists()) {
      // 读取文件内容
      final content = await file.readAsString();
      final responseData = _successResponse(jsonDecode(content));
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    } else {
      // 处理异常
      final responseData = _errorResponse(code: -1, msg: 'Failed to get file');
      return Response.notFound(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    // 处理异常
    final responseData = _errorResponse(code: -1, msg: 'Failed to get file: ${e.toString()}');
    return Response.notFound(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

// 获取指定语言原始文件
Future<Response> _getRawLanguageFile(Request request, String fileName) async {
  final file = File('$_lanDir/$fileName');
  try {
    if (await file.exists()) {
      return Response.ok(file.openRead(), headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="$fileName"'
      });
    } else {
      // 处理异常
      final responseData = _errorResponse(code: -1, msg: 'Failed to get file');
      return Response.notFound(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    // 处理异常
    final responseData = _errorResponse(code: -1, msg: 'Failed to get file: ${e.toString()}');
    return Response.notFound(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

Future<Response> _updateTranslation(Request request) async {
  if (request.method != 'POST') {
    return Response.forbidden('Method Not Allowed');
  }
  // 读取 POST 请求体
  final content = await request.readAsString();
  final data = jsonDecode(content);
  final fileName = data['fileName'];
  final key = data['key'];
  final value = data['value'];
  final file = File('$_lanDir/$fileName');
  try {
    if (await file.exists()) {
      Map translations = jsonDecode(await file.readAsString());
      Map newTranslations = Map.from(translations);
      newTranslations[key] = value;
      // 更新文件内容
      await file.writeAsString(jsonEncode(newTranslations));
      // 调用 bash 脚本生成对应的 dart 文件
      final result = await Process.run(
        'sh',
        ['-c', 'flutter pub run intl_utils:generate'],
        workingDirectory: _shDir,
      );
      if (result.exitCode == 0) {
        final responseData = _successResponse(null);
        return Response.ok(jsonEncode(responseData),
            headers: {'Content-Type': 'application/json'});
      } else {
        print('Failed to generate ARB files: ${result.stderr}');
        // 失败重置文件内容
        await file.writeAsString(jsonEncode(translations));
        final responseData = _errorResponse(code: -10, msg: 'Failed to regenerate ARB files');
        return Response.ok(jsonEncode(responseData),
            headers: {'Content-Type': 'application/json'});
      }
    } else {
      final responseData = _errorResponse(code: -1, msg: 'Failed to update file');
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    final responseData = _errorResponse(code: -1, msg: 'Failed to update file: ${e.toString()}');
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

void startServer() async {
  // 创建 CORS 处理程序
  final corsH = corsHeaders(headers: {
    // 允许来自 Flutter Web 应用的域名
    'Access-Control-Allow-Origin': '*',
    // 允许的 HTTP 方法
    'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
    // 允许的请求头
    'Access-Control-Allow-Headers': 'Content-Type, Authorization',
  });

  // 定义路由
  final router = Router()
    ..get('/l10ns', _getLanguages)
    ..get('/l10ns/<fileName>', _getLanguageFile)
    ..get('/l10ns/raw/<fileName>', _getRawLanguageFile)
    ..post('/l10ns/update', _updateTranslation);

  // 使用 CORS 处理程序
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsH)
      .addHandler(router);

  // 启动服务器
  final server = await io.serve(handler, 'localhost', 8080);
  print('Serving at http://${server.address.host}:${server.port}');
}

Map _successResponse(
  dynamic data, {
  String msg = 'success',
}) {
  return {
    'code': 0,
    'msg': msg,
    'data': data,
  };
}

Map _errorResponse({
  int code = -1,
  String msg = 'error',
}) {
  return {
    'code': code,
    'msg': msg,
  };
}
