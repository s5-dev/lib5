import 'dart:typed_data';

import 'package:base_codecs/base_codecs.dart';

class UserID {
  int get type => bytes[0];
  final Uint8List bytes;

  UserID(this.bytes);

  @override
  String toString() {
    return 'z${base58BitcoinEncode(bytes)}';
  }
}

class MetadataUser {
  final UserID userId;
  final String? role;
  final bool signed;

  MetadataUser({
    required this.userId,
    required this.role,
    required this.signed,
  });

  Map<String, dynamic> toJson() {
    final map = <String, dynamic>{};
    void addNotNull(String key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull('userId', userId.toString());
    addNotNull('role', role);
    addNotNull('signed', signed);

    return map;
  }
}
