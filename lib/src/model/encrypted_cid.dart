import 'dart:math';
import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/util/endian.dart';

import 'cid.dart';
import 'multihash.dart';
import 'multibase.dart';

class EncryptedCID extends Multibase {
  final Multihash encryptedBlobHash;
  final CID originalCID;

  final int encryptionAlgorithm;

  final int padding;

  // TODO Maybe rename
  final int chunkSizeAsPowerOf2;
  int get chunkSize => pow(2, chunkSizeAsPowerOf2) as int;

  final Uint8List encryptionKey;

  EncryptedCID({
    required this.encryptedBlobHash,
    required this.originalCID,
    required this.encryptionKey,
    required this.padding,
    required this.chunkSizeAsPowerOf2,
    required this.encryptionAlgorithm,
  });

  factory EncryptedCID.decode(String cid) =>
      EncryptedCID.fromBytes(Multibase.decodeString(cid));

  factory EncryptedCID.fromBytes(Uint8List bytes) {
    if (bytes[0] != cidTypeEncryptedStatic) {
      throw 'Invalid CID type (${bytes[0]})';
    }

    return EncryptedCID(
      encryptionAlgorithm: bytes[1],
      chunkSizeAsPowerOf2: bytes[2],
      encryptedBlobHash: Multihash(bytes.sublist(3, 36)),
      encryptionKey: bytes.sublist(36, 68),
      padding: decodeEndian(bytes.sublist(68, 72)),
      originalCID: CID.fromBytes(bytes.sublist(72)),
    );
  }

  @override
  Uint8List toBytes() {
    return Uint8List.fromList(
      [cidTypeEncryptedStatic, encryptionAlgorithm] +
          [chunkSizeAsPowerOf2] +
          encryptedBlobHash.fullBytes +
          encryptionKey +
          encodeEndian(padding, 4) +
          originalCID.toBytes(),
    );
  }
}
