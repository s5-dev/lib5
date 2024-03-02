# lib5

This library is used by Dart-based code for the S5 Network.

It's more low-level, so if you just want to build an app on S5 you should instead use https://pub.dev/packages/s5

## Features

- Classes to work with CIDs, Multihashes and S5 file metadata
- Sign and verify registry entries
- Full S5 Node implementation which can run anywhere
- Serialize/deserizalize metadata
- All S5 constants
- Some utils

### Install

```sh
dart pub add lib5
dart pub add lib5_crypto_implementation_dart
```
