import 'dart:async';
import 'dart:typed_data';

import 'package:lib5/constants.dart';
import 'package:lib5/lib5.dart';
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
    SignedStreamMessage msg, {
    bool trusted = false,
    Peer? receivedFrom,
    Route? route,
  }) async {
    if (db.contains(makeKey(msg))) {
      return;
    }
    node.logger.verbose(
      '[stream] set ${base64UrlNoPaddingEncode(msg.pk)} ${msg.ts} (${receivedFrom?.id})',
    );

    if (!trusted) {
      if (msg.pk.length != 33) {
        throw 'Invalid pubkey';
      }
      if (msg.pk[0] != mkeyEd25519) {
        throw 'Only ed25519 keys are supported';
      }
      if (msg.ts < 0 ||
          msg.ts >
              (DateTime.now()
                  .add(Duration(seconds: 10))
                  .microsecondsSinceEpoch)) {
        throw 'Invalid revision';
      }
      if (msg.data.length > 1000000) {
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

  Uint8List makeKey(SignedStreamMessage msg) {
    final seq = encodeBigEndian(msg.ts, 8);
    return Uint8List.fromList(msg.pk + seq);
  }

  void storeMessage(SignedStreamMessage msg) {
    final seq = encodeBigEndian(msg.ts, 8);
    final list = db.get(msg.pk) ?? Uint8List(0);

    db.set(
      makeKey(msg),
      msg.serialize(),
    );
    final duplicates = <Multihash>{};
    final timestamps = <Uint8List>[];
    timestamps.add(seq);
    duplicates.add(Multihash(seq));
    for (int i = 0; i < list.length; i += 8) {
      final sub = list.sublist(i, i + 8);
      final mh = Multihash(sub);
      if (duplicates.contains(mh)) continue;
      duplicates.add(mh);
      timestamps.add(sub);
    }
    timestamps.sort((a, b) {
      for (int i = 0; i < 8; i++) {
        if (a[i] < b[i]) return -1;
        if (a[i] > b[i]) return 1;
      }
      return 0;
    });

    db.set(
      msg.pk,
      Uint8List.fromList(
        timestamps.fold(
          <int>[],
          (previousValue, element) => previousValue + element,
        ),
      ),
    );
  }

  final streamQueryRoutingTable = <Multihash, Set<NodeID>>{};

  void broadcastEntry(
    SignedStreamMessage msg,
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

  final streams = <Multihash, StreamController<SignedStreamMessage>>{};

  // TODO Regularly clean to announce for new nodes after X time
  final subs = <Multihash>{};

  // TODO Implement beforeTimestamp
  Future<List<SignedStreamMessage>> getStoredMessages(
    Uint8List pk, {
    int? afterTimestamp,
    int? beforeTimestamp,
  }) async {
    final messages = <SignedStreamMessage>[];
    final list = db.get(pk) ?? Uint8List(0);
    for (int i = 0; i < list.length; i += 8) {
      final sub = list.sublist(i, i + 8);
      if (afterTimestamp != null) {
        if (decodeBigEndian(sub) <= afterTimestamp) continue;
      }
      messages.add(SignedStreamMessage.deserialize(
        db.get(Uint8List.fromList(pk + sub))!,
      ));
    }
    return messages;
  }

  Stream<SignedStreamMessage> subscribe(
    Uint8List pk, {
    int? afterTimestamp,
    int? beforeTimestamp, // TODO Implement beforeTimestamp and route
    Route? route,
  }) async* {
    for (final msg in await getStoredMessages(
      pk,
      afterTimestamp: afterTimestamp,
      beforeTimestamp: beforeTimestamp,
    )) {
      yield msg;
    }

    final pkHash = Multihash(pk);

    final key = Multihash(pk);
    if (!streams.containsKey(key)) {
      streams[key] = StreamController<SignedStreamMessage>.broadcast();
    }

    if (!subs.contains(pkHash)) {
      sendMessageRequest(pk, route: route);
      subs.add(pkHash);
    }

    yield* streams[key]!.stream.where((event) {
      if (afterTimestamp == null) return true;
      if (afterTimestamp < event.ts) return true;
      return false;
    });
  }

  // TODO Send this if connecting to new nodes
  void sendMessageRequest(
    Uint8List pk, {
    int? afterTimestamp,
    Route? route,
  }) {
    final p = Packer();

    p.packInt(protocolMethodMessageQuery);
    p.packBinary(pk);
    if (afterTimestamp != null) {
      p.pack({
        1: afterTimestamp,
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
