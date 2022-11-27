import 'dart:typed_data';

import 'package:messagepack/messagepack.dart';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata.dart';

DirectoryMetadata deserializeDirectoryMetadata(Uint8List bytes) {
  final u = Unpacker(bytes);

  final magicByte = u.unpackInt();
  if (magicByte != metadataMagicByte) {
    throw 'Invalid metadata: Unsupported magic byte';
  }
  final typeAndVersion = u.unpackInt();
  if (typeAndVersion != metadataTypeDirectory) {
    throw 'Invalid metadata: Wrong metadata type';
  }

  final dirname = u.unpackString();

  final tryFiles = u.unpackList().cast<String>();

  final errorPages = u.unpackMap().cast<int, String>();

  final length = u.unpackInt()!;

  final Map<String, DirectoryMetadataFileReference> paths = {};

  for (int i = 0; i < length; i++) {
    final path = u.unpackString()!;
    final cid = CID.fromBytes(Uint8List.fromList(u.unpackBinary()));
    paths[path] = DirectoryMetadataFileReference(
      cid: cid,
      contentType: u.unpackString(),
    );
  }

  final additionalMetadata = u.unpackMap().cast<int, dynamic>();

  final dm = DirectoryMetadata(
    dirname: dirname,
    tryFiles: tryFiles,
    errorPages: errorPages,
    paths: paths,
    additionalMetadata: AdditionalMetadata(additionalMetadata),
  );

  return dm;
}
