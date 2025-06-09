import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:lib5/lib5.dart';
import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/node/node.dart';
import 'package:lib5/src/util/typedefs.dart';

class S5NodeAPI extends S5APIProvider {
  final S5NodeBase node;

  S5NodeAPI(this.node);

  Future<void> init() async {
    await node.start();
    while (node.p2p.peers.isEmpty) {
      await Future.delayed(Duration(milliseconds: 5));
    }
  }

  Client get httpClient => node.httpClient;

  @override
  CryptoImplementation get crypto => node.crypto;

  @override
  Future<BlobIdentifier> uploadBlobAsBytes(Uint8List data) {
    throw UnimplementedError();
  }

  @override
  Future<BlobIdentifier> uploadBlobWithStream({
    required Multihash hash,
    required int size,
    required OpenReadFunction openRead,
    Function(double)? onProgress,
  }) {
    throw UnimplementedError();
  }

  @Deprecated('this should be handled on the application layer')
  Future<Metadata> downloadMetadata(CID cid, {Route? route}) {
    return node.downloadMetadata(cid);
  }

  @override
  Future<RegistryEntry?> registryGet(Uint8List pk, {Route? route}) =>
      node.registry.get(pk, route: route);

  @override
  Stream<RegistryEntry> registryListen(Uint8List pk, {Route? route}) =>
      node.registry.listen(pk, route: route);

  @override
  Future<void> registrySet(RegistryEntry sre, {Route? route}) =>
      node.registry.set(sre, route: route);

  @override
  Future<void> streamPublish(StreamMessage msg, {Route? route}) async {
    await node.stream.set(msg, trusted: true, route: route);
  }

  @override
  Stream<StreamMessage> streamSubscribe(
    Uint8List pk, {
    int? afterRevision,
    int? maxRevision,
    Route? route,
  }) {
    return node.stream.subscribe(
      pk,
      afterRevision: afterRevision,
      maxRevision: maxRevision,
      route: route,
    );
  }

  @override
  Future<Uint8List> downloadBlobAsBytes(Multihash hash, {Route? route}) {
    return node.downloadBytesByHash(hash);
  }

  @override
  Future<Uint8List> downloadBlobSlice(Multihash hash,
      {required int start, required int end, Route? route}) {
    // TODO: implement downloadBlobSlice
    throw UnimplementedError();
  }

  @override
  Future<void> ensureInitialized() {
    // TODO: implement ensureInitialized
    throw UnimplementedError();
  }

  @override
  Future<void> pinHash(Multihash hash) {
    // TODO: implement pinHash
    throw UnimplementedError();
  }

  @override
  Future<void> unpinHash(Multihash hash) {
    // TODO: implement unpinHash
    throw UnimplementedError();
  }
}
