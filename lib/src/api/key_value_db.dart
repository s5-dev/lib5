import 'dart:typed_data';

abstract class KeyValueDB {
  void set(Uint8List key, Uint8List value);
  Uint8List? get(Uint8List key);
  bool contains(Uint8List key);
  void delete(Uint8List key);
}
