/// This provides access to the self-contained S5 node.
///
/// Note, it is NOT recommended to initialize your own node, but to instead use the [s5](https://pub.dev/packages/s5) wrapper.
/// Using s5.create() will generate a S5NodeBase instance without having to deal with all of this yourself.
/// It can be embedded in any dart runtime as follows.
/// ```dart
/// final Map<String, dynamic> config = {config params};
/// final Logger logger = yourlogger;
/// final CryptoImplementation crypto;
/// final S5NodeBase nodeBase = S5NodeBase(config: config, logger: logger, crypto: crypto);
/// // then you need to add a KV DB
/// if (config['database']?['path'] != null) {
///   Hive.init(config['database']['path']);
/// }
/// await nodebase.init(
///   blobDB: HiveKeyValueDB(
///     await Hive.openBox('s5-object-cache'),
///   ),
///   registryDB: HiveKeyValueDB(await Hive.openBox('s5-registry-db')),
///   streamDB: HiveKeyValueDB(await Hive.openBox('s5-stream-db')),
///   nodesDB: HiveKeyValueDB(await Hive.openBox('s5-nodes')),
///   p2pService: NativeP2PService(this),
/// );
/// ```

library lib5.node;

export 'src/api/node_with_identity.dart';
export 'src/api/node.dart';
export 'src/node/model/signed_message.dart';
export 'src/node/node.dart';
export 'src/node/service/p2p.dart';
export 'src/node/service/registry.dart';
export 'src/node/service/stream.dart';
export 'src/node/store.dart';
export 'src/node/util/uri_provider.dart';
