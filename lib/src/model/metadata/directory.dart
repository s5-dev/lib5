import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/encrypted_cid.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/pack_anything.dart';
import 'package:messagepack/messagepack.dart';

import 'base.dart';
import 'extra.dart';

class DirectoryMetadata extends Metadata {
  DirectoryMetadata({
    required this.details,
    required this.directories,
    required this.files,
    required this.extraMetadata,
  });

  final DirectoryMetadataDetails details;

  // ! keys are for URIs
  // ! optional "name" for custom name
  Map<String, DirectoryReference> directories;
  Map<String, FileReference> files;

  final ExtraMetadata extraMetadata;

  Uint8List serialize() {
    final p = Packer();
    p.packInt(metadataMagicByte);
    p.packInt(metadataTypeDirectory);

    p.packListLength(4);

    p.pack(details.data);

    p.packMapLength(directories.length);
    for (final e in directories.entries) {
      p.packString(e.key);
      p.pack(e.value);
    }

    p.packMapLength(files.length);
    for (final e in files.entries) {
      p.packString(e.key);
      p.pack(e.value);
    }

    p.pack(extraMetadata.data);

    return p.takeBytes();
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'directory',
        'details': details,
        'directories': directories,
        'files': files,
        'extraMetadata': extraMetadata,
      };

  factory DirectoryMetadata.deserizalize(Uint8List bytes) {
    final u = Unpacker(bytes);

    final magicByte = u.unpackInt();
    if (magicByte != metadataMagicByte) {
      throw 'Invalid metadata: Unsupported magic byte';
    }
    final typeAndVersion = u.unpackInt();
    if (typeAndVersion != metadataTypeDirectory) {
      throw 'Invalid metadata: Wrong metadata type';
    }

    u.unpackListLength();

    final dir = DirectoryMetadata(
      details: DirectoryMetadataDetails(u.unpackMap().cast<int, dynamic>()),
      directories: {},
      files: {},
      extraMetadata: ExtraMetadata({}),
    );

    final dirCount = u.unpackMapLength();
    for (int i = 0; i < dirCount; i++) {
      dir.directories[u.unpackString()!] = DirectoryReference.decode(
        u.unpackMap().cast<int, dynamic>(),
      );
    }

    final fileCount = u.unpackMapLength();
    for (int i = 0; i < fileCount; i++) {
      dir.files[u.unpackString()!] = FileReference.decode(
        u.unpackMap().cast<int, dynamic>(),
      );
    }

    dir.extraMetadata.data.addAll(u.unpackMap().cast<int, dynamic>());
    return dir;
  }
}

class DirectoryMetadataDetails {
  final Map<int, dynamic> data;

  // TODO Use for sync (deleted files/directories with timestamp)

  DirectoryMetadataDetails(this.data);

  Map<String, dynamic> toJson() => {};
}

class DirectoryReference {
  final int created;
  final String name;

  Uint8List encryptedWriteKey;

  // These two are derived from the writeKey
  Uint8List publicKey;
  Uint8List? encryptionKey;

  DirectoryReference({
    required this.created,
    required this.name,
    required this.encryptedWriteKey,
    required this.publicKey,
    required this.encryptionKey,
  });

  // ! Ignore, used for internal operations
  String? uri;
  String? key;
  int? size;

  @override
  Map<String, dynamic> toJson() => {
        'name': name,
        'created': created,
        'publicKey': base64UrlNoPaddingEncode(publicKey),
        'encryptedWriteKey': base64UrlNoPaddingEncode(encryptedWriteKey),
        'encryptionKey': encryptionKey == null
            ? null
            : base64UrlNoPaddingEncode(encryptionKey!),
      };

  factory DirectoryReference.decode(Map<int, dynamic> data) {
    return DirectoryReference(
      name: data[1],
      created: data[2],
      publicKey: data[3],
      encryptedWriteKey: data[4],
      encryptionKey: data[5],
    );
  }

  Map<int, dynamic> encode() {
    final map = <int, dynamic>{
      1: name,
      2: created,
      3: publicKey,
      4: encryptedWriteKey,
    };
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(5, encryptionKey);
    return map;
  }
}

// TODO Share individual files with updates -> add copy hook (with DirectoryReference)
class FileReference {
  FileReference({
    required this.name,
    required this.created,
    required this.modified,
    required this.version,
    required this.file,
    this.ext,
    this.history,
    this.mimeType,
  });

  /// Unix timestamp (in milliseconds) when this file was created
  int created;

  /// The current version of a file
  FileVersion file;

  /// Historic versions of a file
  Map<int, FileVersion>? history;

  /// MIME Type of the file, optional
  String? mimeType;

  /// Unix timestamp (in milliseconds) when this file was last modified
  int modified;

  /// Name of this file
  String name;

  // Current version of the file. When this file was already modified 9 times, this value is 9
  int version;

  /// Can be used by applications to add more metadata
  Map<String, dynamic>? ext;

  Map<String, dynamic> toJson() => {
        'name': name,
        'created': created,
        'modified': modified,
        'version': version,
        'mimeType': mimeType,
        'file': file,
        'ext': ext,
        'history': history,
      };

  factory FileReference.decode(Map<int, dynamic> data) {
    final fr = FileReference(
      name: data[1],
      created: data[2],
      modified: data[3],
      file: FileVersion.decode(data[4].cast<int, dynamic>()),
      version: data[5],
      mimeType: data[6],
      ext: data[7].cast<String, dynamic>(),
    );
    if (data[8] != null) {
      fr.history = <int, FileVersion>{};
      for (final m in (data[8] as Map).entries) {
        fr.history![m.key] = FileVersion.decode(m.value.cast<int, dynamic>());
      }
    }
    return fr;
  }

  Map<int, dynamic> encode() {
    final map = <int, dynamic>{
      1: name,
      2: created,
      3: modified,
      4: file,
      5: version,
    };
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(6, mimeType);
    addNotNull(7, ext);
    addNotNull(8, history);
    return map;
  }

  // ! Ignore, used for internal operations
  String? uri;
  String? key;
}

class FileVersion {
  int ts;

  EncryptedCID? encryptedCID;
  CID get cid => encryptedCID!.originalCID;

  FileVersion({
    required this.encryptedCID,
    required this.ts,
    this.hashes,
    this.ext,
  });

  List<Multihash>? hashes;

  factory FileVersion.decode(Map<int, dynamic> data) {
    return FileVersion(
      encryptedCID: EncryptedCID.fromBytes(data[1]!),
      ts: data[8],
      hashes: data[9]?.map((e) => Multihash(e)).toList(),
    );
  }

  Map<int, dynamic> encode() {
    // TODO Support not-encrypted CIDs
    final map = <int, dynamic>{
      1: encryptedCID!.toBytes(),
      8: ts,
    };
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(9, hashes?.map((e) => e.fullBytes).toList());
    return map;
  }

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'encryptedCID': encryptedCID?.toBase58(),
        'cid': cid.toBase58(),
        'hashes': hashes?.map((e) => e.toBase64Url()).toList()
      };

  // ! Ignore, temporary
  Map<String, dynamic>? ext;
}
