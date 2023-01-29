import 'dart:typed_data';

import 'package:messagepack/messagepack.dart';
import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/hidden_db/api.dart';
import 'package:lib5/src/seed/seed.dart';
import 'package:lib5/src/util/derive_hash.dart';
import 'package:lib5/src/util/pack_anything.dart';

import 'constants.dart';

class S5UserIdentity {
  final S5APIProvider api;

  final Map<int, Uint8List> subSeeds;

  Uint8List get fsRootKey => subSeeds[fileSystemTweak]!;

  S5UserIdentity(this.subSeeds, {required this.api});

  factory S5UserIdentity.unpack(
    Uint8List bytes, {
    required S5APIProvider api,
  }) {
    final u = Unpacker(bytes);
    if (u.unpackInt() != authPayloadVersion1) {
      throw 'Auth payload version not supported';
    }
    return S5UserIdentity(
      u.unpackMap().cast<int, Uint8List>(),
      api: api,
    );
  }

  Uint8List pack() {
    final p = Packer();
    p.packInt(authPayloadVersion1);
    p.pack(subSeeds);
    return p.takeBytes();
  }

  static Future<S5UserIdentity> fromSeedPhrase(
    String seedPhrase, {
    required S5APIProvider api,
  }) async {
    final crypto = api.crypto;
    final seedEntropy = validatePhrase(seedPhrase, crypto: crypto);

    final seedBytes = crypto.hashBlake3Sync(seedEntropy);

    final mainIdentitySeed = deriveHashBlake3Int(
      seedBytes,
      mainIdentityTweak,
      crypto: crypto,
    );

    // TODO Derive userId and public identity from recoverySeed
/*     final recoverySeed = deriveHashBlake3Int(
      mainIdentitySeed,
      recoveryTweak,
      crypto: crypto,
    );

    final publicSignatureSeed = deriveHashBlake3Int(
      mainIdentitySeed,
      publicSignatureSeedTweak,
      crypto: crypto,
    ); */

    final subSeeds = <int, Uint8List>{
//      1: deriveHashBlake3Int(publicSignatureSeed, 0,
//          crypto: crypto), // public-signatures
//      2: deriveHashBlake3Int(mainIdentitySeed, 1,
//          crypto: crypto), // public-base
      storageServiceAccountsTweak: deriveHashBlake3Int(
        mainIdentitySeed,
        storageServiceAccountsTweak,
        crypto: crypto,
      ),
      hiddenDBTweak: deriveHashBlake3Int(
        mainIdentitySeed,
        hiddenDBTweak,
        crypto: crypto,
      ),
      fileSystemTweak: deriveHashBlake3Int(
        mainIdentitySeed,
        fileSystemTweak,
        crypto: crypto,
      ),
      // TODO Allow custom overrides
    };

    return S5UserIdentity(subSeeds, api: api);
  }

  HiddenDBProvider get hiddenDB => TrustedHiddenDBProvider(
        subSeeds[hiddenDBTweak]!,
        api,
      );
}
