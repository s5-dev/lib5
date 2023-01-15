import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';

const challengeSize = 32;

const challengeTypeRegister = 1;
const challengeTypeLogin = 2;

Future<ChallengeResponseS5> signChallenge({
  required KeyPairEd25519 keyPair,
  required Uint8List challenge,
  required int challengeType,
  required String serviceAuthority,
  required CryptoImplementation crypto,
}) async {
  if (challenge.length != challengeSize) {
    throw 'Invalid challenge: wrong length';
  }

  final serviceBytes = await crypto.hashBlake3(
    Uint8List.fromList(utf8.encode(serviceAuthority)),
  );

  final message = Uint8List.fromList(
    [challengeType, ...challenge, ...serviceBytes],
  );

  final signatureBytes = await crypto.signEd25519(
    kp: keyPair,
    message: message,
  );

  return ChallengeResponseS5(
    response: message,
    signature: signatureBytes,
  );
}

class ChallengeResponseS5 {
  final Uint8List response;
  final Uint8List signature;
  ChallengeResponseS5({required this.response, required this.signature});
}
