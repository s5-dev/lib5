import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata/user_identity.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:s5_msgpack/s5_msgpack.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/seed/seed.dart';
import 'package:lib5/src/util/derive_hash.dart';
import 'package:lib5/src/util/pack_anything.dart';

import 'constants.dart';

class S5UserIdentity {
  final Map<int, Uint8List> subSeeds;

  S5UserIdentity(this.subSeeds);

  factory S5UserIdentity.unpack(Uint8List bytes) {
    final u = Unpacker(bytes);
    if (u.unpackInt() != authPayloadVersion1) {
      throw 'Auth payload version not supported';
    }
    return S5UserIdentity(
      u.unpackMap().cast<int, Uint8List>(),
    );
  }

  Uint8List pack() {
    final p = Packer();
    p.packInt(authPayloadVersion1);
    p.pack(subSeeds);
    return p.takeBytes();
  }

  /// Use this when first creating a user identity, for staying logged in you should use the pack/unpack methods
  /// ! NEVER STORE THE SEED PHRASE !
  static Future<S5UserIdentity> fromSeedPhrase(
    String seedPhrase, {
    required CryptoImplementation crypto,
  }) async {
    return S5UserIdentity(
      await _generateSeedMapFromSeedPhrase(seedPhrase, crypto: crypto),
    );
  }

  /// Call this once when creating a new user identity on the network (sets up metadata and recovery mechanism)
  static Future<void> createUserIdentity(
    String seedPhrase, {
    required CryptoImplementation crypto,
  }) async {
    final seedMap = await _generateSeedMapFromSeedPhrase(
      seedPhrase,
      full: true,
      crypto: crypto,
    );

    final signingKeyPair = await crypto.newKeyPairEd25519(
      seed: seedMap[signingKeyPairTweak]!,
    );
    final links = <int, CID>{};
    for (int i = 0; i < 32; i++) {
      final resolverKeyPair = await crypto.newKeyPairEd25519(
        seed: deriveHashBlake3Int(
          seedMap[resolverLinksTweak]!,
          i,
          crypto: crypto,
        ),
      );
      links[i] = CID(cidTypeResolver, Multihash(resolverKeyPair.publicKey));
    }

    // ignore: unused_local_variable
    final userIdentityMetadata = UserIdentityMetadata(
      details: UserIdentityMetadataDetails(
        created: (DateTime.now().millisecondsSinceEpoch / 1000).round(),
        createdBy: 'lib5',
      ),
      signingKeys: [UserIdentityPublicKey(signingKeyPair.publicKey)],
      encryptionKeys: [],
      links: links,
    );

    /* final cid = await api.uploadBlob(
      serializeUserIdentityMetadata(userIdentityMetadata),
    );

    final publicIdentityKeyPair = await api.crypto.newKeyPairEd25519(
      seed: seedMap[publicIdentityTweak]!,
    );

    final sre = await signRegistryEntry(
      kp: publicIdentityKeyPair,
      data: cid.toRegistryEntry(),
      revision: 0,
      crypto: api.crypto,
    );
    await api.registrySet(sre); */
  }

  static String generateSeedPhrase({required CryptoImplementation crypto}) {
    return generatePhrase(crypto: crypto);
  }

  static Future<Map<int, Uint8List>> _generateSeedMapFromSeedPhrase(
    String seedPhrase, {
    bool full = false,
    required CryptoImplementation crypto,
  }) async {
    final seedEntropy = validatePhrase(seedPhrase, crypto: crypto);

    final seedBytes = crypto.hashBlake3Sync(seedEntropy);

    final mainIdentitySeed = deriveHashBlake3Int(
      seedBytes,
      mainIdentityTweak,
      crypto: crypto,
    );

    final publicIdentitySeed = deriveHashBlake3Int(
      mainIdentitySeed,
      publicIdentityTweak,
      crypto: crypto,
    );

    // Should be =floor( publicIdentityRevisionNumber / 1024 )
    final int keyRotationIndex = 0;

    final publicSubSeed = deriveHashBlake3Int(
      publicIdentitySeed,
      keyRotationIndex,
      crypto: crypto,
    );

    final privateDataSeed = deriveHashBlake3Int(
      mainIdentitySeed,
      privateDataTweak,
      crypto: crypto,
    );

    final privateSubSeed = deriveHashBlake3Int(
      privateDataSeed,
      keyRotationIndex,
      crypto: crypto,
    );

    final subSeeds = <int, Uint8List>{
      signingKeyPairTweak: deriveHashBlake3Int(
        publicSubSeed,
        signingKeyPairTweak,
        crypto: crypto,
      ),
      encryptionKeyPairTweak: deriveHashBlake3Int(
        publicSubSeed,
        encryptionKeyPairTweak,
        crypto: crypto,
      ),
      resolverLinksTweak: deriveHashBlake3Int(
        publicSubSeed,
        resolverLinksTweak,
        crypto: crypto,
      ),
      publicReservedTweak1: deriveHashBlake3Int(
        publicSubSeed,
        publicReservedTweak1,
        crypto: crypto,
      ),
      publicReservedTweak2: deriveHashBlake3Int(
        publicSubSeed,
        publicReservedTweak2,
        crypto: crypto,
      ),
      storageServiceAccountsTweak: deriveHashBlake3Int(
        privateSubSeed,
        storageServiceAccountsTweak,
        crypto: crypto,
      ),
      hiddenDBTweak: deriveHashBlake3Int(
        privateSubSeed,
        hiddenDBTweak,
        crypto: crypto,
      ),
      fileSystemTweak: deriveHashBlake3Int(
        privateSubSeed,
        fileSystemTweak,
        crypto: crypto,
      ),
      privateReservedTweak1: deriveHashBlake3Int(
        privateSubSeed,
        privateReservedTweak1,
        crypto: crypto,
      ),
      privateReservedTweak2: deriveHashBlake3Int(
        privateSubSeed,
        privateReservedTweak2,
        crypto: crypto,
      ),
      extensionTweak: deriveHashBlake3Int(
        privateSubSeed,
        extensionTweak,
        crypto: crypto,
      ),
    };

    if (full) {
      subSeeds[publicIdentityTweak] = publicIdentitySeed;
    }

    return subSeeds;
  }

  Uint8List get fsRootKey => subSeeds[fileSystemTweak]!;
  Uint8List get hiddenDBKey => subSeeds[hiddenDBTweak]!;

/*   HiddenDBProvider get hiddenDB => TrustedHiddenDBProvider(
        subSeeds[hiddenDBTweak]!,
        api,
      ); */
}
