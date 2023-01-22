import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/util/endian.dart';

Uint8List deriveHashBlake3(
  List<int> base,
  List<int> tweak, {
  required CryptoImplementation crypto,
}) {
  if (base.length != 32) {
    throw 'Invalid base length';
  }
  return crypto.hashBlake3Sync(
    Uint8List.fromList(
      base + (crypto.hashBlake3Sync(Uint8List.fromList(tweak))),
    ),
  );
}

Uint8List deriveHashBlake3Int(
  List<int> base,
  int tweak, {
  required CryptoImplementation crypto,
}) {
  if (base.length != 32) {
    throw 'Invalid base length';
  }
  return crypto.hashBlake3Sync(
    Uint8List.fromList(
      base + encodeEndian(tweak, 32),
    ),
  );
}
