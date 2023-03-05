import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/util/endian.dart';

Future<bool> verifyRegistryEntry(
  SignedRegistryEntry sre, {
  required CryptoImplementation crypto,
}) {
  final list = Uint8List.fromList([
    recordTypeRegistryEntry,
    ...encodeEndian(sre.revision, 8),
    sre.data.length, // 1 byte
    ...sre.data,
  ]);
  return crypto.verifyEd25519(
    pk: sre.pk.sublist(1),
    message: list,
    signature: sre.signature,
  );
}
