
const num successCode = 0;
const num defaultErrorCode = -99;
const String defaultErrorMsg = 'Unknown error';

abstract class BaseResponse {
  num get code;
  String get msg;
}

class CommonResponse extends BaseResponse {
  CommonResponse({
    num? code,
    String? msg,
  }) {
    _code = code;
    _msg = msg;
  }

  CommonResponse.fromJson(dynamic json) {
    _code = json['code'];
    _msg = json['msg'];
  }

  num? _code;
  String? _msg;

  @override
  num get code => _code ?? defaultErrorCode;

  @override
  String get msg => _msg ?? defaultErrorMsg;
}