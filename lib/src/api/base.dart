import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata/base.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/model/node_id.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/stream/message.dart';
import 'package:lib5/src/util/typedefs.dart';

abstract class S5APIProvider {
  Future<SignedRegistryEntry?> registryGet(
    Uint8List pk, {
    Route? route,
  });
  Stream<SignedRegistryEntry> registryListen(
    Uint8List pk, {
    Route? route,
  });
  Future<void> registrySet(
    SignedRegistryEntry sre, {
    Route? route,
  });

  Stream<SignedStreamMessage> streamSubscribe(
    Uint8List pk, {
    int? afterTimestamp,
    int? beforeTimestamp,
    Route? route,
  });
  Future<void> streamPublish(
    SignedStreamMessage msg, {
    Route? route,
  });

  /// Upload a small blob of bytes
  ///
  /// Returns the Raw CID of the uploaded raw file blob
  ///
  /// Max size is 10 MB, use [uploadRawFile] for larger files
  Future<CID> uploadBlob(Uint8List data);

  /// Upload a raw file
  ///
  /// Returns the Raw CID of the uploaded raw file blob
  ///
  /// Does not have a file size limit and can handle large files efficiently
  Future<CID> uploadRawFile({
    required Multihash hash,
    required int size,
    required OpenReadFunction openRead,
  });

  /// Downloads a full file blob to memory, you should only use this if they are smaller than 1 MB
  Future<Uint8List> downloadRawFile(Multihash hash, {Route? route});

  /// Download Metadata by its CID
  Future<Metadata> downloadMetadata(CID cid, {Route? route});

  Future<void> deleteCID(CID cid);

  CryptoImplementation get crypto;
}

class Route {
  final List<NodeID>? nodes;

  Route({this.nodes});
}
