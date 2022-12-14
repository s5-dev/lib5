import 'dart:typed_data';

import 'package:lib5/src/model/metadata/media.dart';
import 'package:messagepack/messagepack.dart';

extension PackAnything on Packer {
  void pack(dynamic v) {
    if (v == null) {
      packNull();
    } else if (v is int) {
      packInt(v);
    } else if (v is bool) {
      packBool(v);
    } else if (v is double) {
      packDouble(v);
    } else if (v is String) {
      packString(v);
    } else if (v is Uint8List) {
      packBinary(v);
    } else if (v is List) {
      packListLength((v).length);
      for (final item in v) {
        pack(item);
      }
    } else if (v is Map) {
      packMapLength((v).length);
      for (final e in v.entries) {
        pack(e.key);
        pack(e.value);
      }
    } else if (v is MediaFormat) {
      pack(v.encode());
    } else {
      throw 'Could not pack ${v.runtimeType}';
    }
  }
}
