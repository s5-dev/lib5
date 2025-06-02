import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata/user_identity.dart';
import 'package:lib5/src/util/pack_anything.dart';
import 'package:s5_msgpack/s5_msgpack.dart';

@Deprecated(
    's5 no longer uses a custom data structure for public identity data')
Uint8List serializeUserIdentityMetadata(
  UserIdentityMetadata u,
) {
  final c = Packer();
  c.packInt(metadataMagicByte);
  c.packInt(metadataTypeUserIdentity);

  c.packListLength(4);

  c.pack({
    2: u.details.created,
    3: u.details.createdBy,
  });

  c.packListLength(u.signingKeys.length);
  for (final key in u.signingKeys) {
    c.pack({1: key.key});
  }

  c.packListLength(u.encryptionKeys.length);
  for (final key in u.encryptionKeys) {
    c.pack({1: key.key});
  }

  c.pack(u.links);

  return c.takeBytes();
}

@Deprecated(
    's5 no longer uses a custom data structure for public identity data')
UserIdentityMetadata deserializeUserIdentityMetadata(Uint8List bytes) {
  final u = Unpacker(bytes);
  final magicByte = u.unpackInt();
  if (magicByte != metadataMagicByte) {
    throw 'Invalid metadata: Unsupported magic byte';
  }
  final typeAndVersion = u.unpackInt();
  if (typeAndVersion != metadataTypeUserIdentity) {
    throw 'Invalid user identity metadata: $typeAndVersion != $metadataTypeUserIdentity';
  }
  u.unpackListLength();

  final detailsMap = u.unpackMap();

  final signingKeys = u
      .unpackList()
      .map((m) => UserIdentityPublicKey((m as Map)[1] as Uint8List))
      .toList();

  final encryptionKeys = u
      .unpackList()
      .map((m) => UserIdentityPublicKey((m as Map)[1] as Uint8List))
      .toList();

  final linksMap = u.unpackMap().cast<int, Uint8List>();

  return UserIdentityMetadata(
    details: UserIdentityMetadataDetails(
      created: detailsMap[2] as int,
      createdBy: detailsMap[3] as String,
    ),
    signingKeys: signingKeys,
    encryptionKeys: encryptionKeys,
    links: linksMap.map((key, value) => MapEntry(key, CID.fromBytes(value))),
  );
}
