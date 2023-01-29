import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/util/endian.dart';
import 'package:lib5/src/util/padding.dart';

import 'constants.dart';

Future<Uint8List> encryptMutableBytes(
  Uint8List data,
  Uint8List key, {
  required CryptoImplementation crypto,
}) async {
  final lengthInBytes = encodeEndian(
    data.length,
    4,
  );

  final totalOverhead =
      encryptionOverheadLength + 4 + encryptionNonceLength + 2;

  final finalSize =
      padFileSizeDefault(data.length + totalOverhead) - totalOverhead;

  data = Uint8List.fromList(
    lengthInBytes + data + Uint8List(finalSize - data.length),
  );

  // Generate a random nonce.
  final nonce = crypto.generateRandomBytes(encryptionNonceLength);

  final header = [0x8d, 0x01] + nonce;

  // Encrypt the data.
  final encryptedBytes = await crypto.encryptXChaCha20Poly1305(
    key: key,
    plaintext: data,
    nonce: nonce,
  );

  // Prepend the header to the final data.
  return Uint8List.fromList(header + encryptedBytes);
}

Future<Uint8List> decryptMutableBytes(
  Uint8List data,
  Uint8List key, {
  required CryptoImplementation crypto,
}) async {
  if (key.length != encryptionKeyLength) {
    throw 'wrong encryptionKeyLength (${key.length} != $encryptionKeyLength)';
  }

  // Validate that the size of the data corresponds to a padded block.
  if (!checkPaddedBlock(data.length)) {
    throw "Expected parameter 'data' to be padded encrypted data, length was '${data.length}', nearest padded block is '${padFileSizeDefault(data.length)}'";
  }

  final version = data[1];
  if (version != 0x01) {
    throw 'Invalid version';
  }

  // Extract the nonce.
  final nonce = data.sublist(2, encryptionNonceLength + 2);

  var decryptedBytes = await crypto.decryptXChaCha20Poly1305(
    key: key,
    nonce: nonce,
    ciphertext: data.sublist(
      encryptionNonceLength + 2,
    ),
  );

  final lengthInBytes = decryptedBytes.sublist(0, 4);

  final length = decodeEndian(lengthInBytes);

  return decryptedBytes.sublist(4, length + 4);
}
