import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';
import 'package:lib5/src/model/multibase.dart';
import 'package:lib5/util.dart';

class NodeID extends Multibase {
  final Uint8List bytes;
  NodeID(this.bytes);

  factory NodeID.decode(String nodeId) {
    return NodeID(Multibase.decodeString(nodeId));
  }

  @override
  bool operator ==(Object other) {
    if (other is! NodeID) {
      return false;
    }
    return areBytesEqual(bytes, other.bytes);
  }

  @override
  Uint8List toBytes() => bytes;

  @override
  int get hashCode {
    return bytes[0] +
        (bytes[1] * 256) +
        (bytes[2] * 256 * 256) +
        (bytes[3] * 256 * 256 * 256);
  }
}
