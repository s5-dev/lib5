/// This is an experimental full FS implementation on top of S5.
///
/// Example usage:
/// ```dart
/// import 'dart:typed_data';
///
/// import 'package:lib5/lib5.dart';
/// import 'package:mime/mime.dart';
///
/// // Initialize the API provider and user identity
/// final String seed = "your seed here";
/// final S5 s5 = await S5.create();
/// await s5.recoverIdentityFromSeedPhrase(seed);
/// await s5.registerOnNewStorageService(
///   "https://s5.ninja",
/// );
/// final S5APIProvider apiProvider = s5.api;
/// final S5UserIdentity userIdentity = s5.identity;
///
/// // Create a FileSystem instance
/// final fileSystem = FileSystem(apiProvider, userIdentity);
///
/// // Initialize the file system
/// await fileSystem.init();
///
/// // Create a directory named 'exampleDir' in the root directory
/// await fileSystem.createDirectory('/', 'exampleDir');
///
/// // Create a file named 'exampleFile.txt' in the 'exampleDir' directory
/// final fileVersion = FileVersion(
///   ts: DateTime.now().millisecondsSinceEpoch,
///   plaintextCID: CID.raw(Multihash.blake3(Uint8List(32))),
/// );
///
/// final mediaType = lookupMimeType('exampleFile.txt');
///
/// await fileSystem.createFile(
///   directoryPath: '/exampleDir',
///   fileName: 'exampleFile.txt',
///   fileVersion: fileVersion,
///   mediaType: mediaType,
/// );
///
/// print('Directory and file created successfully!');
/// ```
///
/// The S5 FS has not been extensively tested yet, and using it directly through lib5
/// should be approached with caution.

library lib5.fs;

export 'src/fs/fs.dart';
