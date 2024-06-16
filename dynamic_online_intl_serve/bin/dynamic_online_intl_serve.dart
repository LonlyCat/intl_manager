
import 'package:dynamic_online_intl_serve/dynamic_online_intl_serve.dart' as dynamic_online_intl_serve;
import 'dart:io';

// will run by script like: dart run dynamic_online_intl_serve/bin/dynamic_online_intl_serve.dart --root=$PWD
void main(List<String> arguments) {
  // get root path
  String root = '';
  for (var i = 0; i < arguments.length; i++) {
    if (arguments[i].startsWith('--root=')) {
      root = arguments[i].split('=')[1];
      break;
    }
  }
  if (root.isEmpty) {
    root = Directory.current.path;
  }
  dynamic_online_intl_serve.startServer(root);
}
