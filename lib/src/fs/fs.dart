import 'dart:typed_data';

import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/identifier/directory.dart';
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

  Future<DirectoryIdentifier> createSnapshot(String path,
      {bool encrypted = true}) async {
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
            .key
            .bytes,
        encryptionKey: dir.encryptionKey,
      );
    }

    if (encrypted) {
      // TODO Make snapshots deterministic in a secure way
      // final key = deriveHashBlake3(base, tweak, crypto: _api.crypto);
      final key = _api.crypto.generateSecureRandomBytes(32);

      // TODO migrate encryption to prefix-free format
      // ignore: deprecated_member_use_from_same_package
      final bytes = await encryptMutableBytes(
        staticDir.serialize(),
        key,
        crypto: _api.crypto,
      );
      final cid = await _api.uploadBlobAsBytes(bytes);

      return DirectoryIdentifier.encryptedXChaCha20Poly1305(
        key,
        cid.hash,
      );
    } else {
      final blobId = await _api.uploadBlobAsBytes(staticDir.serialize());

      return DirectoryIdentifier(blobId.hash);
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
          // TODO migrate encryption to prefix-free format
          // ignore: deprecated_member_use_from_same_package
          ? await encryptMutableBytes(
              transactionRes.serialize(),
              ks.encryptionKey!,
              crypto: _api.crypto,
            )
          : transactionRes.serialize();

      final cid = await _api.uploadBlobAsBytes(newBytes);

      final kp = await _api.crypto.newKeyPairEd25519(seed: ks.writeKey!);

      final sre = await RegistryEntry.create(
        kp: kp,
        data: cid.hashBytes,
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

  // TODO Error handling
  Future<FileReference> getFileReference(String path) async {
    final pathSegments = path.split('/');
    final dir = await listDirectory(
      pathSegments.sublist(0, pathSegments.length - 1).join('/'),
    );
    return dir!.files[pathSegments.last]!;
  }

  Future<(DirectoryMetadata, RegistryEntry?)?> _getDirectoryMetadata(
      KeySet ks) async {
    RegistryEntry? entry;

    final Multihash multihash;
    // ignore: deprecated_member_use_from_same_package
    if (ks.publicKey[0] == mhashBlake3Default ||
        ks.publicKey[0] == mhashBlake3) {
      ks.publicKey[0] = mhashBlake3;
      multihash = Multihash(ks.publicKey);
    } else {
      entry = await _api.registryGet(ks.publicKey);

      // TODO Handle null better
      if (entry == null) return null;

      final data = entry.data;
      // ignore: deprecated_member_use_from_same_package
      if (data[0] == mhashBlake3 || data[0] == mhashBlake3Default) {
        multihash = Multihash(
          data.sublist(0, 33),
        );
      } else {
        // this line is for reading directories encoded using the old format
        if (data[0] != 0x5a) throw FormatException();

        multihash = Multihash(
          data.sublist(2, 35),
        );
      }
      // ignore: deprecated_member_use_from_same_package
      multihash.fullBytes[0] = mhashBlake3;
    }
    final metadataBytes = await _api.downloadBlobAsBytes(multihash);

    if (metadataBytes[0] == 0x8d) {
      if (ks.encryptionKey == null) {
        throw MissingEncryptionKeyException();
      }
      // TODO migrate encryption to prefix-free format
      // ignore: deprecated_member_use_from_same_package
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
    final filesystemRootKey = deriveHashInt(
      _identity!.fsRootKey,
      1,
      crypto: _api.crypto,
    );

    // ? ed25519 calculates a SHA512 hash of the seed before using it
    final rootPublicKey =
        (await _api.crypto.newKeyPairEd25519(seed: filesystemRootKey))
            .publicKey;

    // ? BLAKE3 is a cryptographic hash function, so this derivation is irreversible
    final rootEncryptionKey = deriveHashInt(
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

  Future<DirectoryIdentifier> getDirectoryCID(String path) async {
    final keySet = await getKeySet(parseURI(await _preprocessLocalPath(path)));
    if (keySet.encryptionKey == null) {
      return DirectoryIdentifier(Multihash(keySet.publicKey));
    }
    final rootCID =
        _buildEncryptedDirectoryCID(keySet.publicKey, keySet.encryptionKey!);
    return rootCID;
  }

  /// publicKey: 33 bytes (with multicodec prefix byte)
  /// encryptionKey: 32 bytes
  DirectoryIdentifier _buildEncryptedDirectoryCID(
    Uint8List publicKey,
    Uint8List encryptionKey,
  ) {
    return DirectoryIdentifier.encryptedXChaCha20Poly1305(
      encryptionKey,
      MultiKeyOrHash(publicKey),
    );
  }

  Future<DirectoryReference> _createDirectory(
    String name,
    Uint8List writeKey,
  ) async {
    final newWriteKey = _api.crypto.generateSecureRandomBytes(32);

    final ks = await _deriveKeySetFromWriteKey(newWriteKey);

    final encryptionNonce = _api.crypto.generateSecureRandomBytes(24);

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
    final encryptionKey = deriveHashInt(
      writeKey,
      0x5e,
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

  final _keySetCache = <Uri, KeySet>{};

  // TODO Maybe create a KeySet cache
  Future<KeySet> getKeySet(Uri uri) async {
    if (_keySetCache.containsKey(uri)) return _keySetCache[uri]!;

    if (uri.pathSegments.isEmpty) {
      final dirId = DirectoryIdentifier.decode(uri.host);

      Uint8List? writeKey;

      if (uri.userInfo.isNotEmpty) {
        final parts = uri.userInfo.split(':');
        if (parts[0] != 'write') throw FormatException();

        writeKey = Multibase.decodeString(parts[1]).sublist(1);
      }

      if (dirId.key.type == mkeyEd25519) {
        // TODO Verify that writeKey matches
        return KeySet(
          publicKey: dirId.key.bytes,
          writeKey: writeKey,
          encryptionKey: null,
        );
      } else if (dirId.encrypted) {
        // TODO Verify that writeKey matches
        return KeySet(
          publicKey: dirId.key.bytes,
          writeKey: writeKey,
          encryptionKey: dirId.encryptionKey,
        );
        // ignore: deprecated_member_use_from_same_package
      } else if (dirId.key.type == mhashBlake3Default ||
          dirId.key.type == mhashBlake3) {
        final mhash = dirId.key.bytes;
        mhash[0] = mhashBlake3;
        return KeySet(
          publicKey: mhash,
          writeKey: writeKey,
          encryptionKey: null,
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

    final ks = KeySet(
      publicKey: dir.publicKey,
      writeKey: writeKey,
      encryptionKey: dir.encryptionKey,
    );

    _keySetCache[uri] = ks;
    return ks;
  }

  Future<FileVersion> uploadFilePlaintext({
    required int size,
    required OpenReadFunction openRead,
  }) async {
    final b3hash = await _api.crypto.hashBlake3File(
      size: size,
      openRead: openRead,
    );

    final plaintextCID = BlobIdentifier.blake3(b3hash, size);

    final BlobIdentifier cid;
    if (size < (1024 * 1024)) {
      cid = await _api.uploadBlobAsBytes(
        Uint8List.fromList(
          await openRead().fold(
            <int>[],
            (previous, element) => previous + element,
          ),
        ),
      );
    } else {
      cid = await _api.uploadBlobWithStream(
        hash: plaintextCID.hash,
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
  factory MissingWriteAccessException([dynamic message]) =>
      MissingWriteAccessException(message);
}

class MissingEncryptionKeyException implements Exception {}

class NoIdentityException implements Exception {}

class InvalidPathException implements Exception {}
