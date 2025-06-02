import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/util/bytes.dart';
import 'package:lib5/src/util/endian.dart';
import 'multibase.dart';
import 'multihash.dart';

@Deprecated('use blob identifiers instead')
class CID extends Multibase {
  late final int type;
  late final Multihash hash;
  int? size;

  CID(this.type, this.hash, {this.size});

  CID.raw(this.hash, {this.size}) {
    type = cidTypeRaw;
  }

  CID.decode(String cid) {
    _init(Multibase.decodeString(cid));
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

  Uint8List get hashBytes => hash.fullBytes;

  void _init(Uint8List bytes) {
    type = bytes[0];
    if (type == cidTypeBridge) {
      hash = Multihash(bytes);
    } else {
      if (type == cidTypeRaw) {
        hash = Multihash(bytes.sublist(1, 34));

        final sizeBytes = bytes.sublist(34);
        if (sizeBytes.isNotEmpty) {
          size = decodeEndian(sizeBytes);
        }
      } else {
        hash = Multihash(bytes.sublist(1));
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

  @override
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

  // TODO Optional encryption

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
