import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart' hide hex;
import 'package:convert/convert.dart';
import 'package:lib5/src/util/base64.dart';

abstract class Multibase {
  Uint8List toBytes();

  static Uint8List decodeString(String data) {
    final Uint8List bytes;
    if (data[0] == 'z') {
      bytes = base58BitcoinDecode(data.substring(1));
    } else if (data[0] == 'f') {
      bytes = Uint8List.fromList(hex.decode(data.substring(1)));
    } else if (data[0] == 'b') {
      var str = data.substring(1).toUpperCase();
      while (str.length % 4 != 0) {
        str = '$str=';
      }
      bytes = base32Rfc.decode(str);
    } else if (data[0] == 'u') {
      var str = data.substring(1);
      while (str.length % 4 != 0) {
        str = '$str=';
      }
      bytes = base64Url.decode(str);
    } else if (data[0] == ':') {
      bytes = Uint8List.fromList(utf8.encode(data));
    } else {
      throw 'Multibase encoding ${data[0]} not supported';
    }

    return bytes;
  }

  String toHex() {
    return 'f${hex.encode(toBytes())}';
  }

  String toBase32() {
    return 'b${base32Rfc.encode(toBytes()).replaceAll('=', '').toLowerCase()}';
  }

  String toBase64Url() {
    return 'u${base64UrlNoPaddingEncode(toBytes())}';
  }

  String toBase58() {
    return 'z${base58Bitcoin.encode(toBytes())}';
  }

  @override
  String toString() {
    return toBase58();
  }
  // TODO Maybe add:
  // - base36,            k,    base36 [0-9a-z] case-insensitive - no padding,                draft
  // - base32hex,         v,    rfc4648 case-insensitive - no padding - highest char,         candidate
}
