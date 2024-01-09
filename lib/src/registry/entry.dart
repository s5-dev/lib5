import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';

import 'sign.dart';
import 'verify.dart';

class SignedRegistryEntry {
  /// public key with multicodec prefix
  final Uint8List pk;

  /// revision number of this entry, maximum is (256^8)-1
  final int revision;

  /// data stored in this entry, can have a maximum length of 48 bytes
  final Uint8List data;

  /// signature of this registry entry
  final Uint8List signature;

  SignedRegistryEntry({
    required this.pk,
    required this.revision,
    required this.data,
    required this.signature,
  });

  static Future<SignedRegistryEntry> create({
    required KeyPairEd25519 kp,
    required Uint8List data,
    required int revision,
    required CryptoImplementation crypto,
  }) =>
      signRegistryEntry(kp: kp, data: data, revision: revision, crypto: crypto);

  Future<bool> verify({required CryptoImplementation crypto}) =>
      verifyRegistryEntry(this, crypto: crypto);
}
