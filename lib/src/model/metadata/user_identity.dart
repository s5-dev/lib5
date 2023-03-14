import 'dart:typed_data';

import 'package:lib5/src/model/cid.dart';

class UserIdentityMetadata {
  late final CID userID;

  final UserIdentityMetadataDetails details;

  final List<UserIdentityPublicKey> signingKeys;
  final List<UserIdentityPublicKey> encryptionKeys;

  // Links to (usually) resolver CIDs
  final Map<int, CID> links;

  UserIdentityMetadata({
    required this.details,
    required this.signingKeys,
    required this.encryptionKeys,
    required this.links,
  });

  // TODO B3 Hashes / CIDs of previous versions with timestamps
}

class UserIdentityMetadataDetails {
  // Unix timestamp in seconds
  final int created;
  // final int modified;

  UserIdentityMetadataDetails({
    required this.created,
    required this.createdBy,
    // required this.modified,
  });

  // which code created this account
  final String createdBy;
}

class UserIdentityPublicKey {
  final Uint8List key;
  UserIdentityPublicKey(this.key);
}
