/// Provides access to S5 identity related functions.
///
/// ```dart
/// // Assuming you have a CryptoImplementation instance named 'crypto'
/// final CryptoImplementation crypto = s5.crypto;

/// // Generate a seed phrase
/// String seedPhrase = generatePhrase(crypto: crypto);
/// print('Generated Seed Phrase: $seedPhrase');

/// // Verify the seed phrase
/// try {
///   Uint8List seed = validatePhrase(seedPhrase, crypto: crypto);
///   print('Seed is valid. Seed bytes: $seed');
/// } catch (e) {
///   print('Seed validation failed: $e');
/// }

library lib5.identity;

export 'package:lib5/src/identity/identity.dart';
export 'package:lib5/src/seed/seed.dart';
