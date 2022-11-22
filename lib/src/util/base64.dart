import 'dart:convert';
import 'dart:typed_data';

// TODO Make this implementation more efficient

String base64UrlNoPaddingEncode(Uint8List bytes) {
  return base64Url.encode(bytes).replaceAll('=', '');
}

Uint8List base64UrlNoPaddingDecode(String str) {
  while (str.length % 4 != 0) {
    str += '=';
  }
  return base64Url.decode(str);
}
