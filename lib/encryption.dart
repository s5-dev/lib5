/// Uses [CryptoImplementation] to handle lib5 related encryption tasks.
///
/// ```dart
/// final key = Uint8List(32); // Replace with your key
/// final data = Uint8List.fromList([1, 2, 3, 4, 5]); // Replace with your data
///
/// final encryptedData = await encryptMutableBytes(data, key, crypto: s5.crypto);
/// print('Encrypted data: $encryptedData');
///
/// final decryptedData = await decryptMutableBytes(encryptedData, key, crypto: crypto);
/// print('Decrypted data: $decryptedData');
/// ```

library lib5.encryption;

export 'package:lib5/src/crypto/encryption/mutable.dart';
