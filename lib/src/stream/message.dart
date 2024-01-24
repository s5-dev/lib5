import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/big_endian.dart';

class SignedStreamMessage {
  /// public key with multicodec prefix, for example 0xed for ed25519
  final Uint8List pk;

  /// unix timestamp of this message (can be millis or micros)
  final int ts; // ! u64
  /// seq number of this message, can be 0
  final int seq; // ! u32

  /// the CID of the data payload
  final CID cid;

  /// the data payload of this message
  final Uint8List data;

  /// signature of this message
  final Uint8List signature;

  SignedStreamMessage({
    required this.pk,
    required this.ts,
    required this.cid,
    required this.data,
    required this.signature,
    this.seq = 0,
  });

  static Future<SignedStreamMessage> create({
    required KeyPairEd25519 kp,
    required Uint8List data,
    required int ts,
    int seq = 0,
    required CryptoImplementation crypto,
  }) async {
    final hash = await crypto.hashBlake3(data);
    final cid = CID(cidTypeRaw, Multihash.blake3(hash), size: data.length);
    final list = Uint8List.fromList([
      recordTypeStreamMessage,
      ...encodeBigEndian(ts, 8),
      ...encodeBigEndian(seq, 4),
      cid.toBytes().length,
      ...cid.toBytes(),
    ]);

    final signature = await crypto.signEd25519(
      kp: kp,
      message: list,
    );

    return SignedStreamMessage(
      pk: kp.publicKey,
      ts: ts,
      seq: seq,
      cid: cid,
      data: data,
      signature: Uint8List.fromList(signature),
    );
  }

  Future<bool> verify({required CryptoImplementation crypto}) async {
    final hash = await crypto.hashBlake3(data);
    final calculatedCID =
        CID(cidTypeRaw, Multihash.blake3(hash), size: data.length);
    if (cid != calculatedCID) return false;

    final list = Uint8List.fromList([
      recordTypeStreamMessage,
      ...encodeBigEndian(ts, 8),
      ...encodeBigEndian(seq, 4),
      cid.toBytes().length,
      ...cid.toBytes(),
    ]);

    return crypto.verifyEd25519(
      pk: pk.sublist(1),
      message: list,
      signature: signature,
    );
  }

  Uint8List serialize() {
    return Uint8List.fromList([
      recordTypeStreamMessage,
      ...pk,
      ...encodeBigEndian(ts, 8),
      ...encodeBigEndian(seq, 4),
      cid.toBytes().length,
      ...cid.toBytes(),
      ...signature,
      ...data,
    ]);
  }

  factory SignedStreamMessage.deserialize(Uint8List event) {
    final cidLength = event[46];
    final cid = CID.fromBytes(event.sublist(47, 47 + cidLength));
    final signatureEnd = 47 + cidLength + 64;

    return SignedStreamMessage(
      pk: event.sublist(1, 34),
      ts: decodeBigEndian(event.sublist(34, 42)),
      seq: decodeBigEndian(event.sublist(42, 46)),
      cid: cid,
      signature: event.sublist(47 + cidLength, signatureEnd),
      data: event.sublist(signatureEnd),
    );
  }
}
