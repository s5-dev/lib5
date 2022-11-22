import 'dart:math';
import 'dart:typed_data';

Uint8List encodeEndian(int value, int length) {
  final res = Uint8List(length);

  for (int i = 0; i < length; i++) {
    res[i] = value & 0xff;
    value = value >> 8;
  }
  return res;
}

int decodeEndian(Uint8List bytes) {
  int total = 0;

  for (int i = 0; i < bytes.length; i++) {
    total += bytes[i] * pow(256, i) as int;
  }

  return total;
}
