import 'package:dynamic_online_intl_manager/model/base_response.dart';

/// code : 0
/// msg : "suc"
/// data : ["intl_zh.arb","intl_en.arb"]

class IntlListResponse extends BaseResponse {
  IntlListResponse({
    num? code,
    String? msg,
    List<String>? data,
  }) {
    _code = code;
    _msg = msg;
    _data = data;
  }

  IntlListResponse.fromJson(dynamic json) {
    _code = json['code'];
    _msg = json['msg'];
    _data = json['data'] != null ? json['data'].cast<String>() : [];
  }

  num? _code;
  String? _msg;
  List<String>? _data;

  @override
  num get code => _code ?? defaultErrorCode;

  @override
  String get msg => _msg ?? defaultErrorMsg;

  List<String>? get data => _data;

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    map['code'] = _code;
    map['msg'] = _msg;
    map['data'] = _data;
    return map;
  }
}
