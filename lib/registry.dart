/// Provides access to registry functions like creating, signing, and verifying.
///
/// ```dart
/// // Assuming you have a CryptoImplementation instance named 'crypto'
/// final CryptoImplementation crypto = s5.crypto; // create s5 node earlier
///
/// // Generate a key pair
/// final keyPair = await crypto.newKeyPairEd25519();
///
/// // Data to store in the registry entry
/// final data = Uint8List.fromList([1, 2, 3, 4, 5]);
/// final revision = 1;
///
/// // Create and sign the registry entry
/// final entry = await SignedRegistryEntry.create(
///   kp: keyPair,
///   data: data,
///   revision: revision,
///   crypto: crypto,
/// );
///
/// // Verify the signed registry entry
/// final isValid = await entry.verify(crypto: crypto);
///
/// print('Registry entry is valid: $isValid');

library lib5.registry;

export 'src/registry/entry.dart';
export 'src/registry/sign.dart';
export 'src/registry/verify.dart';
