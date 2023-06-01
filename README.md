# lib5

This library is used by Dart-based code for the S5 network.

## Features

- Classes to work with CIDs, Multihashes and S5 file metadata
- Sign and verify registry entries
- Serialize/deserizalize metadata
- All S5 constants
- Some utils

### Install

```sh
dart pub add lib5
dart pub add lib5_crypto_implementation_dart
```

### Example

```dart
import 'package:lib5/lib5.dart';
import 'package:lib5/remote.dart';
import 'package:lib5/storage_service.dart';
import 'package:lib5_crypto_implementation_dart/lib5_crypto_implementation_dart.dart';
import 'package:http/http.dart' as http;

void main(List<String> arguments) async {
  final crypto = DartCryptoImplementation();  
  final s5Api = RemoteS5APIProvider(
    'https://s5.ninja',
    httpClient: http.Client(),
    crypto: crypto,
  );
  // ! Optional, required for uploads, needs local or remote node
  s5Api.storageServiceConfigs.add(
    StorageServiceConfig(
      scheme: 'http',
      authority: 'localhost:5050',
      headers: {},
    ),
  );
  final res = await s5Api.downloadRawFile(
    CID.decode('z4odvyg7EbrxBZ5mJjwSJEr47rdfL4jbVDrBfQnzzwNUup8s6').hash,
  );
}
```