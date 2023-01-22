import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata/base.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/registry/entry.dart';

abstract class S5APIProvider {
  Future<SignedRegistryEntry?> registryGet(Uint8List pk);
  Future<void> registrySet(SignedRegistryEntry sre);
  Stream<SignedRegistryEntry> registryListen(Uint8List pk);

  Future<CID> uploadRawFile(Uint8List data);
  Future<Uint8List> downloadRawFile(Multihash hash);

  Future<Metadata> getMetadataByCID(CID cid);

  CryptoImplementation get crypto;
}
