import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:lib5/src/constants.dart';
import 'package:lib5/src/crypto/base.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/metadata/base.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/registry/entry.dart';
import 'package:lib5/src/serialization/media_metadata.dart';
import 'package:lib5/src/serialization/web_app_metadata.dart';
import 'package:lib5/src/util/base64.dart';
import 'package:lib5/src/util/bytes.dart';

import 'remote_upload.dart';

class RemoteS5APIProvider extends S5APIProviderWithRemoteUpload {
  final String readApiBaseUrl;

  @override
  final CryptoImplementation crypto;

  @override
  final http.Client httpClient;

  RemoteS5APIProvider(
    this.readApiBaseUrl, {
    required this.httpClient,
    required this.crypto,
  });

  @override
  Future<Uint8List> downloadRawFile(Multihash hash) async {
    final locations = await fetchStorageLocationsFromServer(hash);
    for (final loc in locations) {
      try {
        final res = await httpClient.get(Uri.parse(loc['parts'][0]));

        if (res.statusCode != 200) {
          throw 'HTTP ${res.statusCode}';
        }

        if (!areBytesEqual(
            hash.hashBytes, crypto.hashBlake3Sync(res.bodyBytes))) {
          throw 'Hash mismatch';
        }

        return res.bodyBytes;
      } catch (e, st) {
        // TODO Proper logging
        print(e);
        print(st);
      }
    }
    throw 'Could not download file';
  }

  Future<List> fetchStorageLocationsFromServer(Multihash hash) async {
    final res = await httpClient.get(
      Uri.parse(
        '$readApiBaseUrl/s5/debug/storage_locations/${hash.toBase64Url()}',
      ),
    );

    final List uris = json.decode(res.body)['locations'];

    uris.sort((a, b) => -a['score'].compareTo(b['score']));
    return uris;
  }

  final metadataCache = <Multihash, Metadata>{};

  @override
  Future<Metadata> getMetadataByCID(CID cid) async {
    late final Metadata metadata;

    if (metadataCache.containsKey(cid.hash)) {
      metadata = metadataCache[cid.hash]!;
    } else {
      final bytes = await downloadRawFile(cid.hash);

      if (cid.type == cidTypeMetadataMedia) {
        metadata = await deserializeMediaMetadata(bytes, crypto: crypto);
      } else if (cid.type == cidTypeMetadataWebApp) {
        metadata = deserializeWebAppMetadata(bytes);
      } else {
        throw 'Unsupported metadata format';
      }
      metadataCache[cid.hash] = metadata;
    }
    return metadata;
  }

  @override
  Future<SignedRegistryEntry?> registryGet(Uint8List pk) async {
    final res = await httpClient.get(Uri.parse(readApiBaseUrl)
        .replace(path: '/s5/registry', queryParameters: {
      'pk': base64UrlNoPaddingEncode(pk),
    }));
    final data = json.decode(res.body);

    return SignedRegistryEntry(
      pk: pk,
      revision: data['revision'],
      data: base64UrlNoPaddingDecode(data['data']),
      signature: base64UrlNoPaddingDecode(data['signature']),
    );
  }

  @override
  Future<void> registrySet(SignedRegistryEntry sre) async {
    final sc = storageServiceConfigs.first;
    final res = await httpClient.post(
      sc.getAPIUrl('/s5/registry'),
      headers: {
        'content-type': 'application/json',
      }..addAll(sc.headers),
      body: json.encode(
        {
          'pk': base64UrlNoPaddingEncode(sre.pk),
          'revision': sre.revision,
          'data': base64UrlNoPaddingEncode(sre.data),
          'signature': base64UrlNoPaddingEncode(sre.signature),
        },
      ),
    );
    if (res.statusCode != 204) {
      throw 'Failed to set registry: HTTP ${res.statusCode}: ${res.body}';
    }
  }

  @override
  Stream<SignedRegistryEntry> registryListen(Uint8List pk) {
    // TODO: implement registryListen
    throw UnimplementedError();
  }
}
