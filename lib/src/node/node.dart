import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:lib5/lib5.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/node/service/p2p.dart';
import 'package:lib5/src/node/service/registry.dart';
import 'package:lib5/src/node/service/stream.dart';
import 'package:lib5/src/node/store.dart';
import 'package:lib5/src/node/util/uri_provider.dart';
import 'package:lib5/util.dart';
import 'package:s5_msgpack/s5_msgpack.dart';
import 'package:tint/tint.dart';

class S5NodeBase {
  final Map<String, dynamic> config;
  final Logger logger;
  CryptoImplementation crypto;
  late final KeyValueDB objectsBox;

  late final RegistryService registry;
  late final StreamMessageService stream;
  late final P2PService p2p;

  final httpClient = Client();

  bool get exposeStore => false;
  ObjectStore? store;

  S5NodeBase({
    required this.config,
    required this.logger,
    required this.crypto,
  });

  Future<void> init({
    required KeyValueDB blobDB,
    required KeyValueDB registryDB,
    required KeyValueDB streamDB,
    required KeyValueDB nodesDB,
    P2PService? p2pService,
  }) async {
    objectsBox = blobDB;

    p2p = p2pService ?? P2PService(this);

    p2p.nodeKeyPair = await crypto.newKeyPairEd25519(
      seed: base64UrlNoPaddingDecode(
        (config['keypair']['seed'] as String).replaceAll('=', ''),
      ),
    );

    await p2p.init(nodesDB);

    logger.info('${'NODE ID'.bold()}: ${p2p.localNodeId.toString().green()}');

    logger.info('');

    registry = RegistryService(this, db: registryDB);
    stream = StreamMessageService(this, db: streamDB);
  }

  Future<void> start() async {
    await p2p.start();
  }

  Map<int, Map<NodeID, Map<int, dynamic>>> readStorageLocationsFromDB(
    Multihash hash,
  ) {
    final Map<int, Map<NodeID, Map<int, dynamic>>> map = {};
    final bytes = objectsBox.get(hash.fullBytes);
    if (bytes == null) {
      return map;
    }
    final unpacker = Unpacker(bytes);
    final mapLength = unpacker.unpackMapLength();
    for (int i = 0; i < mapLength; i++) {
      final type = unpacker.unpackInt();
      map[type!] = {};
      final mapLength = unpacker.unpackMapLength();
      for (int j = 0; j < mapLength; j++) {
        final nodeId = unpacker.unpackBinary();
        map[type]![NodeID(nodeId)] = unpacker.unpackMap().cast<int, dynamic>();
      }
    }
    return map;
  }

  void addStorageLocation(
    Multihash hash,
    NodeID nodeId,
    StorageLocation location, {
    Uint8List? message,
  }) async {
    final map = readStorageLocationsFromDB(hash);

    map[location.type] ??= {};

    map[location.type]![nodeId] = {
      1: location.parts,
      // 2: location.binaryParts,
      3: location.expiry,
      4: message,
    };

    objectsBox.set(
      hash.fullBytes,
      (Packer()..pack(map)).takeBytes(),
    );
  }

  Map<NodeID, StorageLocation> getCachedStorageLocations(
    Multihash hash,
    List<int> types,
  ) {
    final locations = <NodeID, StorageLocation>{};

    final map = readStorageLocationsFromDB(hash);
    if (map.isEmpty) {
      return {};
    }

    final ts = (DateTime.now().millisecondsSinceEpoch / 1000).round();

    for (final type in types) {
      if (!map.containsKey(type)) continue;
      for (final e in map[type]!.entries) {
        if (e.value[3] < ts) {
        } else {
          locations[e.key] = StorageLocation(
            type,
            e.value[1].cast<String>(),
            e.value[3],
          )..providerMessage = e.value[4];
        }
      }
    }
    return locations;
  }

  Future<CID> uploadRawFile(Uint8List data) async {
    throw UnimplementedError();
  }

  final metadataCache = <Multihash, Metadata>{};

  Future<Metadata> downloadMetadata(CID cid) async {
    final hash = cid.hash;

    late final Metadata metadata;

    if (metadataCache.containsKey(hash)) {
      metadata = metadataCache[hash]!;
    } else {
      final bytes = await downloadBytesByHash(hash);

      if (cid.type == cidTypeMetadataMedia) {
        metadata = await deserializeMediaMetadata(bytes, crypto: crypto);
      } else if (cid.type == cidTypeMetadataWebApp) {
        metadata = deserializeWebAppMetadata(bytes);
      } else if (cid.type == cidTypeMetadataDirectory) {
        metadata = DirectoryMetadata.deserizalize(bytes);
      } else if (cid.type == cidTypeBridge) {
        metadata = await deserializeMediaMetadata(bytes, crypto: crypto);
      } else {
        throw 'Unsupported metadata format';
      }
      metadataCache[hash] = metadata;
    }
    return metadata;
  }

  Future<Uint8List> downloadBytesByHash(Multihash hash) async {
    final dlUriProvider = StorageLocationProvider(this, hash, [
      storageLocationTypeFull,
      storageLocationTypeFile,
    ]);

    dlUriProvider.start();

    int retryCount = 0;
    while (true) {
      final dlUri = await dlUriProvider.next();

      logger.verbose('[try] ${dlUri.location.bytesUrl}');

      try {
        final res = await httpClient
            .get(Uri.parse(dlUri.location.bytesUrl))
            .timeout(Duration(seconds: 30)); // TODO Adjust timeout

        if (hash.functionType == cidTypeBridge) {
          if (res.statusCode != 200) {
            throw 'HTTP ${res.statusCode}: ${res.body} for ${dlUri.location.bytesUrl}';
          }
          // TODO Have list of trusted Node IDs here, already filter them BEFORE EVEN DOWNLOADING
        } else {
          final resHash = await crypto.hashBlake3(res.bodyBytes);

          if (!areBytesEqual(hash.hashBytes, resHash)) {
            throw 'Integrity verification failed';
          }
          dlUriProvider.upvote(dlUri);
        }

        return res.bodyBytes;
      } catch (e, st) {
        logger.catched(e, st);

        dlUriProvider.downvote(dlUri);
      }
      retryCount++;
      if (retryCount > 8) {
        throw 'Too many retries';
      }
    }
  }

  Future<void> fetchHashLocally(Multihash hash, List<int> types) async {}
}
