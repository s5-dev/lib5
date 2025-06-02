import 'dart:typed_data';

import 'package:lib5/src/crypto/base.dart';
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

    final mainIdentitySeed = deriveHashInt(
      seedBytes,
      mainIdentityTweak,
      crypto: crypto,
    );

    final publicIdentitySeed = deriveHashInt(
      mainIdentitySeed,
      publicIdentityTweak,
      crypto: crypto,
    );

    // Should be =floor( publicIdentityRevisionNumber / 1024 )
    final int keyRotationIndex = 0;

    final publicSubSeed = deriveHashInt(
      publicIdentitySeed,
      keyRotationIndex,
      crypto: crypto,
    );

    final privateDataSeed = deriveHashInt(
      mainIdentitySeed,
      privateDataTweak,
      crypto: crypto,
    );

    final privateSubSeed = deriveHashInt(
      privateDataSeed,
      keyRotationIndex,
      crypto: crypto,
    );

    final subSeeds = <int, Uint8List>{
      signingKeyPairTweak: deriveHashInt(
        publicSubSeed,
        signingKeyPairTweak,
        crypto: crypto,
      ),
      encryptionKeyPairTweak: deriveHashInt(
        publicSubSeed,
        encryptionKeyPairTweak,
        crypto: crypto,
      ),
      resolverLinksTweak: deriveHashInt(
        publicSubSeed,
        resolverLinksTweak,
        crypto: crypto,
      ),
      publicReservedTweak1: deriveHashInt(
        publicSubSeed,
        publicReservedTweak1,
        crypto: crypto,
      ),
      publicReservedTweak2: deriveHashInt(
        publicSubSeed,
        publicReservedTweak2,
        crypto: crypto,
      ),
      storageServiceAccountsTweak: deriveHashInt(
        privateSubSeed,
        storageServiceAccountsTweak,
        crypto: crypto,
      ),
      hiddenDBTweak: deriveHashInt(
        privateSubSeed,
        hiddenDBTweak,
        crypto: crypto,
      ),
      fileSystemTweak: deriveHashInt(
        privateSubSeed,
        fileSystemTweak,
        crypto: crypto,
      ),
      privateReservedTweak1: deriveHashInt(
        privateSubSeed,
        privateReservedTweak1,
        crypto: crypto,
      ),
      privateReservedTweak2: deriveHashInt(
        privateSubSeed,
        privateReservedTweak2,
        crypto: crypto,
      ),
      extensionTweak: deriveHashInt(
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
