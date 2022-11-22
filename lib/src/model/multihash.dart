import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/util/bytes.dart';

class Multihash {
  final Uint8List fullBytes;

  int get functionType => fullBytes[0];
  Uint8List get hashBytes => fullBytes.sublist(1);

  Multihash(this.fullBytes);

  factory Multihash.fromBase64Url(String hash) {
    while (hash.length % 4 != 0) {
      hash += '=';
    }
    final bytes = base64Url.decode(hash);
    return Multihash(bytes);
  }

  String toBase58() {
    return base58Bitcoin.encode(fullBytes);
  }

  String toBase64Url() {
    return base64Url.encode(fullBytes).replaceAll('=', '');
  }

  String toBase32() {
    return base32Rfc.encode(fullBytes).replaceAll('=', '').toLowerCase();
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
