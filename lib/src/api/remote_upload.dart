import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/api/node.dart';
import 'package:lib5/src/identifier/blob.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/storage_service/config.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

class S5APIProviderWithRemoteUpload extends S5NodeAPI {
  final List<StorageServiceConfig> storageServiceConfigs = [];

  S5APIProviderWithRemoteUpload(super.node);

  @override
  http.Client get httpClient;

  @override
  Future<BlobIdentifier> uploadBlobAsBytes(Uint8List data) async {
    final expectedHash = await crypto.hashBlake3(data);
    final expectedBlobId = BlobIdentifier.blake3(expectedHash, data.length);

    for (final sc in (storageServiceConfigs + storageServiceConfigs)) {
      try {
        final res = await httpClient.post(
          sc.getAPIUrl(
            '/s5/upload',
          ),
          headers: sc.headers,
          body: data,
        );
        if (res.statusCode != 200) {
          throw 'HTTP ${res.statusCode}: ${res.body}';
        }

        final cidStr = json.decode(res.body)['cid'];
        if (!expectedBlobId.matchesCidStr(cidStr)) {
          throw 'Integrity check for file uploaded to $sc failed ($cidStr != $expectedBlobId)';
        }
        return expectedBlobId;
      } catch (e, st) {
        // TODO Proper logging
        print(e);
        print(st);
      }
    }
    throw 'Could not upload raw file';
  }

  // TODO Make this trustless
  @Deprecated(
      'this should be handled on the application layer and use directories')
  Future<CID> uploadDirectory(
    Map<String, Stream<List<int>>> fileStreams,
    Map<String, int> lengths,
    String name, {
    List<String>? tryFiles,
    Map<String, String>? errorPages,
    required Function lookupMimeType,
  }) async {
    final params = {
      'name': name,
    };

    if (tryFiles != null) {
      params['tryfiles'] = json.encode(tryFiles);
    }
    if (errorPages != null) {
      params['errorpages'] = json.encode(errorPages);
    }

    final uc = storageServiceConfigs.first;

    var uri = uc.getAPIUrl('/s5/upload/directory').replace(
          queryParameters: params,
        );

    var request = http.MultipartRequest("POST", uri);

    request.headers.addAll(uc.headers);

    for (final filename in fileStreams.keys) {
      var stream = http.ByteStream(fileStreams[filename]!);

      final mimeType = lookupMimeType(filename);

      var multipartFile = http.MultipartFile(
        filename,
        stream,
        lengths[filename]!,
        filename: filename,
        contentType: mimeType == null ? null : MediaType.parse(mimeType),
      );

      request.files.add(multipartFile);
    }

    final response = await httpClient.send(request);

    if (response.statusCode != 200) {
      throw Exception('HTTP ${response.statusCode}');
    }

    final res = await response.stream.transform(utf8.decoder).join();

    final resData = json.decode(res);

    if (resData['cid'] == null) throw Exception('Directory upload failed');
    return CID.decode(resData['cid']);
  }
}
