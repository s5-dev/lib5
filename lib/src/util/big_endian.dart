import 'dart:math';
import 'dart:typed_data';

Uint8List encodeBigEndian(int value, int length) {
  final res = Uint8List(length);

  for (int i = (length - 1); i >= 0; i--) {
    res[i] = value & 0xff;
    value = value >> 8;
  }
  return res;
}

int decodeBigEndian(Uint8List bytes) {
  int total = 0;
  for (int i = 0; i < bytes.length; i++) {
    total += bytes[bytes.length - (i + 1)] * pow(256, i) as int;
  }

  return total;
}
