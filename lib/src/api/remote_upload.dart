import 'dart:convert';
import 'dart:typed_data';

import 'package:lib5/src/api/base.dart';
import 'package:lib5/src/constants.dart';
import 'package:lib5/src/model/cid.dart';
import 'package:lib5/src/model/multihash.dart';
import 'package:lib5/src/storage_service/config.dart';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

abstract class S5APIProviderWithRemoteUpload extends S5APIProvider {
  final List<StorageServiceConfig> storageServiceConfigs = [];

  http.Client get httpClient;

  @override
  Future<CID> uploadRawFile(Uint8List data) async {
    final expectedHash = await crypto.hashBlake3(data);
    final expectedCID = CID(
      cidTypeRaw,
      Multihash(Uint8List.fromList(
        [mhashBlake3Default] + expectedHash,
      )),
      size: data.length,
    );

    for (final sc in storageServiceConfigs) {
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
        final cid = CID.decode(json.decode(res.body)['cid']);
        if (cid != expectedCID) {
          throw 'Integrity check for file uploaded to $sc failed ($cid != $expectedCID)';
        }
        return cid;
      } catch (e, st) {
        // TODO Proper logging
        print(e);
        print(st);
      }
    }
    throw 'Could not upload raw file';
  }

  // TODO Make this trustless
  Future<CID> uploadDirectory(
    Map<String, Stream<List<int>>> fileStreams,
    Map<String, int> lengths,
    String dirname, {
    List<String>? tryFiles,
    Map<String, String>? errorPages,
    required Function lookupMimeType,
  }) async {
    final params = {
      'dirname': dirname,
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
