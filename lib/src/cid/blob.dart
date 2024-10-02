///
/// This implementation follows the S5 v1 spec at https://docs.sfive.net/spec/blobs.html
///

import 'dart:typed_data';

import 'package:lib5/src/model/multibase.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/bytes.dart';
import 'package:lib5/src/util/endian.dart';

class BlobCID extends Multibase {
  late final Multihash hash;
  late final int size;

  Uint8List get hashBytes => hash.fullBytes;

  BlobCID(this.hash, this.size);

  BlobCID.decode(String cid) {
    _init(Multibase.decodeString(cid));
  }

  BlobCID.fromBytes(Uint8List bytes) {
    _init(bytes);
  }

  void _init(Uint8List bytes) {
    // TODO Do some checks first

    hash = Multihash(bytes.sublist(2, 35));
    final sizeBytes = bytes.sublist(35);
    size = decodeEndian(sizeBytes);
  }

  @override
  Uint8List toBytes() {
    Uint8List sizeBytes = encodeEndian(size, 8);
    while (sizeBytes.isNotEmpty && sizeBytes.last == 0) {
      sizeBytes = sizeBytes.sublist(0, sizeBytes.length - 1);
    }

    if (sizeBytes.isEmpty) {
      sizeBytes = Uint8List(1);
    }

    return Uint8List.fromList(
      [0x5b, 0x82] + hash.fullBytes + sizeBytes,
    );
  }

  @override
  String toString() {
    return toBase32();
  }

  @override
  bool operator ==(Object other) {
    if (other is! BlobCID) {
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
