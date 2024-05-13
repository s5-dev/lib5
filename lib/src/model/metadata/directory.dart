import 'dart:typed_data';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/encrypted_cid.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/pack_anything.dart';
import 'package:s5_msgpack/s5_msgpack.dart';

import 'base.dart';

class DirectoryMetadata extends Metadata {
  DirectoryMetadata({
    required this.details,
    required this.directories,
    required this.files,
  });

  final DirectoryMetadataDetails details;

  // ! keys are for URIs
  // ! optional "name" for custom name
  Map<String, DirectoryReference> directories;
  Map<String, FileReference> files;

  Uint8List serialize() {
    final p = Packer();
    p.packInt(metadataMagicByte);
    p.packInt(cidTypeMetadataDirectory);

    p.packListLength(3);

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

    return p.takeBytes();
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'directory',
        'details': details,
        'directories': directories,
        'files': files,
      };

  factory DirectoryMetadata.deserizalize(Uint8List bytes) {
    final u = Unpacker(bytes);

    final magicByte = u.unpackInt();
    if (magicByte != metadataMagicByte) {
      throw 'Invalid metadata: Unsupported magic byte';
    }
    final typeAndVersion = u.unpackInt();
    if (typeAndVersion != metadataTypeDirectory &&
        typeAndVersion != cidTypeMetadataDirectory) {
      throw 'Invalid metadata: Wrong metadata type';
    }

    u.unpackListLength();

    final dir = DirectoryMetadata(
      details: DirectoryMetadataDetails(u.unpackMap().cast<int, dynamic>()),
      directories: {},
      files: {},
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

    return dir;
  }

  @override
  String toString() {
    return 'DirectoryMetadata${jsonEncode(this)}';
  }
}

class DirectoryMetadataDetails {
  final Map<int, dynamic> data;

  bool get isShared => data.containsKey(3);
  bool get isSharedReadOnly => data[3]?[1] ?? false;
  bool get isSharedReadWrite => data[3]?[2] ?? false;

  CID get previousVersion => CID.fromBytes(data[4]);

  void setShared(bool value, bool write) {
    data[3] ??= <int, bool>{};
    data[3][write ? 2 : 1] = value;
  }

  DirectoryMetadataDetails(this.data);

  Map<String, dynamic> toJson() => {};
}

class DirectoryReference {
  final int created;

  String name;

  Uint8List encryptedWriteKey;

  // These two are derived from the writeKey
  Uint8List publicKey;
  Uint8List? encryptionKey;

  /// Can be used by applications to add more metadata
  Map<String, dynamic>? ext;

  DirectoryReference({
    required this.created,
    required this.name,
    required this.encryptedWriteKey,
    required this.publicKey,
    required this.encryptionKey,
    this.ext,
  });

  // ! Ignore, used for internal operations
  String? uri;
  String? key;
  int? size;

  Map<String, dynamic> toJson() => {
        'name': name,
        'created': created,
        'publicKey': base64UrlNoPaddingEncode(publicKey),
        'encryptedWriteKey': base64UrlNoPaddingEncode(encryptedWriteKey),
        'encryptionKey': encryptionKey == null
            ? null
            : base64UrlNoPaddingEncode(encryptionKey!),
        'ext': ext,
      };

  factory DirectoryReference.decode(Map<int, dynamic> data) {
    return DirectoryReference(
      name: data[1],
      created: data[2],
      publicKey: data[3],
      encryptedWriteKey: data[4],
      encryptionKey: data[5],
      ext: data[6]?.cast<String, dynamic>(),
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
    addNotNull(6, ext);
    return map;
  }
}

// TODO Share individual files with updates -> add copy hook (with DirectoryReference)
class FileReference {
  FileReference({
    required this.name,
    required this.created,
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
  int get modified => file.ts;

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
        'history':
            history?.map((key, value) => MapEntry(key.toString(), value)),
      };

  factory FileReference.decode(Map<int, dynamic> data) {
    final fr = FileReference(
      name: data[1],
      created: data[2],
      file: FileVersion.decode(data[4].cast<int, dynamic>()),
      version: data[5],
      mimeType: data[6],
      ext: data[7]?.cast<String, dynamic>(),
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

  @override
  String toString() {
    return 'FileReference${jsonEncode(this)}';
  }
}

class FileVersion {
  /// in millis
  final int ts;

  final EncryptedCID? encryptedCID;
  final CID? plaintextCID;

  CID get cid => plaintextCID ?? encryptedCID!.originalCID;

  final FileVersionThumbnail? thumbnail;

  final List<Multihash>? hashes;

  FileVersion({
    required this.ts,
    this.plaintextCID,
    this.encryptedCID,
    this.thumbnail,
    this.hashes,
    this.ext,
  });

  // TODO Add copyWith for adding things like ext

  factory FileVersion.decode(Map<int, dynamic> data) {
    return FileVersion(
      encryptedCID: data[1] == null ? null : EncryptedCID.fromBytes(data[1]!),
      plaintextCID: data[2] == null ? null : CID.fromBytes(data[2]!),
      ts: data[8],
      hashes: data[9]?.map((e) => Multihash(e)).toList(),
      thumbnail: data[10] == null
          ? null
          : FileVersionThumbnail.decode(
              data[10].cast<int, dynamic>(),
            ),
    );
  }

  Map<int, dynamic> encode() {
    final map = <int, dynamic>{
      8: ts,
    };
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(1, encryptedCID?.toBytes());
    addNotNull(2, plaintextCID?.toBytes());

    addNotNull(9, hashes?.map((e) => e.fullBytes).toList());
    addNotNull(10, thumbnail);

    return map;
  }

  Map<String, dynamic> toJson() => {
        'ts': ts,
        'encryptedCID': encryptedCID?.toBase58(),
        'cid': cid.toBase58(),
        'hashes': hashes?.map((e) => e.toBase64Url()).toList(),
        'thumbnail': thumbnail,
      };

  // ! Ignore, temporary
  Map<String, dynamic>? ext;
}

class FileVersionThumbnail {
  String? imageType; // default: webp
  double aspectRatio;
  EncryptedCID cid;
  Uint8List? thumbhash;

  FileVersionThumbnail({
    this.imageType,
    required this.cid,
    required this.aspectRatio,
    this.thumbhash,
  });

  Map<String, dynamic> toJson() => {
        'imageType': imageType,
        'aspectRatio': aspectRatio,
        'cid': cid.toBase58(),
        'thumbhash':
            thumbhash == null ? null : base64UrlNoPaddingEncode(thumbhash!),
      };

  Map<int, dynamic> encode() {
    final map = <int, dynamic>{
      2: aspectRatio,
      3: cid.toBytes(),
    };
    void addNotNull(int key, dynamic value) {
      if (value != null) {
        map[key] = value;
      }
    }

    addNotNull(1, imageType);
    addNotNull(4, thumbhash);
    return map;
  }

  factory FileVersionThumbnail.decode(Map<int, dynamic> data) {
    return FileVersionThumbnail(
      imageType: data[1],
      aspectRatio: data[2]!,
      cid: EncryptedCID.fromBytes(data[3]!),
      thumbhash: data[4],
    );
  }
}
