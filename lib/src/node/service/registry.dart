import 'dart:async';
import 'dart:typed_data';

import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';
import 'package:lib5/registry.dart';
import 'package:lib5/src/node/node.dart';
import 'package:lib5/src/node/service/p2p.dart';
import 'package:lib5/util.dart';
import 'package:s5_msgpack/s5_msgpack.dart';

class RegistryService {
  final KeyValueDB db;
  final S5NodeBase node;

  RegistryService(this.node, {required this.db});

  Future<void> set(
    RegistryEntry sre, {
    bool trusted = false,
    Peer? receivedFrom,
    Route? route,
  }) async {
    node.logger.verbose(
      '[registry] set ${base64UrlNoPaddingEncode(sre.pk)} ${sre.revision} (${receivedFrom?.id})',
    );

    if (!trusted) {
      if (sre.pk.length != 33) {
        throw 'Invalid pubkey';
      }
      if (sre.pk[0] != mkeyEd25519) {
        throw 'Only ed25519 keys are supported';
      }
      if (sre.revision < 0 || sre.revision > 281474976710656) {
        throw 'Invalid revision';
      }
      if (sre.data.length > registryMaxDataSize) {
        throw 'Data too long';
      }
      final isValid = await verifyRegistryEntry(
        sre,
        crypto: node.crypto,
      );

      if (!isValid) {
        throw 'Invalid signature found';
      }
    }

    final existingEntry = getFromDB(sre.pk);

    if (existingEntry != null) {
      if (receivedFrom != null) {
        if (existingEntry.revision == sre.revision) {
          return;
        } else if (existingEntry.revision > sre.revision) {
          final updateMessage = existingEntry.serialize();
          receivedFrom.sendMessage(updateMessage);
          return;
        }
      }

      if (existingEntry.revision >= sre.revision) {
        throw 'Revision number too low';
      }
    }
    final key = Multihash(sre.pk);

    streams[key]?.add(sre);

    db.set(sre.pk, sre.serialize());

    broadcastEntry(sre, receivedFrom);
  }

  // TODO Clean this table after some time
  // TODO final registryUpdateRoutingTable = <String, List<String>>{};
  // TODO if there are more than X peers, only broadcast to subscribed nodes (routing table) and shard-nodes (256)
  void broadcastEntry(RegistryEntry sre, Peer? receivedFrom) {
    node.logger.verbose('[registry] broadcastEntry');
    final updateMessage = sre.serialize();

    // TODO Only forward to routing table
    for (final p in node.p2p.peers.values) {
      if (receivedFrom == null || p.id != receivedFrom.id) {
        p.sendMessage(updateMessage);
      }
    }
  }

  void sendRegistryRequest(Uint8List pk, {NodeID? receivedFrom}) {
    final p = Packer();

    p.packInt(protocolMethodRegistryQuery);
    p.packBinary(pk);

    final req = p.takeBytes();

    // TODO Use shard system if there are more than X peers

    if (receivedFrom == null) {
      for (final peer in node.p2p.peers.values) {
        peer.sendMessage(req);
      }
    } else {
      for (final peer in node.p2p.peers.values) {
        if (receivedFrom != peer.id) {
          peer.sendMessage(req);
        }
      }
    }
  }

  final streams = <Multihash, StreamController<RegistryEntry>>{};
  final subs = <Multihash>{};

  Future<RegistryEntry?> get(Uint8List pk, {Route? route}) async {
    final key = Multihash(pk);
    if (subs.contains(key)) {
      node.logger.verbose('[registry] get (subbed) $key');
      final res = getFromDB(pk);
      if (res != null) {
        return res;
      }
      sendRegistryRequest(pk);
      await Future.delayed(Duration(milliseconds: 200));
      return getFromDB(pk);
    } else {
      sendRegistryRequest(pk);
      subs.add(key);
      if (!streams.containsKey(key)) {
        streams[key] = StreamController<RegistryEntry>.broadcast();
      }
      if (getFromDB(pk) == null) {
        node.logger.verbose('[registry] get (clean) $key');
        for (int i = 0; i < 200; i++) {
          await Future.delayed(Duration(milliseconds: 10));
          if (getFromDB(pk) != null) break;
        }
      } else {
        node.logger.verbose('[registry] get (cached) $key');
        await Future.delayed(Duration(milliseconds: 200));
      }
      return getFromDB(pk);
    }
  }

  Stream<RegistryEntry> listen(Uint8List pk, {Route? route}) {
    final key = Multihash(pk);
    if (!streams.containsKey(key)) {
      streams[key] = StreamController<RegistryEntry>.broadcast();
      sendRegistryRequest(pk);
    }
    return streams[key]!.stream;
  }

  RegistryEntry? getFromDB(Uint8List pk) {
    if (db.contains(pk)) {
      return RegistryEntry.deserialize(db.get(pk)!);
    }
    return null;
  }

  Future<void> setEntryHelper(
    KeyPairEd25519 keyPair,
    Uint8List data,
  ) async {
    final revision = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    final sre = await signRegistryEntry(
      kp: keyPair,
      data: data,
      revision: revision,
      crypto: node.crypto,
    );

    set(sre);
  }
}
