import 'dart:typed_data';

import 'package:messagepack/messagepack.dart';

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/metadata/media.dart';
import 'package:lib5/src/model/metadata/user.dart';
import 'package:lib5/src/model/metadata/extra.dart';
import 'package:lib5/src/util/bytes.dart';
import 'package:lib5/src/util/endian.dart';
import 'package:lib5/src/util/pack_anything.dart';

Future<MediaMetadata> deserializeMediaMetadata(
  Uint8List bytes, {
  required CryptoImplementation crypto,
}) async {
  final magicByte = bytes[0];
  if (magicByte != metadataMagicByte) {
    throw 'Invalid metadata: Unsupported magic byte';
  }
  final typeAndVersion = bytes[1];

  final Uint8List bodyBytes;

  final provenUserIds = <String>[];

  if (typeAndVersion == metadataTypeProofs) {
    final proofSectionLength = decodeEndian(bytes.sublist(2, 4));

    bodyBytes = bytes.sublist(4 + proofSectionLength);

    if (proofSectionLength > 0) {
      final proofUnpacker = Unpacker(bytes.sublist(4, proofSectionLength + 4));

      final b3hash = Uint8List.fromList(
        [mhashBlake3Default] + await crypto.hashBlake3(bodyBytes),
      );

      final proofCount = proofUnpacker.unpackListLength();

      for (int i = 0; i < proofCount; i++) {
        final parts = proofUnpacker.unpackList();
        final proofType = parts[0] as int;

        if (proofType == metadataProofTypeSignature) {
          final pubkey = Uint8List.fromList(parts[1] as List<int>);
          final mhashType = parts[2] as int;
          final signature = Uint8List.fromList(parts[3] as List<int>);

          if (mhashType != mhashBlake3Default) {
            throw 'Hash type $mhashType not supported';
          }

          if (pubkey[0] != mkeyEd25519) {
            throw 'Only ed25519 keys are supported';
          }
          if (pubkey.length != 33) {
            throw 'Invalid userId';
          }

          final isValid = await crypto.verifyEd25519(
            message: b3hash,
            signature: signature,
            pk: pubkey.sublist(1),
          );

          if (!isValid) {
            throw 'Invalid signature found';
          }
          provenUserIds.add(String.fromCharCodes(pubkey));
        } else {
          // ! Unsupported proof type
        }
      }
    }
  } else if (typeAndVersion == metadataTypeMedia) {
    bodyBytes = bytes.sublist(1);
  } else {
    throw 'Invalid metadata: Unsupported type $typeAndVersion';
  }

  // Start of body section

  final u = Unpacker(bodyBytes);
  final type = u.unpackInt();

  if (type != metadataTypeMedia) {
    throw 'Invalid metadata: Unsupported type $type';
  }

  u.unpackListLength();

  final name = u.unpackString();

  final details = MediaMetadataDetails(u.unpackMap().cast<int, dynamic>());

  final users = <MetadataUser>[];
  final userCount = u.unpackListLength();
  for (int i = 0; i < userCount; i++) {
    final m = u.unpackMap();

    final userId = UserID(Uint8List.fromList(m[1] as List<int>));

    users.add(MetadataUser(
      userId: userId,
      role: m[2] as String?,
      signed: provenUserIds.contains(String.fromCharCodes(userId.bytes)),
    ));
  }

  final mediaTypesMap = u.unpackMap().cast<String, dynamic>();
  final mediaTypes = <String, List<MediaFormat>>{};

  for (final m in mediaTypesMap.entries) {
    final type = m.key;

    mediaTypes[type] = [];
    for (final e in m.value) {
      mediaTypes[type]!.add(MediaFormat.decode(e.cast<int, dynamic>()));
    }
  }

  final links = u.unpackMap().cast<int, dynamic>();

  final extraMetadata = u.unpackMap().cast<int, dynamic>();

  return MediaMetadata(
    name: name ?? '',
    details: details,
    users: users,
    mediaTypes: mediaTypes,
    links: links.isEmpty ? null : MediaMetadataLinks.decode(links),
    extraMetadata: ExtraMetadata(extraMetadata),
  );
}

Future<Uint8List> serializeMediaMetadata(
  MediaMetadata m, {
  List<KeyPairEd25519> keyPairs = const [],
  required CryptoImplementation crypto,
}) async {
  final c = Packer();
  c.packInt(metadataTypeMedia);

  c.packListLength(6);

  c.packString(m.name);
  c.pack(m.details.data);

  if (keyPairs.isNotEmpty) {
    c.packListLength(keyPairs.length);
    for (final kp in keyPairs) {
      c.pack({
        1: kp.publicKey,
      });
    }
  } else {
    c.packListLength(m.users.length);
    for (final user in m.users) {
      c.pack({
        1: user.userId.bytes,
      });
    }
  }

  c.packMapLength(m.mediaTypes.length);
  for (final e in m.mediaTypes.entries) {
    c.packString(e.key);
    c.pack(e.value);
  }

  if (m.links == null) {
    c.packMapLength(0);
  } else {
    c.pack(m.links!.encode());
  }

  c.pack(m.extraMetadata.data);

  final bodyBytes = c.takeBytes();

  if (keyPairs.isEmpty) {
    return Uint8List.fromList([metadataMagicByte] + bodyBytes);
  }

  final b3hash = Uint8List.fromList(
    [mhashBlake3Default] + (await crypto.hashBlake3(bodyBytes)),
  );

  final proofPacker = Packer();

  proofPacker.packListLength(keyPairs.length);

  for (final kp in keyPairs) {
    final signature = await crypto.signEd25519(
      kp: kp,
      message: b3hash,
    );
    proofPacker.pack([
      metadataProofTypeSignature,
      mhashBlake3Default,
      kp.publicKey,
      signature,
    ]);
  }
  final proofBytes = proofPacker.takeBytes();

  final header = [
        metadataMagicByte,
        metadataTypeProofs,
      ] +
      encodeEndian(proofBytes.length, 2);

  return Uint8List.fromList(header + proofBytes + bodyBytes);
}
