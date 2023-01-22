import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/util/endian.dart';

Future<Uint8List> encryptChunk({
  required Uint8List key,
  required Uint8List plaintext,
  required int index,
  required CryptoImplementation crypto,
}) {
  return crypto.encryptXChaCha20Poly1305(
    key: key,
    nonce: encodeEndian(index, 24),
    plaintext: plaintext,
  );
}

Future<Uint8List> decryptChunk({
  required Uint8List key,
  required Uint8List ciphertext,
  required int index,
  required CryptoImplementation crypto,
}) {
  return crypto.decryptXChaCha20Poly1305(
    key: key,
    nonce: encodeEndian(index, 24),
    ciphertext: ciphertext,
  );
}
