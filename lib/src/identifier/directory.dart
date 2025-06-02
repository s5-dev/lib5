import 'dart:typed_data';

import 'package:lib5/lib5.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/multibase.dart';
import 'package:lib5/src/util/bytes.dart';

typedef MultiKeyOrHash = Multihash;

class DirectoryIdentifier extends Multibase {
  final MultiKeyOrHash key;

  bool get encrypted => encryptionAlgorithm != null;
  // this is usually encryptionAlgorithmXChaCha20Poly1305
  final int? encryptionAlgorithm;
  final Uint8List? encryptionKey;

  DirectoryIdentifier(this.key, {this.encryptionAlgorithm, this.encryptionKey});

  DirectoryIdentifier.encrypted(
      this.encryptionAlgorithm, this.encryptionKey, this.key);

  factory DirectoryIdentifier.encryptedXChaCha20Poly1305(
      Uint8List encryptionKey, MultiKeyOrHash key) {
    return DirectoryIdentifier.encrypted(
      encryptionAlgorithmXChaCha20Poly1305,
      encryptionKey,
      key,
    );
  }

  factory DirectoryIdentifier.decode(String cid) {
    return _init(Multibase.decodeString(cid));
  }

  factory DirectoryIdentifier.fromBytes(Uint8List bytes) {
    return _init(bytes);
  }

  static DirectoryIdentifier _init(Uint8List bytes) {
    if (bytes[0] != cidTypeDirectory) throw FormatException();
    if (bytes[1] == cidTypeEncryptedMutable) {
      return DirectoryIdentifier.encrypted(
        bytes[2],
        bytes.sublist(3, 35),
        Multihash(bytes.sublist(35)),
      );
    } else {
      return DirectoryIdentifier(MultiKeyOrHash(bytes.sublist(1)));
    }
  }

  @override
  Uint8List toBytes() {
    if (encrypted) {
      return Uint8List.fromList(<int>[
            cidTypeDirectory,
            cidTypeEncryptedMutable,
            encryptionAlgorithm!
          ] +
          encryptionKey! +
          key.bytes);
    } else {
      return Uint8List.fromList([cidTypeDirectory] + key.bytes);
    }
  }

  @override
  String toString() {
    return toBase32();
  }

  @override
  bool operator ==(Object other) {
    if (other is! DirectoryIdentifier) {
      return false;
    }
    return areBytesEqual(toBytes(), other.toBytes());
  }

  @override
  int get hashCode {
    final fullBytes = toBytes();
    return fullBytes[0] +
        (fullBytes[1] * 256) +
        (fullBytes[2] * 256 * 256) +
        (fullBytes[3] * 256 * 256 * 256);
  }
}
