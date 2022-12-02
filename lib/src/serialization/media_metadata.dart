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
  final rawUnpacker = Unpacker(bytes);

  final magicByte = rawUnpacker.unpackInt();
  if (magicByte != metadataMagicByte) {
    throw 'Invalid metadata: Unsupported magic byte';
  }
  final typeAndVersion = rawUnpacker.unpackInt();
  if (typeAndVersion != metadataTypeMedia) {
    throw 'Invalid metadata: Wrong metadata type';
  }
  final proofSectionLength = decodeEndian(bytes.sublist(2, 6));

  final bodyBytes = bytes.sublist(6 + proofSectionLength);

  final provenUserIds = <String>[];

  if (proofSectionLength > 0) {
    final proofUnpacker = Unpacker(bytes.sublist(6, proofSectionLength + 6));

    final b3hash = await crypto.hashBlake3(bodyBytes);

    final proofCount = proofUnpacker.unpackListLength();

    for (int i = 0; i < proofCount; i++) {
      final parts = proofUnpacker.unpackList();
      final proofType = parts[0] as int;

      if (proofType == metadataProofTypeSignature) {
        final pubkey = Uint8List.fromList(parts[1] as List<int>);
        final mhash = Uint8List.fromList(parts[2] as List<int>);
        final signature = Uint8List.fromList(parts[3] as List<int>);

        if (!areBytesEqual(mhash.sublist(1), b3hash)) {
          throw 'Invalid hash';
        }

        if (pubkey[0] != mkeyEd25519) {
          throw 'Only ed25519 keys are supported';
        }
        if (pubkey.length != 33) {
          throw 'Invalid userId';
        }

        final isValid = await crypto.verifyEd25519(
          message: mhash,
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

  // Start of body section

  final u = Unpacker(bodyBytes);

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

  final extraMetadata = u.unpackMap().cast<int, dynamic>();

  final mm = MediaMetadata(
    name: name ?? '',
    details: details,
    users: users,
    mediaTypes: mediaTypes,
    extraMetadata: ExtraMetadata(extraMetadata),
  );

  return mm;
}

Future<Uint8List> serializeMediaMetadata(
  MediaMetadata m, {
  List<KeyPairEd25519> keyPairs = const [],
  required CryptoImplementation crypto,
}) async {
  final c = Packer();

  c.packString(m.name);
  c.pack(m.details.data);

  c.packListLength(keyPairs.length);
  for (final kp in keyPairs) {
    c.pack({
      1: kp.publicKey,
    });
  }

  c.packMapLength(m.mediaTypes.length);
  for (final e in m.mediaTypes.entries) {
    c.packString(e.key);
    c.pack(e.value);
  }
  c.pack(m.extraMetadata.data);

  final bodyBytes = c.takeBytes();

  if (keyPairs.isEmpty) {
    final header = [
          metadataMagicByte,
          metadataTypeMedia,
        ] +
        encodeEndian(0, 4);

    return Uint8List.fromList(header + bodyBytes);
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
      kp.publicKey,
      b3hash,
      signature,
    ]);
  }
  final proofBytes = proofPacker.takeBytes();

  final header = [
        metadataMagicByte,
        metadataTypeMedia,
      ] +
      encodeEndian(proofBytes.length, 4);

  return Uint8List.fromList(header + proofBytes + bodyBytes);
}
