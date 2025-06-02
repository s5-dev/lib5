import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/util/endian.dart';

import 'sign.dart';
import 'verify.dart';

class RegistryEntry {
  /// public key with multicodec prefix
  final Uint8List pk;

  /// revision number of this entry, maximum is (256^8)-1
  final int revision;

  /// data stored in this entry, can have a maximum length of 48 bytes
  final Uint8List data;

  /// signature of this registry entry
  final Uint8List signature;

  RegistryEntry({
    required this.pk,
    required this.revision,
    required this.data,
    required this.signature,
  });

  static Future<RegistryEntry> create({
    required KeyPairEd25519 kp,
    required Uint8List data,
    required int revision,
    required CryptoImplementation crypto,
  }) =>
      signRegistryEntry(kp: kp, data: data, revision: revision, crypto: crypto);

  Future<bool> verify({required CryptoImplementation crypto}) =>
      verifyRegistryEntry(this, crypto: crypto);

  Uint8List serialize() {
    return Uint8List.fromList([
      recordTypeRegistryEntry,
      ...pk,
      ...encodeEndian(revision, 8),
      data.length,
      ...data,
      ...signature,
    ]);
  }

  factory RegistryEntry.deserialize(Uint8List event) {
    final dataLength = event[42];
    return RegistryEntry(
      pk: event.sublist(1, 34),
      revision: decodeEndian(event.sublist(34, 42)),
      data: event.sublist(43, 43 + dataLength),
      signature: event.sublist(43 + dataLength),
    );
  }
}
