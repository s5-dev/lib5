import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/big_endian.dart';

class StreamMessage {
  /// public key with multicodec prefix, for example 0xed for ed25519
  final Uint8List pk;

  /// seq number of this message, can be 0
  final int seq; // ! u32

  // nonce of this message
  final int nonce; // ! u32

  int get revision => (seq << 32) + nonce;
  final Multihash hash;

  /// the data payload of this message
  final Uint8List? data;

  /// signature of this message
  final Uint8List signature;

  StreamMessage({
    required this.pk,
    required this.seq,
    this.nonce = 0,
    required this.hash,
    required this.signature,
    this.data,
  });

  static Future<StreamMessage> create({
    required KeyPairEd25519 kp,
    required int seq,
    int nonce = 0,
    required Uint8List data,
    required CryptoImplementation crypto,
  }) async {
    final hash = await crypto.hashBlake3(data);
    final mhash = Multihash.blake3(hash);
    final list = Uint8List.fromList([
      recordTypeStreamMessage,
      ...encodeBigEndian(seq, 4),
      ...encodeBigEndian(nonce, 4),
      0x21,
      ...mhash.bytes,
    ]);

    final signature = await crypto.signEd25519(
      keyPair: kp,
      message: list,
    );

    return StreamMessage(
      pk: kp.publicKey,
      seq: seq,
      nonce: nonce,
      hash: mhash,
      signature: Uint8List.fromList(signature),
      data: data,
    );
  }

  Future<bool> verify({required CryptoImplementation crypto}) async {
    if (data != null) {
      final calculatedHash = await crypto.hashBlake3(data!);
      final mhash = Multihash.blake3(calculatedHash);
      if (hash != mhash) return false;
    }

    final list = Uint8List.fromList([
      recordTypeStreamMessage,
      ...encodeBigEndian(seq, 4),
      ...encodeBigEndian(nonce, 4),
      0x21,
      ...hash.bytes,
    ]);

    if (pk[0] != mkeyEd25519) {
      throw 'unsupported algorithm ${pk[0]}';
    }

    return crypto.verifyEd25519(
      publicKey: pk.sublist(1),
      message: list,
      signature: signature,
    );
  }

  Uint8List serialize() {
    final hashBytes = hash.bytes;
    assert(hashBytes.length == 0x21);
    return Uint8List.fromList([
      recordTypeStreamMessage,      //  1 byte
      ...pk,                        // 33 bytes
      ...encodeBigEndian(seq,   4), //  4 bytes
      ...encodeBigEndian(nonce, 4), //  4 bytes
      hashBytes.length,             //  1 byte
      ...hashBytes,                 // usually 33 bytes (blake3 multihash)
      ...signature,                 // 64 bytes
      if (data != null) ...data!,
    ]);
  }

  factory StreamMessage.deserialize(Uint8List event) {
    final hashLength = event[42];
    final mhash = Multihash(event.sublist(43, 43 + hashLength));
    final signatureStart = 43 + hashLength;
    final signatureEnd = signatureStart + 64;

    return StreamMessage(
      pk: event.sublist(1, 34),
      seq: decodeBigEndian(event.sublist(34, 38)),
      nonce: decodeBigEndian(event.sublist(38, 42)),
      hash: mhash,
      signature: event.sublist(signatureStart, signatureEnd),
      data: event.sublist(signatureEnd),
    );
  }
}
