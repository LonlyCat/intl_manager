import 'dart:io';
import 'dart:convert';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_cors_headers/shelf_cors_headers.dart';

String _rootPath = '';

// 语言包目录
ServeConfig? _currentConfig;
class ServeConfig {
  ServeConfig({
    required this.arbDir,
    required this.projectDir,
    this.branch = 'main',
  });

  String arbDir;
  String projectDir;
  String branch;
}

// 获取文件列表
Future<Response> _getLanguages(Request request) async {
  try {
    final config = await _loadServeConfig();
    final directory = Directory(config.arbDir);
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
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

// 获取指定语言文件并通过 JSON 返回
Future<Response> _getLanguageFile(Request request, String fileName) async {
  try {
    final config = await _loadServeConfig();
    final file = File('${config.arbDir}/$fileName');
    if (await file.exists()) {
      // 读取文件内容
      final content = await file.readAsString();
      final responseData = _successResponse(jsonDecode(content));
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    } else {
      // 处理异常
      final responseData = _errorResponse(code: -1, msg: 'Failed to get file');
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    // 处理异常
    final responseData = _errorResponse(code: -1, msg: 'Failed to get file: ${e.toString()}');
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

// 获取指定语言原始文件
Future<Response> _getRawLanguageFile(Request request, String fileName) async {
  try {
    final config = await _loadServeConfig();
    final file = File('${config.arbDir}/$fileName');
    if (await file.exists()) {
      return Response.ok(file.openRead(), headers: {
        'Content-Type': 'application/octet-stream',
        'Content-Disposition': 'attachment; filename="$fileName"'
      });
    } else {
      // 处理异常
      final responseData = _errorResponse(code: -1, msg: 'Failed to get file');
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    // 处理异常
    final responseData = _errorResponse(code: -1, msg: 'Failed to get file: ${e.toString()}');
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

/// 更新翻译
/// POST 请求，请求体为 JSON 格式
/// 参数： {fileName, key, value}
Future<Response> _updateTranslation(Request request) {
  Future<Response> response = _internalUpdateTranslation(request);
  _translationQueue.add(response);
  _invokeUpdateTranslation();
  return response;
}

Future<Response> _internalUpdateTranslation(Request request) async {
  if (request.method != 'POST') {
    return Response.forbidden('Method Not Allowed');
  }
  // 读取 POST 请求体
  final content = await request.readAsString();
  final data = jsonDecode(content);
  final fileName = data['fileName'];
  final key = data['key'];
  final value = data['value'];
  try {
    final config = await _loadServeConfig();
    final file = File('${config.arbDir}/$fileName');
    if (await file.exists()) {
      Map translations = jsonDecode(await file.readAsString());
      Map newTranslations = Map.from(translations);
      newTranslations[key] = value;
      // 更新文件内容
      await file.writeAsString(jsonEncode(newTranslations));
      // 调用 bash 脚本生成对应的 dart 文件
      final suc = await _runCommands([
        // 生成多语言文件
        Process.run(
          'sh',
          ['-c', 'flutter pub run intl_utils:generate'],
          workingDirectory: config.projectDir,
        ),
      ]);
      if (suc) {
        await _pushChangeToGit();
        final responseData = _successResponse(null);
        return Response.ok(jsonEncode(responseData),
            headers: {'Content-Type': 'application/json'});
      } else {
        print('Failed to generate ARB files');
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

Future<Response>? _currentTranslation;
List<Future<Response>> _translationQueue = [];
Future _invokeUpdateTranslation() async {
  if (_currentTranslation != null) {
    return;
  }
  if (_translationQueue.isEmpty) {
    return;
  }
  _currentTranslation = _translationQueue.removeAt(0);
  await _currentTranslation;
  _currentTranslation = null;
  _invokeUpdateTranslation();
}

/// 同步翻译
Future<Response> _syncTranslations(Request request) async {
  bool suc = await _pushChangeToGit();
  if (suc) {
    final responseData = _successResponse(null);
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  } else {
    final responseData = _errorResponse(code: -10, msg: 'Failed to sync translations');
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}


/// 添加翻译
/// POST 请求，请求体为 JSON 格式
/// 参数： [{fileName, key, value}, ...]
Future<Response> _addTranslations(Request request) async {
  if (request.method != 'POST') {
    return Response.forbidden('Method Not Allowed');
  }
  // 读取 POST 请求体
  final content = await request.readAsString();
  final data = jsonDecode(content);
  try {
    final config = await _loadServeConfig();
    for (var item in data) {
      final fileName = item['fileName'];
      String key = item['key'];
      String value = item['value'];
      final file = File('${config.arbDir}/$fileName');
      if (await file.exists()) {
        Map translations = jsonDecode(await file.readAsString());
        Map newTranslations = Map.from(translations);
        newTranslations[key] = value;
        // 更新文件内容
        await file.writeAsString(jsonEncode(newTranslations));
      } else {
        final responseData = _errorResponse(code: -1, msg: 'Failed to update file');
        return Response.ok(jsonEncode(responseData),
            headers: {'Content-Type': 'application/json'});
      }
    }
    // 调用 bash 脚本生成对应的 dart 文件
    final suc = await _runCommands([
      // 生成多语言文件
      Process.run(
        'sh',
        ['-c', 'flutter pub run intl_utils:generate'],
        workingDirectory: config.projectDir,
      ),
    ]);
    if (suc) {
      _pushChangeToGit();
      final responseData = _successResponse(null);
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    } else {
      print('Failed to generate ARB files');
      final responseData = _errorResponse(code: -10, msg: 'Failed to regenerate ARB files');
      return Response.ok(jsonEncode(responseData),
          headers: {'Content-Type': 'application/json'});
    }
  } catch (e) {
    final responseData = _errorResponse(code: -1, msg: 'Failed to update file: ${e.toString()}');
    return Response.ok(jsonEncode(responseData),
        headers: {'Content-Type': 'application/json'});
  }
}

/// 从 lib/env/serve.env 加载配置
Future<ServeConfig> _loadServeConfig() async {
  if (_currentConfig != null) {
    return _currentConfig!;
  }
  String configPath = '$_rootPath/lib/env/serve.env';
  print('configPath: $configPath');
  final config = File(configPath);
  final lines = await config.readAsLines();
  Map<String, String> env = {};
  for (var line in lines) {
    final parts = line.split('=');
    if (parts.length == 2) {
      env[parts[0]] = parts[1];
    }
  }
  String? arbDir = env['ARB_DIR'];
  String? projectDir = env['PROJECT_DIR'];
  if (arbDir != null && projectDir != null) {
    // 解析当前 [projectDir] 下 git 仓库是什么分支
    final gitBranch = await Process.run(
      'git',
      ['rev-parse', '--abbrev-ref', 'HEAD'],
      workingDirectory: projectDir,
    );
    final config = ServeConfig(
      arbDir: arbDir,
      projectDir: projectDir,
      branch: gitBranch.stdout.toString().trim(),
    );
    _currentConfig = config;
    return config;
  } else {
    throw Exception('Failed to load config');
  }
}

// 向 git 仓库提交并推送修改
Future<bool> _pushChangeToGit() async {
  final config = await _loadServeConfig();
  // 执行 lib/script/git_sync.sh 脚本, 并将 branch、 projectDir 传递给脚本
  // 并将脚本执行结果输出到控制台
  return _runCommands([
    Process.run(
      'sh',
      ['-c', 'lib/script/git_sync.sh ${config.branch} ${config.projectDir}'],
      workingDirectory: _rootPath,
    ),
  ]);
}

Future<bool> _runCommands(List<Future<ProcessResult>> commands) async {
  for (var command in commands) {
    // 等待 2 秒, 避免过快导致 git 仓库文件锁导致的异常
    await Future.delayed(Duration(seconds: 2));
    ProcessResult result = await command;
    if (result.exitCode != 0) {
      print('Failed to run command with code ${result.exitCode}: ${result.stderr}');
      return false;
    }
    print('Command: ${result.stderr.isNotEmpty ? result.stderr : result.stdout}');
  }
  return true;
}

void startServer(String rootPath) async {
  _rootPath = rootPath;
  _loadServeConfig();

  // 定义路由
  final router = Router()
    ..get('/l10ns', _getLanguages)
    ..get('/l10ns/<fileName>', _getLanguageFile)
    ..get('/l10ns/raw/<fileName>', _getRawLanguageFile)
    ..post('/l10ns/update', _updateTranslation)
    ..post('/l10ns/sync', _syncTranslations)
    ..post('/l10ns/add', _addTranslations);

  // 创建 CORS 处理程序
  final corsH = corsHeaders(headers: {
    // 允许来自 Flutter Web 应用的域名
    ACCESS_CONTROL_ALLOW_ORIGIN: '*',
    // 允许的 HTTP 方法
    ACCESS_CONTROL_ALLOW_METHODS: 'GET, POST, PUT, DELETE, OPTIONS',
    // 允许的请求头
    ACCESS_CONTROL_ALLOW_HEADERS: 'Content-Type, Authorization',
  });

  // 使用 CORS 处理程序
  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addMiddleware(corsH)
      .addHandler(router.call);

  // 启动服务器
  try {
    await io.serve(handler, 'localhost', 8080);
  } catch (e) {
    print('run server with err: $e');
  }
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
