import 'dart:typed_data';

import 'package:mime/mime.dart';

import 'package:lib5/lib5.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/encryption/mutable.dart';
import 'package:lib5/src/model/multibase.dart';
import 'package:lib5/src/util/derive_hash.dart';
import 'package:lib5/src/util/typedefs.dart';

final _encryptionKeyTweak = 1;

class FileSystem {
  final S5APIProvider _api;

  final S5UserIdentity? _identity;

  FileSystem(this._api, this._identity);

  Future<void> init() async {
    final res = await _runDirectoryTransaction(
      parseURI(await _buildRootWriteURI()),
      (dir, writeKey) async {
        final names = ['home', 'archive'];
        bool hasChanges = false;
        for (final name in names) {
          if (dir.directories.containsKey(name)) continue;
          dir.directories[name] = await _createDirectory(name, writeKey);
          hasChanges = true;
        }
        if (!hasChanges) return null;
        return dir;
      },
    );
    res.unwrap();
  }

  Future<void> createDirectoryRecursive(String path) async {
    final parts = path.split('/');
    for (int i = 1; i < parts.length; i++) {
      final dirp = parts.sublist(0, i).join('/');
      final dir = parts[i];
      try {
        await createDirectory(dirp, dir);
      } catch (e) {
        if ((e is DirectoryTransactionResult) &&
            e.e.toString() ==
                'Directory already contains a subdirectory with the same name') {
        } else {
          rethrow;
        }
      }
    }
  }

  Future<DirectoryReference> createDirectory(
    String path,
    String name,
  ) async {
    // TODO validateFileSystemEntityName(name);

    late final DirectoryReference dirReference;

    final res = await _runDirectoryTransaction(
      parseURI(await _preprocessLocalPath(path)),
      (dir, writeKey) async {
        if (dir.directories.containsKey(name)) {
          throw 'Directory already contains a subdirectory with the same name';
        }

        final newDir = await _createDirectory(name, writeKey);

        dir.directories[name] = newDir;

        dirReference = newDir;

        return dir;
      },
    );
    res.unwrap();
    return dirReference;
  }

  Future<FileReference> createFile({
    required String directoryPath,
    required String fileName,
    required FileVersion fileVersion,
    String? mediaType,
  }) async {
    // TODO validateFileSystemEntityName(name);

    late final FileReference fileReference;

    final res = await _runDirectoryTransaction(
      parseURI(await _preprocessLocalPath(directoryPath)),
      (dir, _) async {
        if (dir.files.containsKey(fileName)) {
          throw 'Directory already contains a file with the same name';
        }
        final file = FileReference(
          created: fileVersion.ts,
          name: fileName,
          mimeType: mediaType ?? lookupMimeType(fileName),
          version: 0,
          history: {},
          file: fileVersion,
          ext: fileVersion.ext,
        );
        file.file.ext = null;
        dir.files[fileName] = file;
        fileReference = file;

        return dir;
      },
    );
    res.unwrap();
    return fileReference;
  }

  Future<FileReference> createOrUpdateFile({
    required String directoryPath,
    required String fileName,
    required FileVersion fileVersion,
    String? mediaType,
  }) async {
    late final FileReference fileReference;
    final res = await _runDirectoryTransaction(
      parseURI(await _preprocessLocalPath(directoryPath)),
      (dir, _) async {
        if (dir.files.containsKey(fileName)) {
          final f = dir.files[fileName]!;
          f.history ??= {};
          f.mimeType = mediaType ?? f.mimeType ?? lookupMimeType(fileName);
          f.history![f.version] = f.file;
          f.version++;
          f.file = fileVersion;
          f.ext = fileVersion.ext;
          f.file.ext = null;
          fileReference = f;
          return dir;
        }
        final file = FileReference(
          created: fileVersion.ts,
          name: fileName,
          mimeType: mediaType ?? lookupMimeType(fileName),
          version: 0,
          history: {},
          file: fileVersion,
          ext: fileVersion.ext,
        );
        file.file.ext = null;
        dir.files[fileName] = file;
        fileReference = file;

        return dir;
      },
    );
    res.unwrap();
    return fileReference;
  }

  // TODO Open file (stream) openRead

  Future<CID> createSnapshot(String path, {bool encrypted = true}) async {
    final ks = await getKeySet(parseURI(
      await _preprocessLocalPath(path),
    ));
    final res = await _getDirectoryMetadata(ks);

    final remoteDir = res?.$1 ??
        DirectoryMetadata(
          details: DirectoryMetadataDetails({}),
          directories: {},
          files: {},
        );

    final staticDir = DirectoryMetadata(
      details: remoteDir.details,
      directories: {},
      files: remoteDir.files,
    );
    for (final dirName in remoteDir.directories.keys) {
      final dir = remoteDir.directories[dirName]!;

      staticDir.directories[dirName] = DirectoryReference(
        created: dir.created,
        name: dir.name,
        encryptedWriteKey: Uint8List(0),
        publicKey: (await createSnapshot(
          '$path/$dirName',
          encrypted: encrypted,
        ))
            .hash
            .fullBytes,
        encryptionKey: dir.encryptionKey,
      );
    }

    if (encrypted) {
      // TODO Make snapshots deterministic in a secure way
      // final key = deriveHashBlake3(base, tweak, crypto: _api.crypto);
      final key = _api.crypto.generateRandomBytes(32);

      final bytes = await encryptMutableBytes(
        staticDir.serialize(),
        key,
        crypto: _api.crypto,
      );
      final cid = await _api.uploadBlob(bytes);

      return CID(
        cidTypeMetadataDirectory,
        Multihash(
          Uint8List.fromList(
            <int>[
                  cidTypeEncryptedMutable,
                  encryptionAlgorithmXChaCha20Poly1305
                ] +
                key +
                cid.hash.fullBytes,
          ),
        ),
      );
    } else {
      final cid = await _api.uploadBlob(staticDir.serialize());

      return CID(cidTypeMetadataDirectory, cid.hash);
    }
  }

  Future<DirectoryTransactionResult> _runDirectoryTransaction(
    Uri uri,
    DirectoryTransactionFunction transaction,
  ) async {
    final ks = await getKeySet(uri);
    final dir = await _getDirectoryMetadata(ks);
    if (ks.writeKey == null) throw MissingWriteAccessException(uri.toString());
    try {
      final transactionRes = await transaction(
        dir?.$1 ??
            DirectoryMetadata(
              details: DirectoryMetadataDetails({}),
              directories: {},
              files: {},
            ),
        ks.writeKey!,
      );
      if (transactionRes == null) {
        return DirectoryTransactionResult(
          type: DirectoryTransactionResultType.notModified,
        );
      }

      // TODO Make sure this is secure
      final newBytes = ks.encryptionKey != null
          ? await encryptMutableBytes(
              transactionRes.serialize(),
              ks.encryptionKey!,
              crypto: _api.crypto,
            )
          : transactionRes.serialize();

      final cid = await _api.uploadBlob(newBytes);

      final kp = await _api.crypto.newKeyPairEd25519(seed: ks.writeKey!);

      final sre = await SignedRegistryEntry.create(
        kp: kp,
        data: cid.toRegistryEntry(),
        revision: (dir?.$2?.revision ?? 0) + 1,
        crypto: _api.crypto,
      );

      await _api.registrySet(sre);

      return DirectoryTransactionResult(
        type: DirectoryTransactionResultType.ok,
      );
    } catch (e, st) {
      return DirectoryTransactionResult(
        type: DirectoryTransactionResultType.error,
        e: e,
        st: st,
      );
    }
  }

  // TODO use case: directory symlinks for just links with field "cid"
  // TODO use case: link individual files in other dirs for collaborative?

  // TODO Maybe rename to readDirectory
  Future<DirectoryMetadata?> listDirectory(String path) async {
    /* final parsedPath = parsePath(path);
    final uriHash = convertUriToHashForCache(parsedPath); */

    final ks = await getKeySet(parseURI(
      await _preprocessLocalPath(path),
    ));
    final res = await _getDirectoryMetadata(ks);

    return res?.$1;
  }

  Future<DirectoryMetadata?> listDirectoryRecursive(String path) async {
    final dir = await listDirectory(path);
    if (dir == null) return null;

    for (final dirName in dir.directories.keys) {
      final subdir = await listDirectoryRecursive('$path/$dirName');
      if (subdir != null) {
        for (final file in subdir.files.entries) {
          dir.files['$dirName/${file.key}'] = file.value;
        }
      }
    }
    return dir;
  }

  // TODO Handle Errors for missing files
  Future<FileReference> getFileReference(String path) async {
    final pathSegments = path.split('/');
    final dir = await listDirectory(
      pathSegments.sublist(0, pathSegments.length - 1).join('/'),
    );
    return dir!.files[pathSegments.last]!;
  }

  Future<(DirectoryMetadata, SignedRegistryEntry?)?> _getDirectoryMetadata(
      KeySet ks) async {
    SignedRegistryEntry? entry;

    final Multihash multihash;
    if (ks.publicKey[0] == mhashBlake3Default) {
      multihash = Multihash(ks.publicKey);
    } else {
      entry = await _api.registryGet(ks.publicKey);

      // TODO Handle null better
      if (entry == null) return null;

      final data = entry.data;
      if (data[0] != registryS5CIDByte) throw FormatException();
      if (data[1] != cidTypeRaw && data[1] != cidTypeMetadataDirectory) {
        throw FormatException();
      }

      multihash = Multihash(
        data.sublist(2, 35),
      );
    }
    final metadataBytes = await _api.downloadRawFile(multihash);

    if (metadataBytes[0] == 0x8d) {
      if (ks.encryptionKey == null) {
        throw MissingEncryptionKeyException();
      }
      final decryptedMetadataBytes = await decryptMutableBytes(
        metadataBytes,
        ks.encryptionKey!,
        crypto: _api.crypto,
      );
      return (DirectoryMetadata.deserizalize(decryptedMetadataBytes), entry);
    } else {
      return (DirectoryMetadata.deserizalize(metadataBytes), entry);
    }
  }

  Future<String> _preprocessLocalPath(String path) async {
    if (path.startsWith('fs5://')) return path;
    if ('$path/'.startsWith('home/')) {
      return '${await _buildRootWriteURI()}/$path';
    }
    if ('$path/'.startsWith('archive/')) {
      return '${await _buildRootWriteURI()}/$path';
    }
    throw InvalidPathException();
  }

  Future<String> _buildRootWriteURI() async {
    if (_identity == null) throw NoIdentityException();
    final filesystemRootKey = deriveHashBlake3Int(
      _identity!.fsRootKey,
      1,
      crypto: _api.crypto,
    );

    // ? ed25519 calculates a SHA512 hash of the seed before using it
    final rootPublicKey =
        (await _api.crypto.newKeyPairEd25519(seed: filesystemRootKey))
            .publicKey;

    // ? BLAKE3 is a cryptographic hash function, so this derivation is irreversible
    final rootEncryptionKey = deriveHashBlake3Int(
      filesystemRootKey,
      _encryptionKeyTweak,
      crypto: _api.crypto,
    );

    // TODO pick matching magic byte
    final rootWriteKey = 'u${Multihash(Uint8List.fromList([
          0x00
        ] + filesystemRootKey)).toBase64Url()}';

    final rootCID =
        _buildEncryptedDirectoryCID(rootPublicKey, rootEncryptionKey);

    return 'fs5://write:$rootWriteKey@${rootCID.toBase32()}';
  }

  Future<CID> getDirectoryCID(String path) async {
    final keySet = await getKeySet(parseURI(await _preprocessLocalPath(path)));
    if (keySet.encryptionKey == null) {
      return CID(cidTypeMetadataDirectory, Multihash(keySet.publicKey));
    }
    final rootCID =
        _buildEncryptedDirectoryCID(keySet.publicKey, keySet.encryptionKey!);
    return rootCID;
  }

  /// publicKey: 33 bytes (with multicodec prefix byte)
  /// encryptionKey: 32 bytes
  CID _buildEncryptedDirectoryCID(
    Uint8List publicKey,
    Uint8List encryptionKey,
  ) {
    return CID(
      cidTypeMetadataDirectory,
      Multihash(
        Uint8List.fromList(
          <int>[cidTypeEncryptedMutable, encryptionAlgorithmXChaCha20Poly1305] +
              encryptionKey +
              publicKey,
        ),
      ),
    );
  }

  Future<DirectoryReference> _createDirectory(
    String name,
    Uint8List writeKey,
  ) async {
    final newWriteKey = _api.crypto.generateRandomBytes(32);

    final ks = await _deriveKeySetFromWriteKey(newWriteKey);

    final encryptionNonce = _api.crypto.generateRandomBytes(24);

    final encryptedWriteKey = await _api.crypto.encryptXChaCha20Poly1305(
      key: writeKey,
      nonce: encryptionNonce,
      plaintext: newWriteKey,
    );

    return DirectoryReference(
      created: _currentMillis(),
      name: name,
      encryptedWriteKey: Uint8List.fromList(
        [0x01] + encryptionNonce + encryptedWriteKey,
      ),
      publicKey: ks.publicKey,
      // TODO Maybe use encryption prefix here
      encryptionKey: ks.encryptionKey,
    );
  }

  int _currentMillis() {
    return DateTime.now().millisecondsSinceEpoch;
  }

  Future<KeySet> _deriveKeySetFromWriteKey(Uint8List writeKey) async {
    final publicKey =
        (await _api.crypto.newKeyPairEd25519(seed: writeKey)).publicKey;
    final encryptionKey = deriveHashBlake3Int(
      writeKey,
      _encryptionKeyTweak,
      crypto: _api.crypto,
    );
    return KeySet(
      publicKey: publicKey,
      writeKey: writeKey,
      encryptionKey: encryptionKey,
    );
  }

  Uri parseURI(String uri) {
    return Uri.parse(uri);
  }

  // TODO Maybe create a KeySet cache
  Future<KeySet> getKeySet(Uri uri) async {
    if (uri.pathSegments.isEmpty) {
      final cid = CID.decode(uri.host);
      if (cid.type != cidTypeMetadataDirectory) throw FormatException();

      Uint8List? writeKey;

      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        if (parts[0] != 'write') throw FormatException();

        writeKey = Multibase.decodeString(parts[1]).sublist(1);
      }

      if (cid.hash.functionType == mkeyEd25519) {
        // TODO Verify that writeKey matches
        return KeySet(
          publicKey: cid.hash.fullBytes,
          writeKey: writeKey,
          encryptionKey: null,
        );
      } else if (cid.hash.functionType == cidTypeEncryptedMutable) {
        // TODO Verify that writeKey matches
        return KeySet(
          publicKey: cid.hash.hashBytes.sublist(33),
          writeKey: writeKey,
          encryptionKey: cid.hash.hashBytes.sublist(1, 33),
        );
      }
    }
    final parentKeySet = await getKeySet(
      uri.replace(
        pathSegments: uri.pathSegments.sublist(
          0,
          uri.pathSegments.length - 1,
        ),
      ),
    );
    final parentDirectory = await _getDirectoryMetadata(parentKeySet);

    // TODO Custom Error Types
    if (parentDirectory == null) {
      throw 'Parent Directory of "${uri.path}" does not exist';
    }

    final dir = parentDirectory.$1.directories[uri.pathSegments.last];
    if (dir == null) {
      throw 'Directory "${uri.path}" does not exist';
    }
    Uint8List? writeKey;

    if (parentKeySet.writeKey != null) {
      final nonce = dir.encryptedWriteKey.sublist(1, 25);
      writeKey = await _api.crypto.decryptXChaCha20Poly1305(
        ciphertext: dir.encryptedWriteKey.sublist(25),
        nonce: nonce,
        key: parentKeySet.writeKey!,
      );
    }

    return KeySet(
      publicKey: dir.publicKey,
      writeKey: writeKey,
      encryptionKey: dir.encryptionKey,
    );
  }

  Future<FileVersion> uploadFilePlaintext({
    required int size,
    required OpenReadFunction openRead,
  }) async {
    final b3hash = await _api.crypto.hashBlake3File(
      size: size,
      openRead: openRead,
    );
    final hash = Multihash.blake3(b3hash);
    final plaintextCID = CID.raw(hash, size: size);

    final CID cid;
    if (size < (1024 * 1024)) {
      cid = await _api.uploadBlob(
        Uint8List.fromList(
          await openRead().fold(
            <int>[],
            (previous, element) => previous + element,
          ),
        ),
      );
    } else {
      cid = await _api.uploadRawFile(
        hash: hash,
        size: size,
        openRead: openRead,
      );
    }

    if (cid != plaintextCID) {
      throw HashMismatchException();
    }

    return FileVersion(
      ts: DateTime.now().millisecondsSinceEpoch,
      plaintextCID: plaintextCID,
    );
  }
}

typedef DirectoryTransactionFunction = Future<DirectoryMetadata?> Function(
    DirectoryMetadata directory, Uint8List writeKey);

enum DirectoryTransactionResultType { ok, error, notModified }

class DirectoryTransactionResult implements Exception {
  final DirectoryTransactionResultType type;
  final Object? e;
  final StackTrace? st;

  DirectoryTransactionResult({required this.type, this.e, this.st});

  void unwrap() {
    if (type == DirectoryTransactionResultType.error) {
      throw this;
    }
  }

  @override
  String toString() {
    if (type == DirectoryTransactionResultType.error) {
      return 'DirectoryTransactionException: $e\n$st';
    }
    return '$type';
  }
}

class KeySet {
  // has multicodec prefix
  final Uint8List publicKey;

  // do NOT have multicodec prefix
  final Uint8List? writeKey;
  final Uint8List? encryptionKey;

  KeySet({
    required this.publicKey,
    required this.writeKey,
    required this.encryptionKey,
  });
}

class HashMismatchException implements Exception {}

class MissingWriteAccessException implements Exception {
  factory MissingWriteAccessException([var message]) =>
      MissingWriteAccessException(message);
}

class MissingEncryptionKeyException implements Exception {}

class NoIdentityException implements Exception {}

class InvalidPathException implements Exception {}
