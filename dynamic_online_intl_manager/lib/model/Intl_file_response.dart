
import 'package:dynamic_online_intl_manager/model/base_response.dart';

/// code : 0
/// msg : "success"
/// data : {"test":"测试 测试"}

class IntlFileResponse extends BaseResponse {
  IntlFileResponse({
    num? code,
    String? msg,
    Map<String, String>? data,
  }) {
    _code = code;
    _msg = msg;
    _data = data;
  }

  IntlFileResponse.fromJson(dynamic json) {
    _code = json['code'];
    _msg = json['msg'];
    _data = json['data'] != null ? Map<String, String>.from(json['data']) : null;
  }

  num? _code;
  String? _msg;
  Map<String, String>? _data;

  @override
  num get code => _code ?? defaultErrorCode;

  @override
  String get msg => _msg ?? defaultErrorMsg;

  Map<String, String>? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['code'] = _code;
    map['msg'] = _msg;
    if (_data != null) {
      map['data'] = _data!;
    }
    return map;
  }
}
