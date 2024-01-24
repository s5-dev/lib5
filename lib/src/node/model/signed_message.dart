import 'dart:typed_data';

import 'package:lib5/lib5.dart';

class SignedP2PMessage {
  final NodeID nodeId;
  final Uint8List message;

  SignedP2PMessage({required this.nodeId, required this.message});
}
