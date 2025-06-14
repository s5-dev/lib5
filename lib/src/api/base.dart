///
/// This implementation follows the S5 v1 spec at https://docs.sfive.net/spec/api-interface.html
///

import 'dart:typed_data';

import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/model/node_id.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/stream/message.dart';
import 'package:lib5/src/util/typedefs.dart';

abstract class S5APIProvider {
  /// Blocks until the S5 API is initialized and ready to be used
  Future<void> ensureInitialized();

  /// Upload a small blob of bytes
  ///
  /// Returns the Raw CID of the uploaded raw file blob
  ///
  /// Max size is 10 MiB, use [uploadRawFile] for larger files
  Future<BlobIdentifier> uploadBlobAsBytes(Uint8List data);

  /// Upload a raw file
  ///
  /// Returns the Raw CID of the uploaded raw file blob
  ///
  /// Does not have a file size limit and can handle large files efficiently
  Future<BlobIdentifier> uploadBlobWithStream({
    required Multihash hash,
    required int size,
    required OpenReadFunction openRead,
    Function(double)? onProgress,
  });

  /// Downloads a full file blob to memory, you should only use this if they are smaller than 1 MB
  Future<Uint8List> downloadBlobAsBytes(Multihash hash, {Route? route});

  /// Downloads a slice of a blob to memory, from `start` (inclusive) to `end` (exclusive)
  Future<Uint8List> downloadBlobSlice(
    Multihash hash, {
    required int start,
    required int end,
    Route? route,
  });

  Future<void> pinHash(Multihash hash);

  Future<void> unpinHash(Multihash hash);

  Future<RegistryEntry?> registryGet(
    Uint8List pk, {
    Route? route,
  });
  Stream<RegistryEntry> registryListen(
    Uint8List pk, {
    Route? route,
  });
  Future<void> registrySet(
    RegistryEntry entry, {
    Route? route,
  });

  Stream<StreamMessage> streamSubscribe(
    Uint8List pk, {
    int? afterRevision,
    int? maxRevision,
    Route? route,
  });
  Future<void> streamPublish(
    StreamMessage msg, {
    Route? route,
  });

  CryptoImplementation get crypto;
}

class Route {
  final List<NodeID>? nodes;

  Route({this.nodes});
}
