import 'dart:typed_data';

bool areBytesEqual(Uint8List l1, Uint8List l2) {
  if (l1.length != l2.length) return false;

  for (int i = 0; i < l1.length; i++) {
    if (l1[i] != l2[i]) return false;
  }
  return true;
}
