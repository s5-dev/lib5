///
/// This implementation follows the S5 v1 spec at https://docs.sfive.net/spec/blobs.html
///

import 'dart:typed_data';

import 'package:lib5/constants.dart';
// ignore: deprecated_member_use_from_same_package
import 'package:lib5/src/model/cid.dart' show CID;
import 'package:lib5/src/model/multibase.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/bytes.dart';
import 'package:lib5/src/util/endian.dart';

class BlobIdentifier extends Multibase {
  late final Multihash hash;
  late final int size;

  Uint8List get hashBytes => hash.bytes;

  BlobIdentifier(this.hash, this.size);

  BlobIdentifier.decode(String cid) {
    _init(Multibase.decodeString(cid));
  }

  BlobIdentifier.fromBytes(Uint8List bytes) {
    _init(bytes);
  }

  void _init(Uint8List bytes) {
    // TODO Do some checks first

    // ignore: deprecated_member_use_from_same_package
    if (bytes[0] == cidTypeRaw) {
      // ignore: deprecated_member_use_from_same_package
      final cid = CID.fromBytes(bytes);
      hash = cid.hash;
      size = cid.size!;
      return;
    }

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
      [0x5b, 0x82] + hash.bytes + sizeBytes,
    );
  }

  @override
  String toString() {
    return toBase32();
  }

  @override
  bool operator ==(Object other) {
    if (other is! BlobIdentifier) {
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

  factory BlobIdentifier.blake3(Uint8List hashBytes, int size) {
    return BlobIdentifier(Multihash.blake3(hashBytes), size);
  }

  // TODO remove this helper method for comparing with legacy cids in the future
  bool matchesCidStr(String cidStr) {
    final cid = BlobIdentifier.decode(cidStr);
    return cid == this;
  }
}
