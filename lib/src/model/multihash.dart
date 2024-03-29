import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/src/constants.dart';

import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/bytes.dart';

class Multihash {
  final Uint8List fullBytes;

  int get functionType => fullBytes[0];
  Uint8List get hashBytes => fullBytes.sublist(1);

  Multihash(this.fullBytes);

  factory Multihash.blake3(Uint8List hash) {
    return Multihash(Uint8List.fromList([mhashBlake3Default] + hash));
  }

  factory Multihash.fromBase64Url(String hash) {
    while (hash.length % 4 != 0) {
      hash += '=';
    }
    final bytes = base64Url.decode(hash);
    return Multihash(bytes);
  }

  String toBase64Url() {
    return base64UrlNoPaddingEncode(fullBytes);
  }

  String toBase32() {
    return base32Rfc.encode(fullBytes).replaceAll('=', '').toLowerCase();
  }

  @override
  String toString() {
    return functionType == cidTypeBridge
        ? utf8.decode(fullBytes)
        : toBase64Url();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Multihash) {
      return false;
    }
    return areBytesEqual(fullBytes, other.fullBytes);
  }

  @override
  int get hashCode {
    return fullBytes[0] +
        (fullBytes[1] * 256) +
        (fullBytes[2] * 256 * 256) +
        (fullBytes[3] * 256 * 256 * 256);
  }
}
