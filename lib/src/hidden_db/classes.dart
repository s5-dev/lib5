import 'dart:typed_data';

import 'package:lib5/src/identifier/blob.dart';

class HiddenRawDataResponse {
  final Uint8List? data;
  final int revision;
  final BlobIdentifier? cid;
  HiddenRawDataResponse({
    this.data,
    this.revision = -1,
    this.cid,
  });
}

class HiddenJSONResponse {
  final dynamic data;
  final int revision;
  final BlobIdentifier? cid;
  HiddenJSONResponse({
    this.data,
    this.revision = -1,
    this.cid,
  });
}
