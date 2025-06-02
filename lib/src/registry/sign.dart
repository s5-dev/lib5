import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/util/endian.dart';

Future<RegistryEntry> signRegistryEntry({
  required KeyPairEd25519 kp,
  required Uint8List data,
  required int revision,
  required CryptoImplementation crypto,
}) async {
  final list = Uint8List.fromList([
    recordTypeRegistryEntry,
    ...encodeEndian(revision, 8),
    data.length, // 1 byte
    ...data,
  ]);

  final signature = await crypto.signEd25519(
    keyPair: kp,
    message: list,
  );

  return RegistryEntry(
    pk: kp.publicKey,
    revision: revision,
    data: data,
    signature: Uint8List.fromList(signature),
  );
}
