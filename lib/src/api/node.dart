import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:lib5/lib5.dart';
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
  Future<void> deleteCID(CID cid) {
    throw UnimplementedError();
  }

  @override
  Future<CID> uploadBlob(Uint8List data) {
    throw UnimplementedError();
  }

  @override
  Future<CID> uploadRawFile(
      {required Multihash hash,
      required int size,
      required OpenReadFunction openRead}) {
    throw UnimplementedError();
  }

  @override
  Future<Uint8List> downloadRawFile(Multihash hash, {Route? route}) {
    return node.downloadBytesByHash(hash);
  }

  @override
  Future<Metadata> downloadMetadata(CID cid, {Route? route}) {
    return node.downloadMetadata(cid);
  }

  @override
  Future<SignedRegistryEntry?> registryGet(Uint8List pk, {Route? route}) =>
      node.registry.get(pk, route: route);

  @override
  Stream<SignedRegistryEntry> registryListen(Uint8List pk, {Route? route}) =>
      node.registry.listen(pk, route: route);

  @override
  Future<void> registrySet(SignedRegistryEntry sre, {Route? route}) =>
      node.registry.set(sre, route: route);

  @override
  Future<void> streamPublish(SignedStreamMessage msg, {Route? route}) async {
    await node.stream.set(msg, trusted: true, route: route);
  }

  @override
  Stream<SignedStreamMessage> streamSubscribe(
    Uint8List pk, {
    int? afterTimestamp,
    int? beforeTimestamp,
    Route? route,
  }) {
    return node.stream.subscribe(
      pk,
      afterTimestamp: afterTimestamp,
      beforeTimestamp: beforeTimestamp,
      route: route,
    );
  }
}
