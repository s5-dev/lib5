import 'dart:typed_data';

import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/crypto/encryption/mutable.dart';
import 'package:lib5/src/registry/sign.dart';
import 'package:lib5/src/util/derive_hash.dart';

import 'classes.dart';
import 'constants.dart';

Future<BlobIdentifier> setHiddenRawDataImplementation({
  required Uint8List pathKey,
  required Uint8List data,
  required int revision,
  required S5APIProvider api,
}) async {
  final encryptionKey = deriveHashInt(
    pathKey,
    encryptionKeyDerivationTweak,
    crypto: api.crypto,
  );
  // TODO migrate encryption to prefix-free format
  // ignore: deprecated_member_use_from_same_package
  final cipherText = await encryptMutableBytes(
    data,
    encryptionKey,
    crypto: api.crypto,
  );

  final cid = await api.uploadBlobAsBytes(
    cipherText,
  );

  final writeKey = deriveHashInt(
    pathKey,
    writeKeyDerivationTweak,
    crypto: api.crypto,
  );

  final keyPair = await api.crypto.newKeyPairEd25519(seed: writeKey);

  // TODO Maybe encrypt entry
  final sre = await signRegistryEntry(
    kp: keyPair,
    data: cid.hashBytes,
    revision: revision,
    crypto: api.crypto,
  );

  await api.registrySet(sre);
  return cid;
}

Future<HiddenRawDataResponse> getHiddenRawDataImplementation({
  required Uint8List pathKey,
  required S5APIProvider api,
}) async {
  final encryptionKey = deriveHashInt(
    pathKey,
    encryptionKeyDerivationTweak,
    crypto: api.crypto,
  );

  final writeKey = deriveHashInt(
    pathKey,
    writeKeyDerivationTweak,
    crypto: api.crypto,
  );
  final keyPair = await api.crypto.newKeyPairEd25519(seed: writeKey);

  final sre = await api.registryGet(keyPair.publicKey);
  if (sre == null) {
    return HiddenRawDataResponse();
  }

  final cid = BlobIdentifier.fromBytes(sre.data.sublist(1));

  final bytes = await api.downloadBlobAsBytes(cid.hash);
  // TODO migrate encryption to prefix-free format
  // ignore: deprecated_member_use_from_same_package
  final plaintext = await decryptMutableBytes(
    bytes,
    encryptionKey,
    crypto: api.crypto,
  );

  return HiddenRawDataResponse(
    data: plaintext,
    cid: cid,
    revision: sre.revision,
  );
}
