import 'dart:typed_data';

import 'package:lib5/src/constants.dart';

abstract class CryptoImplementation {
  Uint8List generateRandomBytes(int length);

  Future<Uint8List> hashBlake3(Uint8List input);
  Uint8List hashBlake3Sync(Uint8List input);

  Future<bool> verifyEd25519({
    required Uint8List pk,
    required Uint8List message,
    required Uint8List signature,
  });

  Future<Uint8List> signEd25519({
    required KeyPairEd25519 kp,
    required Uint8List message,
  });

  Future<KeyPairEd25519> newKeyPairEd25519({
    required Uint8List seed,
  });

  Future<Uint8List> encryptXChaCha20Poly1305({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List plaintext,
  });

  Future<Uint8List> decryptXChaCha20Poly1305({
    required Uint8List key,
    required Uint8List nonce,
    required Uint8List ciphertext,
  });
}

class KeyPairEd25519 {
  // _bytes consists of 64 bytes (seed bytes + public key bytes)
  final Uint8List _bytes;
  KeyPairEd25519(this._bytes);

  Uint8List get publicKey {
    return Uint8List.fromList([mkeyEd25519] + _bytes.sublist(32));
  }

  Uint8List extractBytes() => _bytes;
}
