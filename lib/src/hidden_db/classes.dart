import 'dart:typed_data';

import 'package:lib5/src/model/cid.dart';

class HiddenRawDataResponse {
  final Uint8List? data;
  final int revision;
  final CID? cid;
  HiddenRawDataResponse({
    this.data,
    this.revision = -1,
    this.cid,
  });
}

class HiddenJSONResponse {
  final dynamic data;
  final int revision;
  final CID? cid;
  HiddenJSONResponse({
    this.data,
    this.revision = -1,
    this.cid,
  });
}
