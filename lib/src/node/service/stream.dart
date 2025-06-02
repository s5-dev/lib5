import 'dart:async';
import 'dart:typed_data';

import 'package:lib5/constants.dart';
import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/api/key_value_db.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/model/node_id.dart';
import 'package:lib5/src/node/node.dart';
import 'package:lib5/src/node/service/p2p.dart';
import 'package:lib5/src/stream/message.dart';
import 'package:lib5/src/util/big_endian.dart';
import 'package:lib5/util.dart';
import 'package:s5_msgpack/s5_msgpack.dart';

class StreamMessageService {
  final KeyValueDB db;
  final S5NodeBase node;

  StreamMessageService(this.node, {required this.db});

  Future<void> set(
    StreamMessage msg, {
    bool trusted = false,
    Peer? receivedFrom,
    Route? route,
  }) async {
    if (db.contains(makeFullKey(msg))) {
      return;
    }
    node.logger.verbose(
      '[stream] set ${base64UrlNoPaddingEncode(msg.pk)} ${msg.seq} ${msg.nonce} (${receivedFrom?.id})',
    );

    if (!trusted) {
      if (msg.pk.length != 33) {
        throw 'Invalid pubkey';
      }
      if (msg.pk[0] != mkeyEd25519) {
        throw 'Only ed25519 keys are supported';
      }

      if ((msg.data?.length ?? 0) > 1000000) {
        throw 'Data too long';
      }

      final isValid = await msg.verify(
        crypto: node.crypto,
      );

      if (!isValid) {
        throw 'Invalid signature found';
      }
    }

    storeMessage(msg);

    if (!trusted) {
      streams[Multihash(msg.pk)]?.add(msg);
    }

    broadcastEntry(msg, receivedFrom, route: route);
  }

  Uint8List makeRev(StreamMessage msg) {
    return Uint8List.fromList(
      encodeBigEndian(msg.seq, 4) + encodeBigEndian(msg.nonce, 4),
    );
  }

  Uint8List makeFullKey(StreamMessage msg) {
    return Uint8List.fromList(msg.pk + makeRev(msg));
  }

  void storeMessage(StreamMessage msg) {
    final rev = makeRev(msg);
    final list = db.get(msg.pk) ?? Uint8List(0);

    db.set(
      makeFullKey(msg),
      msg.serialize(),
    );
    final duplicates = <Multihash>{};
    final revs = <Uint8List>[];
    revs.add(rev);
    duplicates.add(Multihash(rev));
    for (int i = 0; i < list.length; i += 8) {
      final sub = list.sublist(i, i + 8);
      final mh = Multihash(sub);
      if (duplicates.contains(mh)) continue;
      duplicates.add(mh);
      revs.add(sub);
    }
    revs.sort((a, b) {
      for (int i = 0; i < 8; i++) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
      }
      return 0;
    });

    db.set(
      msg.pk,
      Uint8List.fromList(
        revs.fold(
          <int>[],
          (previousValue, element) => previousValue + element,
        ),
      ),
    );
  }

  final streamQueryRoutingTable = <Multihash, Set<NodeID>>{};

  void broadcastEntry(
    StreamMessage msg,
    Peer? receivedFrom, {
    Route? route,
  }) {
    node.logger.verbose('[stream] broadcastEntry');
    final updateMessage = msg.serialize();

    if (receivedFrom == null) {
      if (route?.nodes != null) {
        for (final nodeId in route!.nodes!) {
          node.p2p.peers[nodeId]?.sendMessage(updateMessage);
        }
      } else {
        for (final p in node.p2p.peers.values) {
          p.sendMessage(updateMessage);
        }
      }
    } else {
      final interestedPeers = streamQueryRoutingTable[Multihash(msg.pk)] ?? {};
      for (final p in node.p2p.peers.values) {
        if (p.id != receivedFrom.id && interestedPeers.contains(p.id)) {
          p.sendMessage(updateMessage);
        }
      }
    }
  }

  final streams = <Multihash, StreamController<StreamMessage>>{};

  // TODO Regularly clean to announce for new nodes after X time
  final subs = <Multihash>{};

  // TODO Implement maxRevision
  Future<List<StreamMessage>> getStoredMessages(
    Uint8List pk, {
    int? afterRevision,
    int? maxRevision,
  }) async {
    final messages = <StreamMessage>[];
    final list = db.get(pk) ?? Uint8List(0);
    for (int i = 0; i < list.length; i += 8) {
      final sub = list.sublist(i, i + 8);
      if (afterRevision != null) {
        if (decodeBigEndian(sub) <= afterRevision) continue;
      }
      messages.add(StreamMessage.deserialize(
        db.get(Uint8List.fromList(pk + sub))!,
      ));
    }
    return messages;
  }

  Stream<StreamMessage> subscribe(
    Uint8List pk, {
    int? afterRevision,
    int? maxRevision, // TODO Implement maxRevision and route
    Route? route,
  }) async* {
    for (final msg in await getStoredMessages(
      pk,
      afterRevision: afterRevision,
      maxRevision: maxRevision,
    )) {
      yield msg;
    }

    final pkHash = Multihash(pk);

    final key = Multihash(pk);
    if (!streams.containsKey(key)) {
      streams[key] = StreamController<StreamMessage>.broadcast();
    }

    if (!subs.contains(pkHash)) {
      sendMessageRequest(pk, route: route);
      subs.add(pkHash);
    }

    yield* streams[key]!.stream.where((event) {
      if (afterRevision == null) return true;
      if (afterRevision < event.revision) return true;
      return false;
    });
  }

  // TODO Send this if connecting to new nodes
  void sendMessageRequest(
    Uint8List pk, {
    int? afterRevision,
    Route? route,
  }) {
    final p = Packer();

    p.packInt(protocolMethodMessageQuery);
    p.packBinary(pk);
    if (afterRevision != null) {
      p.pack({
        1: afterRevision,
      });
    }

    final req = p.takeBytes();

    // TODO Use shard system if there are more than X peers

    if (route?.nodes != null) {
      for (final nodeId in route!.nodes!) {
        node.p2p.peers[nodeId]?.sendMessage(req);
      }
    } else {
      for (final peer in node.p2p.peers.values) {
        peer.sendMessage(req);
      }
    }
  }
}
