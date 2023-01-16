import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/lib5.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/endian.dart';

class EncryptedCID {
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

  factory EncryptedCID.decode(String cid) {
    final Uint8List bytes;
    // TODO Move multibase decoder to util class
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
    } else {
      throw 'Encoding not supported';
    }

    return EncryptedCID.fromBytes(bytes);
  }
  factory EncryptedCID.fromBytes(Uint8List bytes) {
    if (bytes[0] != cidTypeEncrypted) {
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

  Uint8List toBytes() {
    return Uint8List.fromList(
      [cidTypeEncrypted, encryptionAlgorithm] +
          [chunkSizeAsPowerOf2] +
          encryptedBlobHash.fullBytes +
          encryptionKey +
          encodeEndian(padding, 4) +
          originalCID.toBytes(),
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
    return toBase58();
  }
}
