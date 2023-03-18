import 'dart:typed_data';

import 'package:messagepack/messagepack.dart';
import 'package:lib5/src/model/metadata/extra.dart';
import 'package:lib5/src/model/metadata/web_app.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';

WebAppMetadata deserializeWebAppMetadata(Uint8List bytes) {
  final u = Unpacker(bytes);

  final magicByte = u.unpackInt();
  if (magicByte != metadataMagicByte) {
    throw 'Invalid metadata: Unsupported magic byte';
  }
  final typeAndVersion = u.unpackInt();
  if (typeAndVersion != metadataTypeWebApp) {
    throw 'Invalid metadata: Wrong metadata type';
  }

  u.unpackListLength();

  final name = u.unpackString();

  final tryFiles = u.unpackList().cast<String>();

  final errorPages = u.unpackMap().cast<int, String>();

  final length = u.unpackListLength();

  final Map<String, WebAppMetadataFileReference> paths = {};

  for (int i = 0; i < length; i++) {
    u.unpackListLength();
    final path = u.unpackString()!;
    final cid = CID.fromBytes(u.unpackBinary());
    paths[path] = WebAppMetadataFileReference(
      cid: cid,
      contentType: u.unpackString(),
    );
  }

  final extraMetadata = u.unpackMap().cast<int, dynamic>();

  final dm = WebAppMetadata(
    name: name,
    tryFiles: tryFiles,
    errorPages: errorPages,
    paths: paths,
    extraMetadata: ExtraMetadata(extraMetadata),
  );

  return dm;
}
