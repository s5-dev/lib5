import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/util/endian.dart';

Future<SignedRegistryEntry> signRegistryEntry({
  required KeyPairEd25519 kp,
  required Uint8List data,
  required int revision,
  required CryptoImplementation crypto,
}) async {
  final list = Uint8List.fromList([
    ...encodeEndian(revision, 8),
    data.length, // 1 byte
    ...data,
  ]);

  final signature = await crypto.signEd25519(
    kp: kp,
    message: list,
  );

  return SignedRegistryEntry(
    pk: kp.publicKey,
    revision: revision,
    data: data,
    signature: Uint8List.fromList(signature),
  );
}
