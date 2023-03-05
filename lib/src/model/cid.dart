import 'dart:convert';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/bytes.dart';
import 'package:lib5/src/util/endian.dart';
import 'multihash.dart';

class CID {
  late final int type;
  late final Multihash hash;
  int? size;

  CID(this.type, this.hash, {this.size});

  CID.decode(String cid) {
    final Uint8List bytes;
    if (cid[0] == 'z') {
      bytes = base58BitcoinDecode(cid.substring(1));
    } else if (cid[0] == 'b') {
      var str = cid.substring(1).toUpperCase();
      while (str.length % 4 != 0) {
        str = '$str=';
      }
      bytes = base32Rfc.decode(str);
    } else if (cid[0] == 'u') {
      var str = cid.substring(1);
      while (str.length % 4 != 0) {
        str = '$str=';
      }
      bytes = base64Url.decode(str);
    } else if (cid[0] == ':') {
      bytes = Uint8List.fromList(utf8.encode(cid));
    } else {
      throw 'Encoding not supported';
    }

    _init(bytes);
  }

  CID.fromBytes(Uint8List bytes) {
    _init(bytes);
  }

  factory CID.bridge(String id) {
    return CID(
      cidTypeBridge,
      Multihash(
        Uint8List.fromList(
          [cidTypeBridge] + utf8.encode(id),
        ),
      ),
    );
  }

  void _init(Uint8List bytes) {
    type = bytes[0];
    if (type == cidTypeBridge) {
      hash = Multihash(bytes);
    } else {
      hash = Multihash(bytes.sublist(1, 34));

      final sizeBytes = bytes.sublist(34);
      if (sizeBytes.isNotEmpty) {
        size = decodeEndian(sizeBytes);
      }
    }
  }

  CID copyWith({int? type, int? size}) {
    return CID(
      type ?? this.type,
      hash,
      size: size ?? this.size,
    );
  }

  Uint8List toBytes() {
    if (type == cidTypeBridge) {
      return hash.fullBytes;
    } else if (type == cidTypeRaw) {
      var sizeBytes = encodeEndian(size!, 8);

      while (sizeBytes.isNotEmpty && sizeBytes.last == 0) {
        sizeBytes = sizeBytes.sublist(0, sizeBytes.length - 1);
      }
      if (sizeBytes.isEmpty) {
        sizeBytes = Uint8List(1);
      }

      return Uint8List.fromList(
        _getPrefixBytes() + hash.fullBytes + sizeBytes,
      );
    } else {
      return Uint8List.fromList(_getPrefixBytes() + hash.fullBytes);
    }
  }

  List<int> _getPrefixBytes() {
    return [type];
  }

  Uint8List toRegistryEntry() {
    return Uint8List.fromList(
      [registryS5MagicByte] + toBytes(),
    );
  }

  String toBase58() {
    return 'z${base58Bitcoin.encode(toBytes())}';
  }

  String toBase32() {
    return 'b${base32Rfc.encode(toBytes()).replaceAll('=', '').toLowerCase()}';
  }

  String toBase64Url() {
    return 'u${base64UrlNoPaddingEncode(toBytes())}';
  }

  @override
  String toString() {
    return type == cidTypeBridge ? utf8.decode(hash.fullBytes) : toBase58();
  }

  @override
  bool operator ==(Object other) {
    if (other is! CID) {
      return false;
    }
    return areBytesEqual(toBytes(), other.toBytes());
  }

  @override
  int get hashCode {
    final fullBytes = toBytes();
    return fullBytes[0] +
        (fullBytes[1] * 256) +
        (fullBytes[2] * 256 * 256) +
        (fullBytes[3] * 256 * 256 * 256);
  }
}
