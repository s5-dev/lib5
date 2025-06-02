import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/src/constants.dart';

import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/bytes.dart';

class Multihash {
  final Uint8List bytes;
  @Deprecated('use `bytes` instead')
  Uint8List get fullBytes => bytes;

  int get type => bytes[0];
  Uint8List get value => bytes.sublist(1);

  Multihash(this.bytes);

  factory Multihash.blake3(Uint8List hash) {
    return Multihash(Uint8List.fromList([mhashBlake3] + hash));
  }

  factory Multihash.fromBase64Url(String hash) {
    while (hash.length % 4 != 0) {
      hash += '=';
    }
    final bytes = base64Url.decode(hash);
    return Multihash(bytes);
  }

  String toBase64Url() {
    return base64UrlNoPaddingEncode(bytes);
  }

  String toBase32() {
    return base32Rfc.encode(bytes).replaceAll('=', '').toLowerCase();
  }

  @override
  String toString() {
    return toBase64Url();
  }

  @override
  bool operator ==(Object other) {
    if (other is! Multihash) {
      return false;
    }
    return areBytesEqual(bytes, other.bytes);
  }

  @override
  int get hashCode {
    return bytes[0] +
        (bytes[1] * 256) +
        (bytes[2] * 256 * 256) +
        (bytes[3] * 256 * 256 * 256);
  }
}
